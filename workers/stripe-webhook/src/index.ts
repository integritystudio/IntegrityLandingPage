import { notFound, ok, serverError } from '../../lib/http';
import { verifyStripeSignature } from './verify';
import { createSupabaseAdmin } from './supabase';
import { handleCheckoutSessionCompleted } from './handlers/checkout';
import { handleSubscriptionUpdated, handleSubscriptionDeleted } from './handlers/subscription';
import { handleInvoicePaid, handleInvoicePaymentFailed } from './handlers/invoice';
import type { StripeEvent, HandlerResult, ApiKeyTier } from '../../lib/types';
import { ApiKeyTierSchema } from '../../lib/types/schemas';

export interface Env {
  STRIPE_WEBHOOK_SECRET: string;
  SUPABASE_URL: string;
  SUPABASE_SERVICE_ROLE_KEY: string;
  /** JSON object mapping Stripe price IDs to plan keys, e.g. '{"price_123":"growth"}' */
  STRIPE_PRICE_TO_PLAN_JSON?: string;
}

function parsePriceToPlan(jsonStr: string | undefined): Record<string, ApiKeyTier> {
  if (!jsonStr) return {};
  try {
    const raw = JSON.parse(jsonStr) as Record<string, unknown>;
    const result: Record<string, ApiKeyTier> = {};
    for (const [priceId, plan] of Object.entries(raw)) {
      const parsed = ApiKeyTierSchema.safeParse(plan);
      if (parsed.success) {
        result[priceId] = parsed.data;
      } else {
        console.warn(`STRIPE_PRICE_TO_PLAN_JSON: invalid plan value "${String(plan)}" for price "${priceId}", skipping`);
      }
    }
    return result;
  } catch {
    console.warn('STRIPE_PRICE_TO_PLAN_JSON is not valid JSON; price-to-plan mapping disabled');
    return {};
  }
}

// processEvent runs inside ctx.waitUntil after the 2xx response has been sent.
// Stripe does not see any errors thrown here; log and dead-letter as needed.
async function processEvent(
  event: StripeEvent,
  db: ReturnType<typeof createSupabaseAdmin>,
  priceToPlan: Record<string, ApiKeyTier>,
): Promise<void> {
  let result: HandlerResult = { ok: true };

  try {
    switch (event.type) {
      case 'checkout.session.completed':
        result = await handleCheckoutSessionCompleted(event, db);
        break;

      case 'invoice.paid':
        result = await handleInvoicePaid(event, db);
        break;

      case 'invoice.payment_failed':
        result = await handleInvoicePaymentFailed(event, db);
        break;

      case 'customer.subscription.updated':
        result = await handleSubscriptionUpdated(event, db, priceToPlan);
        break;

      case 'customer.subscription.deleted':
        result = await handleSubscriptionDeleted(event, db, priceToPlan);
        break;

      default:
        console.log(`Unhandled Stripe event type: ${event.type}`);
    }
  } catch (err) {
    // Handler threw unexpectedly. Convert to HandlerResult so the unclaim + dead-letter
    // path below runs — otherwise the event stays claimed but unprocessed with no retry.
    const errMessage = err instanceof Error ? err.message : String(err);
    console.error(`CRITICAL: Unhandled exception in handler for event ${event.id} (${event.type}):`, err);
    result = { ok: false, error: errMessage };
  }

  if (!result.ok) {
    // Remove the claim so the dead-letter queue can retry processing this event.
    // Best-effort — if unclaim fails, the dead-letter reconciliation will see
    // isEventProcessed=true and resolve (not retry) the dead-letter row.
    const unclaimResult = await db.unclaimEvent(event.id);
    if (!unclaimResult.ok) {
      console.error(`Failed to unclaim event ${event.id} after handler failure:`, unclaimResult.error);
    }

    // Write to dead letter queue for retry via reconciliation cron.
    // We already returned 2xx so Stripe will not retry; the cron owns the retry schedule.
    console.error(`Failed to handle Stripe event ${event.type}:`, result.error);
    const deadLetterResult = await db.addDeadLetter(event.id, event.type, event, result.error);
    if (!deadLetterResult.ok) {
      // Dead-letter insert failed and the response is already sent — Stripe cannot be
      // signalled to retry. Log a critical error; recovery requires a manual replay.
      console.error(
        `CRITICAL: Failed to dead-letter event ${event.id} (${event.type}). Manual replay required. Payload:`,
        JSON.stringify(event),
        deadLetterResult.error,
      );
    }
  }
}

async function handleWebhook(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
  const rawBody = await request.text();

  const signatureHeader = request.headers.get('stripe-signature');
  const verifyResult = await verifyStripeSignature(
    signatureHeader,
    rawBody,
    env.STRIPE_WEBHOOK_SECRET,
  );

  if (!verifyResult.ok) {
    return verifyResult.error;
  }

  let event: StripeEvent;
  try {
    event = JSON.parse(rawBody) as StripeEvent;
  } catch {
    return serverError('Invalid JSON in request body');
  }

  if (!event.type) {
    return serverError('Invalid Stripe event');
  }

  const db = createSupabaseAdmin(env.SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY);
  const priceToPlan = parsePriceToPlan(env.STRIPE_PRICE_TO_PLAN_JSON);

  // Atomically claim the event via INSERT … ON CONFLICT DO NOTHING.
  // This collapses the previous check-then-act (isEventProcessed + logProcessedEvent)
  // into a single DB round-trip, eliminating the race window in which two concurrent
  // Stripe deliveries could both pass the check and both execute the handler.
  const claimResult = await db.claimEvent(event.id, event.type);
  if (!claimResult.ok) {
    return serverError('Failed to check idempotency');
  }
  if (!claimResult.claimed) {
    // Another request already claimed this event — skip without processing.
    return ok({ ok: true, queued: false, skipped: true, reason: 'already_processed' });
  }

  // Return 2xx to Stripe immediately, per Stripe's guidance to respond before complex logic.
  // The atomic claim above ensures a Stripe retry sees already_processed rather than
  // double-processing. ctx.waitUntil keeps the Worker alive until processEvent finishes.
  ctx.waitUntil(processEvent(event, db, priceToPlan));
  return ok({ ok: true, queued: true });
}

/**
 * Reconciliation cron: runs every 15 min (configured in wrangler.toml).
 * Retries pending dead letters with exponential backoff.
 */
async function runReconciliation(env: Env): Promise<void> {
  const db = createSupabaseAdmin(env.SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY);
  const priceToPlan = parsePriceToPlan(env.STRIPE_PRICE_TO_PLAN_JSON);
  const pending = await db.fetchPendingDeadLetters(50);

  // Sort by Stripe event creation time (payload.created, Unix seconds) so retries replay
  // events in the order Stripe originally created them. This prevents billing state
  // regression when e.g. subscription.updated is dead-lettered before subscription.deleted
  // but Stripe's event.created timestamp shows the opposite order.
  const ordered = [...pending].sort((a, b) => {
    const aCreated = (a.payload as { created?: number })?.created ?? 0;
    const bCreated = (b.payload as { created?: number })?.created ?? 0;
    return aCreated - bCreated;
  });

  for (const dl of ordered) {
    try {
      // Idempotency guard: resolve and skip dead letters whose event was already processed (e.g. overlapping cron ticks).
      // Fail-closed on DB error: skip event to prevent double-processing if the outage masks a duplicate.
      const guardResult = await db.isEventProcessed(dl.stripe_event_id);
      if (!guardResult.ok) {
        console.error(`isEventProcessed DB error for ${dl.stripe_event_id}:`, guardResult.error);
        continue;
      }
      if (guardResult.processed) {
        // Recovery path: event was already logged but dead-letter row was not resolved
        // (e.g. resolveDeadLetter failed on a prior run). Clean up now.
        const resolveResult = await db.resolveDeadLetter(dl.id);
        if (!resolveResult.ok) {
          console.error(`Failed to resolve orphaned dead letter ${dl.id}:`, resolveResult.error);
        }
        continue;
      }

      const event = dl.payload as StripeEvent;

      let result: HandlerResult = { ok: true };
      switch (dl.event_type) {
        case 'checkout.session.completed':
          result = await handleCheckoutSessionCompleted(event, db);
          break;
        case 'invoice.paid':
          result = await handleInvoicePaid(event, db);
          break;
        case 'invoice.payment_failed':
          result = await handleInvoicePaymentFailed(event, db);
          break;
        case 'customer.subscription.updated':
          result = await handleSubscriptionUpdated(event, db, priceToPlan);
          break;
        case 'customer.subscription.deleted':
          result = await handleSubscriptionDeleted(event, db, priceToPlan);
          break;
        default:
          await db.abandonDeadLetter(dl.id);
          continue;
      }

      if (result.ok) {
        const claimResult = await db.claimEvent(dl.stripe_event_id, dl.event_type);
        if (!claimResult.ok) {
          // Leave dead-letter pending — do not resolve. Next cron run will retry.
          console.error(`Failed to claim event ${dl.stripe_event_id} (${dl.event_type}):`, claimResult.error);
          continue;
        }
        // claimed=false means another concurrent cron tick already claimed the event —
        // safe to resolve the dead-letter row since the event is now logged.
        // If resolveDeadLetter fails here, the event is already in webhook_events_log.
        // The idempotency guard will detect it as processed on the next run and call
        // resolveDeadLetter again to clean up the orphaned dead-letter row.
        const resolveResult = await db.resolveDeadLetter(dl.id);
        if (!resolveResult.ok) {
          console.error(`Failed to resolve dead letter ${dl.id} for event ${dl.stripe_event_id}:`, resolveResult.error);
        }
      } else {
        const failResult = await db.failDeadLetter(dl.id, dl.retry_count, dl.max_retries, result.error);
        if (!failResult.ok) {
          console.error(`Failed to increment retry count for dead letter ${dl.id}:`, failResult.error);
        }
      }
    } catch (err) {
      console.error(`Reconciliation error for dead letter ${dl.id}:`, err);
    }
  }
}

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const { pathname } = new URL(request.url);

    if (pathname === '/health' && request.method === 'GET') {
      return ok({ ok: true, service: 'stripe-webhook' });
    }

    if (pathname === '/webhook' && request.method === 'POST') {
      return handleWebhook(request, env, ctx);
    }

    return notFound();
  },

  async scheduled(_event: ScheduledEvent, env: Env, _ctx: ExecutionContext): Promise<void> {
    await runReconciliation(env);
  },
};
