// HMAC replay protection window (receiver-worker)
export const REPLAY_WINDOW_MS = 5 * 60 * 1000; // 5 minutes

// Dead letter queue: max retry attempts before abandoning
export const DEAD_LETTER_MAX_RETRIES = 5;
// Initial retry delay (ms) for dead letters; doubles on each retry (exponential backoff)
export const DEAD_LETTER_INITIAL_RETRY_DELAY_MS = 60_000; // 1 minute

// CSRF configuration
export const CSRF_TOKEN_MAX_AGE_MS = 60 * 60 * 1000; // 1 hour

// API timeout configuration - 8s to leave headroom for client's 10s timeout
export const RESEND_API_TIMEOUT_MS = 8000;

// Rate limiting defaults
export const DEFAULT_RATE_LIMIT_MAX = 5;
export const DEFAULT_RATE_LIMIT_WINDOW_SECONDS = 60;

// In-memory rate limit store bounds
export const MAX_IN_MEMORY_ENTRIES = 10000;
// Soft threshold: trigger expired-entry cleanup before eviction
export const IN_MEMORY_CLEANUP_THRESHOLD = 1000;

// Circuit breaker: KV failure handling
// Threshold set to 10 to prevent single-attacker trips (see backlog #22)
export const KV_CIRCUIT_BREAKER_THRESHOLD = 10;
// Cooldown before retrying KV after circuit opens
export const KV_CIRCUIT_RESET_COOLDOWN_MS = 60_000;
// Random jitter added to cooldown to avoid thundering herd on recovery
export const KV_CIRCUIT_RESET_JITTER_MS = 30_000;
// Minimum KV TTL to prevent immediate expiry on short windows
export const MIN_KV_TTL_SECONDS = 60;
// TTL for idempotency keys to prevent duplicate submission processing (5 min)
export const IDEMPOTENCY_TTL_SECONDS = 300;

// Maximum request body size (10KB - generous for a contact form)
export const MAX_REQUEST_BODY_BYTES = 10_240;

// Field length limits for security (prevent memory exhaustion, DoS)
export const MAX_NAME_LENGTH = 100;
export const MAX_EMAIL_LENGTH = 254;
export const MAX_ORGANIZATION_LENGTH = 200;
export const MAX_COMPANY_SIZE_LENGTH = 100;
export const MAX_USE_CASE_LENGTH = 200;
export const MAX_MESSAGE_LENGTH = 5000;
