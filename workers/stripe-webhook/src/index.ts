import { ok, serverError } from '../../lib/http';
import { verifyStripeSignature } from './verify';
import { createSupabaseAdmin } from './supabase';
import { handleCheckoutSessionCompleted } from './handlers/checkout';
import { handleSubscriptionUpdated, handleSubscriptionDeleted } from './handlers/subscription';
import { handleInvoicePaid, handleInvoicePaymentFailed } from './handlers/invoice';
import type { StripeEvent, HandlerResult } from '../../lib/types';

export interface Env {
  STRIPE_WEBHOOK_SECRET: string;
  SUPABASE_URL: string;
  SUPABASE_SERVICE_ROLE_KEY: string;
}

async function handleWebhook(request: Request, env: Env): Promise<Response> {
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

  // Idempotency guard: skip events already processed to handle Stripe retries safely.
  const guardResult = await db.isEventProcessed(event.id);
  if (!guardResult.ok) {
    return serverError('Failed to check idempotency');
  }
  if (guardResult.processed) {
    return ok({ ok: true, processed: false, skipped: true, reason: 'already_processed' });
  }

  let result: HandlerResult = { ok: true };

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
      result = await handleSubscriptionUpdated(event, db);
      break;

    case 'customer.subscription.deleted':
      result = await handleSubscriptionDeleted(event, db);
      break;

    default:
      console.log(`Unhandled Stripe event type: ${event.type}`);
  }

  if (!result.ok) {
    // Write to dead letter queue for retry via reconciliation cron.
    // Return 200 to suppress Stripe's built-in retry (we own the retry schedule).
    console.error(`Failed to handle Stripe event ${event.type}:`, result.error);
    await db.addDeadLetter(event.id, event.type, event, result.error);
    return ok({ ok: true, processed: false, error: result.error });
  }

  // Record successful processing for idempotency checks on future retries.
  const logResult = await db.logProcessedEvent(event.id, event.type);
  if (!logResult.ok) {
    console.error(`Failed to log processed event ${event.id} (${event.type}):`, logResult.error);
  }

  return ok({ ok: true, processed: true });
}

/**
 * Reconciliation cron: runs every 15 min (configured in wrangler.toml).
 * Retries pending dead letters with exponential backoff.
 */
async function runReconciliation(env: Env): Promise<void> {
  const db = createSupabaseAdmin(env.SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY);
  const pending = await db.fetchPendingDeadLetters(50);

  for (const dl of pending) {
    try {
      // Idempotency guard: resolve and skip dead letters whose event was already processed (e.g. overlapping cron ticks).
      // Fail-closed on DB error: skip event to prevent double-processing if the outage masks a duplicate.
      const guardResult = await db.isEventProcessed(dl.stripe_event_id);
      if (!guardResult.ok) {
        console.error(`isEventProcessed DB error for ${dl.stripe_event_id}:`, guardResult.error);
        continue;
      }
      if (guardResult.processed) {
        await db.resolveDeadLetter(dl.id);
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
          result = await handleSubscriptionUpdated(event, db);
          break;
        case 'customer.subscription.deleted':
          result = await handleSubscriptionDeleted(event, db);
          break;
        default:
          await db.abandonDeadLetter(dl.id);
          continue;
      }

      if (result.ok) {
        const logResult = await db.logProcessedEvent(dl.stripe_event_id, dl.event_type);
        if (!logResult.ok) {
          console.error(`Failed to log processed event ${dl.stripe_event_id} (${dl.event_type}):`, logResult.error);
        }
        await db.resolveDeadLetter(dl.id);
      } else {
        await db.failDeadLetter(dl.id, dl.retry_count, dl.max_retries, result.error);
      }
    } catch (err) {
      console.error(`Reconciliation error for dead letter ${dl.id}:`, err);
    }
  }
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const { pathname } = new URL(request.url);

    if (pathname === '/health' && request.method === 'GET') {
      return ok({ ok: true, service: 'stripe-webhook' });
    }

    if (pathname === '/webhook' && request.method === 'POST') {
      return handleWebhook(request, env);
    }

    return serverError('Not found');
  },

  async scheduled(_event: ScheduledEvent, env: Env): Promise<void> {
    await runReconciliation(env);
  },
};
