# JWT Claims Strategy — Compliance Review

> **Research record — phase-1 implemented.** Mutable JWT claims removed (1.2 `M18-V01`); `iss`/`nbf`/`aud` validation lives in `workers/lib/auth.ts`. Remaining open item: `email` in the JWT payload. Condensed from the original; see [changelog 1.3](../changelog/1.3/CHANGELOG.md) "Superseded Design-Doc Reconciliation".

**Original date:** 2026-03-20 · **Domain:** JWT security / compliance

---

## Summary

The JWT claims strategy was architecturally sound (immutable references, short TTL, no secrets) but carried 8 findings, three of which blocked Phase 1: mutable `billing_status`/`plan` claims in an immutable token (up to 3600s staleness), missing `iss` validation (token-forgery risk), and `email` PII in an unencrypted payload.

## Current JWT shape (as reviewed)

Produced by the Supabase Custom Access Token Hook, from `TWO_LAYER_AUTH_ARCHITECTURE.md`:

```typescript
interface EnrichedJWT {
  sub: string; email: string; iss: string; aud: "authenticated"; iat: number; exp: number; // 3600s TTL
  org_ids: string[];
  default_org_id: string;
  default_org_plan: string;            // "free" | "growth" | "enterprise"
  default_org_role: string;            // "owner" | "admin" | "member" | "billing_admin" | "viewer"
  default_org_billing_status: string;  // "active" | "past_due" | "cancelled"
}
```

## What was done well

- **Immutability principle**: claims are stable references; mutable data (quota, usage) is fetched server-side via `/bootstrap`.
- **Short TTL (3600s)**: limits blast radius of a stolen token.
- **No secrets in claims**: no API keys/passwords.
- **Two-layer separation**: human identity (JWT) decoupled from machine access (API keys) — independent revocation/lifecycle.
- **Hash-only key storage**: `api_keys.hash` is SHA-256 only; DB compromise doesn't leak live keys.
- **Signature + expiry verification**: implemented correctly in `workers/lib/auth.ts`.

## Findings

### 1. `email` claim — GDPR data minimization
**Severity: Medium · GDPR Art. 5(1)(c) · Status: still open**

`email` is base64-encoded, not encrypted, and can leak via proxy/CDN/observability logs, browser DevTools, or error reporting. The `sub` (user ID) is sufficient for identity resolution; email should be queried server-side (`SELECT email FROM public.users WHERE id = ...`) only when actually needed. Longer-term: scrub `Authorization` headers from all logging pipelines and document that JWT payloads (even base64) are PII.

### 2. `default_org_billing_status` — staleness window
**Severity: Critical · SOC 2 CC6.1 · Status: implemented (removed)**

Violated the project's own rule that JWT claims are immutable references only. Billing status is driven by Stripe webhooks (`customer.subscription.updated`, `invoice.payment_failed`); a JWT claim would lag reality for up to 3600s, meaning a user could retain access for up to 59 minutes after a payment failure with no server-side audit trail of the decision. Resolution: query `organizations.billing_status` server-side (or cache in the Durable Object, invalidated on Stripe webhook receipt) rather than trusting the claim.

### 3. `default_org_plan` — same staleness issue
**Severity: Critical · Billing/rate-limit accuracy · Status: implemented (removed)**

An upgraded user wouldn't get elevated rate limits, and a downgraded user would retain premium access, for up to an hour if plan were read from the JWT. Resolution: resolve plan tier server-side (direct query, or cached in the Durable Object and invalidated on webhook) and apply the rate limit based on current plan, never the JWT claim.

### 4. Missing `nbf` (Not Before) validation
**Severity: Low · RFC 7519 §4.1.5 · Status: implemented**

`verifyJwt` checked `exp` but not `nbf`, which exists to prevent premature token use under clock skew. 15-minute fix, added to `workers/lib/auth.ts`.

### 5. No `jti` (JWT ID) for replay protection
**Severity: Low-medium · OWASP / RFC 7519 §4.1.7 · Status: deferred (Phase 2, not implemented)**

Without a unique `jti`, an intercepted JWT can be replayed for its full validity window with no way to distinguish replays from legitimate requests. Proposed design: add a `jti` (UUID) at issuance, and for sensitive endpoints check it against a Cloudflare KV cache (`JWT_REPLAY_CACHE`), rejecting if already seen and writing it with a TTL matching `exp - now`.

### 6. HS256 vs RS256 mismatch — code/docs divergence
**Severity: Medium · OWASP JWT / OAuth 2.0 · Status: documented, not changed**

`workers/lib/auth.ts` verifies with HS256 (shared secret via `crypto.subtle.importKey`), while `TWO_LAYER_AUTH_ARCHITECTURE.md` described RS256 (asymmetric, via Supabase's public key). HS256 is Supabase's default and is safe as long as the secret lives only in Cloudflare Workers secrets (never `wrangler.toml`) — its downside is that secret rotation requires updating every Worker, versus RS256 where only the private key rotates and the public key is republished. Decision: ship HS256 for Phase 1 with that justification documented; consider migrating to RS256 via Supabase's JWKS endpoint (`{SUPABASE_URL}/auth/v1/.well-known/jwks.json`) as an optional future hardening step.

### 7. `org_ids` array — scope leakage
**Severity: Low · Principle of least privilege · Status: deferred (Phase 2, not implemented)**

Every request transmits the user's full org membership list. Risk is informational rather than exploitable (org IDs are non-guessable UUIDs), but it's more than the request needs. Option: drop `org_ids` from the JWT and let clients query accessible orgs via `/bootstrap` or `/list-orgs`; if kept, treat the JWT payload as PII for logging purposes.

### 8. No `iss` (Issuer) validation
**Severity: Critical · RFC 7519 §4.1.1 / OAuth 2.0 · Status: implemented**

`verifyJwt` checked signature and expiry but not `iss`, meaning a validly-signed JWT from a different Supabase project (or an attacker-controlled issuer) would be accepted, bypassing the intended authorization boundary. Fix: compare `payload.iss` against `${env.SUPABASE_URL}/auth/v1` and reject on mismatch. 15-minute fix.

## Recommended minimal JWT (post-remediation)

```typescript
interface ComplianceMinimalJWT {
  sub: string; iss: string; aud: "authenticated"; iat: number; exp: number; nbf: number;
  default_org_id: string;
  default_org_role: string; // "owner" | "admin" | "member" | "billing_admin" | "viewer"
}
```

Removed: `email` (PII, not needed per-request — open item), `default_org_plan` and `default_org_billing_status` (mutable, resolved server-side — done), `org_ids` (informational leakage, resolved via `/bootstrap` — deferred). Added: `nbf`, `iss` validation.

## Findings-to-standard reference

| # | Finding | Standard | Status |
|---|---------|----------|--------|
| 1 | `email` PII in JWT | GDPR 5(1)(c) | Open |
| 2 | `billing_status` staleness | SOC 2 CC6.1 | Implemented |
| 3 | `plan` staleness | Billing accuracy | Implemented |
| 4 | Missing `nbf` validation | RFC 7519 | Implemented |
| 5 | No `jti` replay protection | OWASP / RFC 7519 | Deferred (Phase 2) |
| 6 | HS256 vs RS256 mismatch | OWASP / OAuth 2.0 | Documented, deferred |
| 7 | `org_ids` scope leakage | Least privilege | Deferred (Phase 2) |
| 8 | No `iss` validation | RFC 7519 / OAuth 2.0 | Implemented |
