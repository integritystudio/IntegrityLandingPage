# API Provisioning Architecture (Flutter)

Flutter-side architecture for Worker-to-Worker API provisioning with HMAC-signed inter-service auth.

## Request Flow

```text
Flutter app
   -> POST /send -> Sender Worker (signs request)
                       -> signed /inbox (RECEIVER service binding) -> api-provisioning-receiver (verifies)

Flutter app
   -> GET /health -> Sender Worker (public, no auth)
```

Flutter never holds the inter-service shared secret. The browser/mobile client calls the Sender Worker over plain HTTPS; the Sender Worker signs and forwards to the receiver via the `RECEIVER` service binding (not a public URL).

> **Receiver identity.** "Receiver Worker" below is the production worker **`api-provisioning-receiver`** (separate `observability-toolkit` repo, `services/api-provisioning-receiver/`), which persists to Supabase. The Sender reaches it via a Cloudflare **service binding** (`binding = "RECEIVER"`, `service = "api-provisioning-receiver"` in `workers/sender-worker/wrangler.toml`) — `env.RECEIVER.fetch(".../inbox")`, not a public URL. `workers/receiver-worker/` in this repo is a **local stub / test double** only; it is not deployed and nothing binds to it.

## Architecture

### Public API (Flutter Client → Sender Worker)

```
┌──────────────┐
│  Flutter App │
│  (iOS/Android)
└──────┬───────┘
       │ HTTPS POST/GET
       │ (public endpoints)
       ▼
┌──────────────────────────────────────┐
│  Sender Worker                        │
│  (api-provisioning-sender)            │
│  ├─ POST /signup                      │
│  ├─ POST /signin                      │
│  ├─ POST /send                        │
│  ├─ POST /create-checkout-session     │
│  └─ GET /health                       │
└──────┬───────────────────────────────┘
       │
       ├─────────► Auth0 (M2M create user, ROPC sign-in → JWT)
       │           + Supabase (org / user / membership rows)
       │
       └─────────► api-provisioning-receiver
                   (RECEIVER service binding)
```

### Internal Flow (Sender → Receiver → Edge Function)

```
┌─────────────────────────────────────────────────────────────────┐
│ POST /send (provision_api_key)                                  │
│ From: Flutter Client                                            │
│ Body: {action, jwt, name, tier}                                 │
└──────────────┬──────────────────────────────────────────────────┘
               │
               ▼ (Sender Worker)
┌─────────────────────────────────────────────────────────────────┐
│ 1. Validate request (action, jwt, name, tier present)           │
│ 2. Create HMAC signature                                         │
│ 3. Forward to Receiver                                           │
└──────────────┬──────────────────────────────────────────────────┘
               │
               ▼ RECEIVER service binding (env.RECEIVER.fetch)
┌─────────────────────────────────────────────────────────────────┐
│ POST /inbox (with x-signature, x-timestamp headers)             │
│ To: api-provisioning-receiver                                    │
│ Body: {action, jwt, name, tier} (same as request)               │
└──────────────┬──────────────────────────────────────────────────┘
               │
               ▼ (api-provisioning-receiver)
┌─────────────────────────────────────────────────────────────────┐
│ 1. Resolve x-key-id -> SIGNING_KEYS entry (required; no fallback)│
│    then validate signature with it (constant-time)               │
│ 2. Validate timestamp (prevent replay attacks)                   │
│ 3. Validate JWT via Auth0 /userinfo                              │
│ 4. Dispatch to handler (provision-api-key)                       │
└──────────────┬──────────────────────────────────────────────────┘
               │
               ▼ HTTPS POST (to Supabase)
┌─────────────────────────────────────────────────────────────────┐
│ POST /functions/v1/api-keys-create (Supabase Edge Function)     │
│ Authorization: Bearer {jwt}                                      │
│ Body: {name, tier}                                               │
└──────────────┬──────────────────────────────────────────────────┘
               │
               ▼ (Edge Function response)
┌─────────────────────────────────────────────────────────────────┐
│ Response: {token, keyId, prefix, tier}                          │
│ - token: API key (obtk_...)                                      │
│ - keyId: unique identifier                                       │
│ - prefix: first 8 chars (safe for logs)                          │
│ - tier: echoed back from request                                 │
└──────────────┬──────────────────────────────────────────────────┘
               │
               ▼ (Receiver → Sender)
┌─────────────────────────────────────────────────────────────────┐
│ Response to Sender Worker                                        │
│ Status: 200 OK                                                   │
│ Body: {ok, token, keyId, prefix, tier}                           │
└──────────────┬──────────────────────────────────────────────────┘
               │
               ▼ HTTPS (to Flutter App)
┌──────────────────────────────────────────────────────────────────┐
│ Final Response to Flutter Client                                 │
│ Status: 200 OK                                                   │
│ Body: {ok, token, keyId, prefix, tier}                           │
│                                                                   │
│ Flutter stores token securely and can now make authenticated     │
│ requests to the API Worker using Bearer {token}                  │
└──────────────────────────────────────────────────────────────────┘
```

### Data Flow Summary

| Step | Source | Destination | Auth Method | Data Signed |
|------|--------|-------------|-------------|------------|
| 1 | Flutter Client | Sender Worker | None (public) | No |
| 2 | Sender Worker | api-provisioning-receiver (RECEIVER binding) | HMAC signature | Yes (x-signature) |
| 3 | Receiver | Auth0 `/userinfo` | Bearer JWT | Yes (JWT token) |
| 4 | Receiver | Supabase Edge Function | Bearer JWT | Yes (JWT token) |
| 5 | Edge Function | Receiver | — | Edge function response |
| 6 | Receiver | Sender Worker | — | Internal response |
| 7 | Sender Worker | Flutter Client | CORS header | No |

## Service Layer

Follow the existing `ContactService` pattern (`lib/services/contact_service.dart`):

- Static-only class with private constructor
- Dio HTTP client with configurable timeouts
- `@visibleForTesting` setters for Dio and retry delay
- Sealed response types (`Success`/`Error`)
- Retry with exponential backoff on transient errors (500, 504, timeout)
- Error string constants (no magic strings)
- Sentry error tracking on final failure

### Proposed File Structure

```
lib/services/
├── provisioning_service.dart   # API client for sender worker
└── provisioning_models.dart    # Request/response data models (if complex)
```

### Service Skeleton

> The skeleton below illustrates the `ContactService`-style pattern. The shipped `ProvisioningService` (`lib/services/provisioning_service.dart`) follows it, but the live `/send` request schema is `{action, jwt, name, email, tier}` (see `SendRequestSchema` in `workers/sender-worker/src/`), not the simplified `{userId, action, sentAt}` event shown here.

```dart
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'analytics.dart';
import 'http_status.dart';

/// Sender Worker endpoint.
/// Configurable via --dart-define for staging/development.
const _senderWorkerUrl = String.fromEnvironment(
  'SENDER_WORKER_URL',
  defaultValue: 'https://sender-worker.alyshia-b38.workers.dev',
);

/// Provisioning event payload.
class ProvisioningEvent {
  final String userId;
  final String action;
  final DateTime sentAt;

  const ProvisioningEvent({
    required this.userId,
    required this.action,
    required this.sentAt,
  });

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'action': action,
    'sentAt': sentAt.toUtc().toIso8601String(),
  };
}

/// Provisioning API response.
sealed class ProvisioningResponse {
  const ProvisioningResponse();
}

class ProvisioningSuccess extends ProvisioningResponse {
  final Map<String, dynamic> data;
  const ProvisioningSuccess({required this.data});
}

class ProvisioningError extends ProvisioningResponse {
  final String error;
  const ProvisioningError({required this.error});
}

/// API client for the Sender Worker.
///
/// Sends provisioning events via POST to the Sender Worker,
/// which signs and forwards them to the Receiver Worker.
/// Flutter never touches the inter-service HMAC secret.
class ProvisioningService {
  ProvisioningService._();

  static const String _errorTimeout =
      'Connection timed out. Please try again.';
  static const String _errorNetwork =
      'Network error. Please try again.';
  static const String _errorServer =
      'Server error. Please try again.';
  static const String _errorUnexpected =
      'An unexpected error occurred.';

  static const int _maxRetries = 2;

  static Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  @visibleForTesting
  static void setDioForTesting(Dio dio) => _dio = dio;

  @visibleForTesting
  static void resetDio() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));
  }

  @visibleForTesting
  static Future<void> Function(Duration) retryDelay = Future.delayed;

  @visibleForTesting
  static void resetRetryDelay() => retryDelay = Future.delayed;

  /// Send a provisioning event to the Sender Worker.
  static Future<ProvisioningResponse> sendEvent(
    ProvisioningEvent event, {
    required String jwt,
  }) async {
    for (var attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        final response = await _dio.post(
          '$_senderWorkerUrl/send',
          data: jsonEncode(event.toJson()),
          options: Options(
            headers: {
              'Content-Type': 'application/json',
              'x-session-data': base64Encode(utf8.encode(jwt)),
            },
            validateStatus: (status) => status != null,
          ),
        );

        final data = response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : const <String, dynamic>{};

        if (response.statusCode == HttpStatus.internalServerError.code ||
            response.statusCode == HttpStatus.gatewayTimeout.code) {
          if (attempt < _maxRetries) {
            await retryDelay(Duration(seconds: 1 << attempt));
            continue;
          }
          return const ProvisioningError(error: _errorServer);
        }

        if (response.statusCode == HttpStatus.ok.code &&
            data['ok'] == true) {
          return ProvisioningSuccess(data: data);
        }

        return ProvisioningError(
          error: data['error'] as String? ?? _errorUnexpected,
        );
      } on DioException catch (e) {
        final isRetryable =
            e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.connectionError;

        if (isRetryable && attempt < _maxRetries) {
          await retryDelay(Duration(seconds: 1 << attempt));
          continue;
        }

        await ErrorTrackingService.captureException(
          e,
          stackTrace: e.stackTrace,
          context: 'ProvisioningService.sendEvent',
          extra: {'endpoint': _senderWorkerUrl, 'attempt': attempt + 1},
        );

        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout) {
          return const ProvisioningError(error: _errorTimeout);
        }
        return const ProvisioningError(error: _errorNetwork);
      } catch (e, stackTrace) {
        await ErrorTrackingService.captureException(e,
            stackTrace: stackTrace);
        return const ProvisioningError(error: _errorUnexpected);
      }
    }
    return const ProvisioningError(error: _errorUnexpected);
  }

  /// Health check against the Receiver Worker (public endpoint).
  /// Returns true if healthy, false otherwise.
  static Future<bool> checkHealth(String receiverUrl) async {
    try {
      final response = await _dio.get('$receiverUrl/health');
      final data = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : const <String, dynamic>{};
      return response.statusCode == HttpStatus.ok.code && data['ok'] == true;
    } on DioException catch (e) {
      await ErrorTrackingService.captureException(e,
          context: 'ProvisioningService.checkHealth');
      return false;
    }
  }
}
```

## Implementation Status

✅ **Flutter Service** (`lib/services/provisioning_service.dart`)
- ProvisioningEvent model with UTC timestamp serialization
- ProvisioningSuccess/ProvisioningError sealed response types
- Retry logic with exponential backoff (1s, 2s delays)
- Health check with HTTPS URL validation
- Sentry error tracking on final failure
- Tests follow contact_service.dart patterns

✅ **Sender Worker** (`workers/sender-worker/src/index.ts`)
- POST /signup, /signin, /send, /create-checkout-session, GET /health (Zod v4 validation)
- Inline Auth0 (M2M create user + ROPC sign-in) + Supabase org/user/membership provisioning on /signup
- HMAC-SHA256 signature computation (timestamp + body); key rotation via `SIGNING_KEYS`/`ACTIVE_KEY_ID`/`x-key-id`
- Forwards signed /send events to the receiver via the `RECEIVER` service binding (x-timestamp, x-signature headers)

✅ **Receiver** — production: `api-provisioning-receiver` (`observability-toolkit` repo); local stub: `workers/receiver-worker/src/index.ts`
- GET /health public endpoint
- POST /inbox with signature verification (constant-time comparison)
- 5-minute replay protection window (REPLAY_WINDOW_MS)

✅ **CORS & Origin Validation** — implemented
- Sender Worker validates the request `Origin` against `ALLOWED_ORIGINS_JSON` and handles OPTIONS preflight; 403 on disallowed origins
- See [CORS Note](#cors-and-origin-headers) below

## Configuration

Worker URLs are injected at build time via `--dart-define`, matching the existing `CONTACT_API_URL` pattern:

```bash
# Development
flutter run -d chrome --dart-define=SENDER_WORKER_URL=http://localhost:8787

# Production (default in code)
flutter build web
```

## Security Model

| Concern | Approach |
|---------|----------|
| Inter-service auth | HMAC-SHA256 signature (Workers only); keyed by `SIGNING_KEYS`/`ACTIVE_KEY_ID`/`x-key-id`, which is required — no keyless fallback |
| Replay protection | `x-timestamp` header, 5-minute window |
| Secret storage | Wrangler secrets / Doppler (`SIGNING_KEYS` + `ACTIVE_KEY_ID`), never in Flutter |
| Client auth | None required (Sender Worker is the trust boundary) |
| CORS | Sender Worker validates `Origin` against `ALLOWED_ORIGINS_JSON` |

The Flutter app treats the Sender Worker as a trusted proxy. It sends plain JSON over HTTPS; the Sender Worker appends `x-timestamp` and `x-signature` headers before forwarding to the Receiver Worker.

## Worker Contracts

### Sender Worker

| Method | Path | Request Body | Response |
|--------|------|-------------|----------|
| POST | `/signup` | `{email, password}` | `{jwt, auth0Sub, userId, email}` or `{error, code}` |
| POST | `/signin` | `{email, password}` | `{jwt, email}` or `{error, code}` |
| POST | `/send` | `{action: "provision_api_key", jwt, name, email, tier, org_name?}` (`org_name` optional — derived from the email's registrable domain when omitted) or `{action: "sign_in", jwt, email}` | `{ ok, token, keyId, prefix, tier }` or `{ error }` |
| POST | `/create-checkout-session` | `{email, tier}` | `{checkoutUrl}` or `{error, code}` |
| GET | `/health` | — | `{ ok: true }` |

> **JWT delivery.** `/send` prefers the JWT from a base64-encoded `x-session-data` request header (avoids WAF pattern-matching on raw JWTs in the body/`Authorization` header) and falls back to `body.jwt`, then a `Bearer` `Authorization` header. See `extractJwt` in `workers/sender-worker/src/index.ts`; the Dart client sends `x-session-data` in `provisioning_service.dart`.

### Receiver (`api-provisioning-receiver`)

| Method | Path | Auth | Response |
|--------|------|------|----------|
| GET | `/health` | None | `{ ok: true, service: "api-provisioning-receiver" }` |
| POST | `/inbox` | `x-timestamp` + `x-signature` headers | `{ ok: true, received: ... }` or `{ error: "..." }` |

## Testing Strategy

Follow the existing `contact_service_test.dart` patterns:

- Mock Dio via `@visibleForTesting` setter
- Override `retryDelay` to avoid real delays
- Test retry count on 500/504/timeout (assert `postCallCount`)
- Test sealed response type matching
- Test `--dart-define` URL override behavior

## Production Hardening

Shipped:

- ✅ Constant-time signature comparison in the receiver
- ✅ `x-key-id` header for secret rotation (`SIGNING_KEYS`/`ACTIVE_KEY_ID`) — cadence/policy tracked as W05 in `docs/BACKLOG.md`
- ✅ CORS configuration on the Sender Worker (`ALLOWED_ORIGINS_JSON`)
- ✅ Service binding (`RECEIVER` → `api-provisioning-receiver`, no public network hop)

Remaining:

- Nonce store if replay protection must be stricter than timestamp-only — tracked as W06 in `docs/BACKLOG.md`
- ~~Monitoring/alerting + dashboards for the provisioning path — tracked as W04 in `docs/BACKLOG.md`.~~ Signals, alerting **and the dashboard** are implemented (see Monitoring Runbook below). The dashboard was recorded as blocked on `obtool-ingest` being repaired until 2026-08-08; that blocker only ever applied to routing through the internal OTEL pipeline, which was one of two options W04 step 3 offered — the Cloudflare Workers Analytics option needed nothing repaired. Note that `/send` error rate is among the signals *not* yet covered — `RECEIVER_ERROR` vs `INTERNAL_ERROR` vs the 502 "receiver-worker unreachable" path is distinguishable only in the response body, which Cloudflare's telemetry does not record, so it needs a counter emitted from the Worker.

## Monitoring Runbook

Daily alerting runs via `.github/workflows/worker-signals.yml` (W04 step 4). A
failing job triggers GitHub's notification emails to the repo owner. The signal
definitions and thresholds live in [`docs/observability-signals.md`](observability-signals.md).

### Running manually

```bash
CLOUDFLARE_API_TOKEN=$(doppler secrets get CLOUDFLARE_API_TOKEN \
  --project integrity-studio --config prd --plain) \
CLOUDFLARE_ACCOUNT_ID=$(doppler secrets get CLOUDFLARE_ACCOUNT_ID \
  --project integrity-studio --config prd --plain) \
SUPABASE_URL=$(doppler secrets get SUPABASE_URL \
  --project integrity-studio --config prd --plain) \
SUPABASE_SERVICE_ROLE_KEY=$(doppler secrets get SUPABASE_PROVISIONING_KEY \
  --project integrity-studio --config prd --plain) \
  npm run check:worker-signals
```

Or without Supabase (dead-letter depth is skipped):

```bash
CLOUDFLARE_API_TOKEN=$(doppler secrets get CLOUDFLARE_API_TOKEN \
  --project integrity-studio --config prd --plain) \
CLOUDFLARE_ACCOUNT_ID=$(doppler secrets get CLOUDFLARE_ACCOUNT_ID \
  --project integrity-studio --config prd --plain) \
  npm run check:worker-signals
```

Exit 0 = all within threshold (or SKIPPED if credentials absent), 1 = breach, 2 = check itself failed. The CI workflow calls `bash scripts/check-worker-signals.sh` directly; both forms are equivalent.

### The dashboard

`npm run dashboard:workers` (`scripts/worker-dashboard.sh`, W04 step 3) renders
the observation surface to read **when the gate above fires**, or when asking
whether the provisioning path is healthy. Same credentials as the check, same
`SKIPPED` behaviour without them:

```bash
CLOUDFLARE_API_TOKEN=$(doppler secrets get CLOUDFLARE_API_TOKEN \
  --project integrity-studio --config prd --plain) \
CLOUDFLARE_ACCOUNT_ID=$(doppler secrets get CLOUDFLARE_ACCOUNT_ID \
  --project integrity-studio --config prd --plain) \
  npm run dashboard:workers

# Default window is 7 days:
DASHBOARD_WINDOW_DAYS=30 npm run dashboard:workers
```

**It is not a gate and never exits non-zero on an unhealthy reading** — exit 0
rendered or skipped, 2 only if the API call itself failed. Keeping the two
separate is deliberate: a gate that also tries to be a dashboard accumulates
thresholds for things nobody wants to fail a build on.

Four panels:

| Panel | What it answers |
|---|---|
| Provisioning path | Is `sender-worker` → `api-provisioning-receiver` healthy end to end? Both on one panel because a receiver failure is indistinguishable from a sender failure otherwise. |
| Other production workers | Invocations, failure %, subrequest ratio, and the non-`success` status split per Worker. |
| Daily trend | Sparklines of successes and failures. **Each row is scaled to its own peak**, so heights compare within a row and never between rows. |
| Resource headroom | cpuTime p50/p99 against each Worker's *configured* `cpu_ms`, and memory p99 against the 128 MiB platform ceiling. |

The resource panel is the point of the dashboard. It is CR20's lesson applied to
the other failure mode: a Worker killed for exceeding CPU never runs handler
code, so it throws no exception and writes no log — error rate is blind to it in
exactly the way it was blind to `stripe-webhook`'s four-month outage. Watching
p99 against the limit predicts the kill before data starts being dropped.

Both the CPU limit and the observability setting are read live from each
script's settings endpoint rather than parsed from a `wrangler.toml`, so they
cannot drift from what is deployed and they work for the two Workers that deploy
out of `observability-toolkit`. The observability read is what lets the dashboard
distinguish "no invocations because idle" from "no invocations recorded because
the Worker is dark" — otherwise the same empty row.

Source is Cloudflare Workers Analytics (GraphQL) only, never Workers Logs. See
[`docs/observability-signals.md`](observability-signals.md) § Data sources for
why the two disagree and why an empty log query must never be read as "no
errors".

### What each breach means

**SIGNAL 1 — `scriptThrewException` on any owned Worker:**
An unhandled throw escaped the handler; the caller got a Cloudflare `1101`.
Check Workers Logs for the event (available from the time `observability` was
enabled; for `api-gateway` and `integrity-studio-contact` that is 2026-07-30).
Look for the error type and stack. If the root cause is not determinable from
logs alone, a recurrence will be diagnosable since all handlers now carry
`worker_uncaught_exception` log lines — wait for the next occurrence before
guessing.

**SIGNAL 2 — `stripe-webhook` subrequest ratio below threshold:**
The reconciliation cron fired but did not reach Supabase. CR20's key finding:
this is the check error rate cannot make (the cron reported `status: success`
for four months while making zero outbound calls). Check that `SUPABASE_URL`
and `SUPABASE_SERVICE_ROLE_KEY` are bound in the Worker settings
(`GET /accounts/.../workers/scripts/stripe-webhook/settings`). Also check
invocation count — if below 75% of the expected 96/day, the cron itself has
stopped firing; verify the `*/15` cron is present in Worker settings.

**SIGNAL 3 — `exceededResources` on any owned Worker:**
The isolate was killed for exceeding CPU or memory. No handler code ran. Check
for a recent code change that increased memory or CPU usage. If it is
`stripe-webhook`'s cron, check for a large dead-letter queue causing an
oversized Supabase response.

**SIGNAL 4 — `exceededResources` or `scriptThrewException` on `api-provisioning-receiver`:**
Reported but never fails this build — the receiver deploys from `observability-toolkit`.
File a finding against that repo; the cause is code there, not here. If
sustained, provision new keys will fail silently from the sender's perspective
(the sender returns `502` or `500` based on the receiver response).

**SIGNAL 5 — pending dead letters above threshold:**
The `*/15` reconciliation cron is not draining the queue. Confirm the cron is
running (SIGNAL 2 above). If the cron is running with healthy subrequest ratios,
the handler is failing post-claim — check Worker logs for `CRITICAL` lines in
`stripe-webhook`. Pending rows need the cron to drain; they will recover without
intervention once the cron is healthy.

**SIGNAL 5 — abandoned dead letters above zero:**
Retries are exhausted. These require a manual Stripe replay:
1. Log in to the [Stripe Dashboard](https://dashboard.stripe.com) → Developers → Webhooks.
2. Find the failed event(s) and use "Resend" to replay.
3. After the event processes, reset the `webhook_dead_letters` row `status` to
   `pending` and `retry_count` to `0` if the Worker dead-lettered again (the
   cron will then pick it up on the next `*/15` tick).

### Rate limits on investigations

`check:worker-signals` reads the Cloudflare GraphQL API using `CLOUDFLARE_API_TOKEN`. The
account-owned token (`cfat_` prefix) verifies only at
`/accounts/<id>/tokens/verify` — not the user endpoint — and requires **Account
Analytics Read**. A `403` here is a scope problem on the token, not an expired token.

## CORS and Origin Headers

The Sender Worker validates the request `Origin` against `ALLOWED_ORIGINS_JSON` and sets `Access-Control-Allow-Origin` on responses; OPTIONS preflight is handled and disallowed origins get a 403. Preflight responses allow `content-type, authorization, x-session-data` headers and `GET, POST, OPTIONS` methods (`CORS_HEADERS` in `workers/sender-worker/src/types.ts`). See `workers/sender-worker/src/utils.ts`.

### Origins

- **Production:** `https://integritystudio.ai`, `https://www.integritystudio.ai`
- **Development:** add `http://localhost:<port>` to `ALLOWED_ORIGINS_JSON` in the **dev** Doppler config

> The `Access-Control-Allow-Origin` header is NOT a security boundary — it only controls browser CORS preflight.
> The Sender Worker is the trust boundary; Flutter never sees the inter-service HMAC secret.

## References

- [Provisioning Environment Setup & Workflow](provisioning-environment-setup.md)
- [Worker Health Signals](observability-signals.md)
- [Client & Inter-Worker Contracts](inter-worker-contract-validation.md)
- [Provisioning Manual E2E Test Guide](PROVISIONING_MANUAL_TEST.md)
- [Cloudflare Workers Fetch API](https://developers.cloudflare.com/workers/runtime-apis/fetch/)
- [Cloudflare Workers Signing Requests](https://developers.cloudflare.com/workers/examples/signing-requests/)
- [Cloudflare Workers CORS](https://developers.cloudflare.com/workers/examples/cors-header-proxy/)
