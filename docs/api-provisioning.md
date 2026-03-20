# API Provisioning Architecture (Flutter)

Flutter-side architecture for Worker-to-Worker API provisioning with HMAC-signed inter-service auth.

## Request Flow

```text
Flutter app
   -> POST /send -> Sender Worker (signs request)
                       -> signed POST /inbox -> Receiver Worker (verifies)

Flutter app
   -> GET /health -> Receiver Worker (public, no auth)
```

Flutter never holds the inter-service shared secret. The browser/mobile client calls the Sender Worker over plain HTTPS; the Sender Worker signs and forwards to the Receiver Worker.

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
│  └─ GET /health                       │
└──────┬───────────────────────────────┘
       │
       ├─────────► Supabase Auth
       │           (email, password, JWT)
       │
       └─────────► Receiver Worker
                   (internal forwarding)
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
               ▼ HTTPS POST (internal)
┌─────────────────────────────────────────────────────────────────┐
│ POST /inbox (with x-signature, x-timestamp headers)             │
│ To: Receiver Worker                                              │
│ Body: {action, jwt, name, tier} (same as request)               │
└──────────────┬──────────────────────────────────────────────────┘
               │
               ▼ (Receiver Worker)
┌─────────────────────────────────────────────────────────────────┐
│ 1. Validate signature using SHARED_SECRET                        │
│ 2. Validate timestamp (prevent replay attacks)                   │
│ 3. Validate JWT via Supabase /auth/v1/user                       │
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
| 2 | Sender Worker | Receiver Worker | HMAC signature | Yes (x-signature) |
| 3 | Receiver Worker | Supabase Auth | Bearer JWT | Yes (JWT token) |
| 4 | Receiver Worker | Supabase Edge Function | Bearer JWT | Yes (JWT token) |
| 5 | Edge Function | Receiver Worker | — | Edge function response |
| 6 | Receiver Worker | Sender Worker | — | Internal response |
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
  defaultValue: 'https://sender-worker.example.workers.dev',
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
    ProvisioningEvent event,
  ) async {
    for (var attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        final response = await _dio.post(
          '$_senderWorkerUrl/send',
          data: jsonEncode(event.toJson()),
          options: Options(
            headers: {'Content-Type': 'application/json'},
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
  static Future<ProvisioningResponse> checkHealth(
    String receiverUrl,
  ) async {
    try {
      final response = await _dio.get('$receiverUrl/health');
      final data = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : const <String, dynamic>{};
      if (response.statusCode == HttpStatus.ok.code &&
          data['ok'] == true) {
        return ProvisioningSuccess(data: data);
      }
      return const ProvisioningError(error: _errorServer);
    } on DioException catch (e) {
      await ErrorTrackingService.captureException(e,
          context: 'ProvisioningService.checkHealth');
      return const ProvisioningError(error: _errorNetwork);
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
- POST /send endpoint with JSON validation
- HMAC-SHA256 signature computation (timestamp + body)
- Forwards signed request to Receiver Worker with x-timestamp and x-signature headers

✅ **Receiver Worker** (`workers/receiver-worker/src/index.ts`)
- GET /health public endpoint
- POST /inbox with signature verification (constant-time comparison)
- 5-minute replay protection window (REPLAY_WINDOW_MS)

⚠️ **CORS & Origin Validation** — NOT YET IMPLEMENTED
- Sender Worker must configure `Access-Control-Allow-Origin` header(s) for Flutter app origin(s)
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
| Inter-service auth | HMAC-SHA256 signature (Workers only) |
| Replay protection | `x-timestamp` header, 5-minute window |
| Secret storage | Wrangler secrets (`SHARED_SECRET`), never in Flutter |
| Client auth | None required (Sender Worker is the trust boundary) |
| CORS | Sender Worker must allow the Flutter app origin |

The Flutter app treats the Sender Worker as a trusted proxy. It sends plain JSON over HTTPS; the Sender Worker appends `x-timestamp` and `x-signature` headers before forwarding to the Receiver Worker.

## Worker Contracts

### Sender Worker

| Method | Path | Request Body | Response |
|--------|------|-------------|----------|
| POST | `/send` | `ProvisioningEvent` JSON | `{ ok: true, received: ... }` or `{ error: "..." }` |

### Receiver Worker

| Method | Path | Auth | Response |
|--------|------|------|----------|
| GET | `/health` | None | `{ ok: true, service: "receiver-worker" }` |
| POST | `/inbox` | `x-timestamp` + `x-signature` headers | `{ ok: true, received: ... }` or `{ error: "..." }` |

## Testing Strategy

Follow the existing `contact_service_test.dart` patterns:

- Mock Dio via `@visibleForTesting` setter
- Override `retryDelay` to avoid real delays
- Test retry count on 500/504/timeout (assert `postCallCount`)
- Test sealed response type matching
- Test `--dart-define` URL override behavior

## Production Hardening

Before shipping:

- Constant-time signature comparison in the Receiver Worker
- `x-key-id` header for secret rotation support
- Nonce store if replay protection must be stricter than timestamp-only
- CORS configuration on the Sender Worker for the Flutter app origin
- Service bindings if both Workers are in the same Cloudflare account (avoids public network hop)

## CORS and Origin Headers

**Current Gap:** Sender Worker does not yet validate or set CORS headers for the Flutter app origin.

### Required Setup

The Sender Worker's `/send` endpoint must respond with `Access-Control-Allow-Origin` header(s) to allow browser-based Flutter Web requests:

```typescript
// In Sender Worker handleSend() or as a middleware
const corsHeaders = {
  'Access-Control-Allow-Origin': 'https://example.com', // Flutter app origin
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'content-type',
};

// Handle OPTIONS preflight
if (request.method === 'OPTIONS') {
  return new Response(null, { headers: corsHeaders, status: 204 });
}

// Add to POST response
return new Response(body, { status, headers: { ...corsHeaders, 'content-type': ... } });
```

### Production Origins

- **Staging:** `https://staging.example.com`
- **Production:** `https://www.example.com`
- **Development:** `http://localhost:8081` (for local flutter run -d chrome)

> The `Access-Control-Allow-Origin` header is NOT a security boundary — it only controls browser CORS preflight.
> The Sender Worker is the trust boundary; Flutter never sees the inter-service HMAC secret.

## References

- [Cloudflare Workers Fetch API](https://developers.cloudflare.com/workers/runtime-apis/fetch/)
- [Cloudflare Workers Signing Requests](https://developers.cloudflare.com/workers/examples/signing-requests/)
- [Cloudflare Workers CORS](https://developers.cloudflare.com/workers/examples/cors-header-proxy/)
