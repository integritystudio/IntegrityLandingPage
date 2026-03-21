# JWT Claims Strategy — Compliance Review

**Date:** 2026-03-20
**Reviewed By:** Payment Processor Research Agent
**Status:** ACTIVE FINDINGS — Phase 1 Remediation Required

---

## Executive Summary

Your JWT claims strategy is fundamentally sound in architecture (immutable references, short TTL, no secrets) but has **8 compliance and security findings**, 3 of which require Phase 1 remediation:

1. **CRITICAL:** `billing_status` and `plan` are mutable state in an immutable token → up to 3600s staleness
2. **CRITICAL:** Missing `iss` claim validation → potential token forgery
3. **HIGH:** `email` PII in unencrypted JWT → GDPR data minimization risk
4. **HIGH:** HS256 vs RS256 mismatch between code and architecture docs

**Minimal remediation path:** Remove 3 mutable claims, add 2 validation checks → Phase 1 can ship with compliant tokens.

---

## Current JWT Architecture

From `TWO_LAYER_AUTH_ARCHITECTURE.md`, your Supabase Custom Access Token Hook produces:

```typescript
interface EnrichedJWT {
  // Standard claims
  sub: string;                         // auth.users.id
  email: string;
  iss: string;                         // "https://supabase.com"
  aud: "authenticated";
  iat: number;
  exp: number;                         // 3600s TTL

  // Custom claims
  org_ids: string[];
  default_org_id: string;
  default_org_plan: string;            // "free" | "growth" | "enterprise"
  default_org_role: string;            // "owner" | "admin" | "member" | "billing_admin" | "viewer"
  default_org_billing_status: string;  // "active" | "past_due" | "cancelled"
}
```

---

## Compliance Assessment

### ✅ What's Done Well

| Aspect | Assessment | Impact |
|--------|-----------|--------|
| **Immutability principle** | Excellent. Claims are stable references only. Mutable data (quota, usage) fetched server-side via `/bootstrap`. | Prevents stale authorization decisions for most claims. |
| **Short TTL (3600s)** | Good. 1-hour expiry limits blast radius of stolen tokens. | Standard for session tokens. |
| **No secrets in claims** | Correct. No API keys, passwords, or sensitive credentials. | Safe to log (if headers are scrubbed). |
| **Two-layer separation** | Strong design. Human identity (JWT) decoupled from machine access (API keys). | Enables independent revocation and lifecycle. |
| **Hash-only key storage** | `api_keys.hash` stores SHA-256 only. DB compromise doesn't leak live keys. | Industry best practice. |
| **JWT signature verification** | Implementation in `workers/lib/auth.ts` correctly verifies signature + expiry. | Prevents tampering. |

---

## Findings & Recommendations

### FINDING 1: `email` Claim — GDPR Data Minimization

**Severity:** 🟡 **MEDIUM** | **Standard:** GDPR Art. 5(1)(c) — Data Minimisation
**Phase:** 1 | **Effort:** 1-2 hours | **Status:** OPEN

#### Issue
```typescript
email: string;  // ← PII in every JWT
```

The `email` claim is base64-encoded (not encrypted) and may be exposed in:
- Request headers logged by proxies, CDNs, or observability tools
- Browser DevTools / Network tab
- Error reporting systems
- Cloudflare logs (if not scrubbed)

**Risk:** Incidental PII exposure across request pipeline violates GDPR Art. 5(1)(c) (data minimisation) if the email is not strictly necessary for every API operation.

#### Recommendation

**Phase 1 (Immediate):**
- Remove `email` from the Custom Access Token Hook output.
- The `sub` (user ID) is sufficient for identity resolution.
- If email is needed, query it server-side in the Worker:
  ```typescript
  // In Worker /bootstrap handler
  const user = await supabase
    .from('public.users')
    .select('email')
    .eq('id', linkRecord.app_user_id)
    .single();
  ```

**Phase 2 (Future):**
- Add a logging/scrubbing policy: ensure all pipelines scrub `Authorization` headers from logs.
- Document in RUNBOOK or SECURITY.md that JWT payloads (even if base64-encoded) are considered PII.

---

### FINDING 2: `default_org_billing_status` Claim — Staleness Window 🚨

**Severity:** 🔴 **CRITICAL** | **Standard:** SOC 2 CC6.1 / Billing Integrity
**Phase:** 1 | **Effort:** 2-3 hours | **Status:** REQUIRES REMEDIATION

#### Issue
```typescript
default_org_billing_status: string; // "active" | "past_due" | "cancelled"
```

This **violates your own design rule:** *"JWT claims are immutable references only. Dynamic state... is queried server-side."*

**Problem:** Billing status is mutable and driven by Stripe webhooks (`customer.subscription.updated`, `invoice.payment_failed`). The JWT won't reflect this until token refresh (up to 3600s away).

#### Risk Scenario
1. Stripe webhook fires → subscription becomes `past_due`
2. User's JWT still says `billing_status: "active"` for up to 59 minutes
3. Worker uses claim for access control → user retains access after payment failure
4. No audit trail of when the decision was made server-side

**Compliance impact:** Violates SOC 2 CC6.1 (system monitoring), as you cannot reliably detect when a user should have been denied access.

#### Recommendation

**REMOVE `default_org_billing_status` from JWT immediately.**

Query billing status server-side when access decisions depend on it:

```typescript
// In Worker middleware (before proxying request)
const org = await supabase
  .from('public.organizations')
  .select('billing_status')
  .eq('id', jwt.default_org_id)
  .single();

if (org.billing_status === 'past_due' || org.billing_status === 'cancelled') {
  return Response.json(
    { error: 'billing_suspended', message: 'Please resolve your payment' },
    { status: 403, headers: { 'Retry-After': '3600' } }
  );
}
```

**Cache optimization:** If you need edge-speed decisions, store billing status in the Durable Object alongside quota state and invalidate on Stripe webhook receipt.

---

### FINDING 3: `default_org_plan` Claim — Same Staleness Issue 🚨

**Severity:** 🔴 **CRITICAL** | **Standard:** Billing Accuracy / Rate Limiting Integrity
**Phase:** 1 | **Effort:** 1-2 hours | **Status:** REQUIRES REMEDIATION

#### Issue
```typescript
default_org_plan: string; // "free" | "growth" | "enterprise"
```

Plan changes (upgrades/downgrades) are driven by Stripe webhooks. A user who upgrades won't get elevated rate limits until their JWT refreshes. A downgraded user retains premium access for up to an hour.

#### Risk Scenario
1. User's plan is `free` (60 req/min rate limit)
2. They upgrade to `growth` (600 req/min)
3. For up to 59 minutes, Cloudflare rate limiter uses JWT claim `plan: "free"` → enforces 60 req/min
4. User doesn't get paid capacity they just purchased
5. Conversely, downgraded user gets free tier burst access post-downgrade

**Compliance impact:** Breaks the billing-to-service mapping (RFC 3986 § 6.2.3 — "Reliable rate limit enforcement").

#### Recommendation

**REMOVE `default_org_plan` from JWT.**

Resolve plan tier server-side for Cloudflare rate limiter decisions:

```typescript
// In Worker, after JWT validation
const plan = await (
  // Option A: Direct query (slower)
  supabase
    .from('public.organizations')
    .select('current_plan')
    .eq('id', jwt.default_org_id)
    .single()
);

// Option B: Cache in Durable Object (faster, invalidate on webhook)
const quotaDO = env.ORG_QUOTA.get(env.ORG_QUOTA.idFromName(jwt.default_org_id));
const snapshot = await quotaDO.fetch('https://do/snapshot').then(r => r.json());
const plan = snapshot.orgPlan;

// Apply rate limit based on CURRENT plan, not JWT claim
const rateLimit = PLAN_LIMITS[plan]; // { free: 60, growth: 600, enterprise: 3000 }
const rateLimitOk = await env[`RATE_LIMITER_${plan.toUpperCase()}`].limit({ key: org_id });
```

---

### FINDING 4: Missing `nbf` (Not Before) Claim Validation

**Severity:** 🟡 **LOW** | **Standard:** RFC 7519 § 4.1.5
**Phase:** 1 | **Effort:** 15 minutes | **Status:** QUICK WIN

#### Issue

Your `verifyJwt` in `workers/lib/auth.ts` checks `exp` but not `nbf`:

```typescript
// Current implementation (line ~52)
if (typeof payload.exp !== 'number' || payload.exp < now) {
  return { ok: false, error: unauthorized('JWT expired') };
}
// ❌ Missing: nbf check
```

The `nbf` (Not Before) claim prevents premature use of tokens in clock-skew scenarios.

#### Recommendation

Add this validation to `workers/lib/auth.ts`:

```typescript
// After exp check
if (typeof payload.nbf === 'number' && payload.nbf > now) {
  return { ok: false, error: unauthorized('JWT not yet valid') };
}
```

This is a RFC 7519 SHOULD (best practice) and is a 15-minute implementation.

---

### FINDING 5: No `jti` (JWT ID) for Replay Protection

**Severity:** 🟡 **LOW-MEDIUM** | **Standard:** RFC 7519 § 4.1.7 / OWASP Token Best Practices
**Phase:** 2 | **Effort:** 4-6 hours | **Status:** DEFERRED TO PHASE 2

#### Issue

Without a unique `jti` (JWT ID), there's no mechanism to detect or prevent JWT replay within the 3600s validity window.

#### Risk Scenario (Low probability, high impact)
1. Attacker intercepts a JWT over an insecure connection
2. Attacker replays the same JWT multiple times → multiple Cloudflare Worker requests are honored
3. No audit trail distinguishes the legitimate request from replays

#### Recommendation

**Phase 2:**
1. **Supabase Custom Access Token Hook:** Add `jti` (UUID) to the JWT:
   ```typescript
   {
     "jti": "550e8400-e29b-41d4-a716-446655440000",
     "iat": ...,
     "exp": ...
   }
   ```

2. **Workers Middleware:** For sensitive endpoints (billing, key rotation), check `jti` against a Cloudflare KV cache:
   ```typescript
   const jti = jwt.jti;
   const seen = await env.JWT_REPLAY_CACHE.get(jti);
   if (seen) {
     return { ok: false, error: unauthorized('Token already used') };
   }
   await env.JWT_REPLAY_CACHE.put(jti, '1', { expirationTtl: jwt.exp - now });
   ```

This is a Phase 2 hardening measure, not blocking Phase 1 ship.

---

### FINDING 6: HS256 vs RS256 Mismatch — Code/Docs Divergence

**Severity:** 🟡 **MEDIUM** | **Standard:** OWASP JWT Security / OAuth 2.0 Best Practices
**Phase:** 2-3 | **Effort:** 4-8 hours | **Status:** DOCUMENT & DEFER

#### Issue

**Code (`workers/lib/auth.ts`)** uses HS256 (HMAC):
```typescript
const key = await crypto.subtle.importKey(
  'raw',
  encoder.encode(jwtSecret),  // ← Shared secret
  { name: 'HMAC', hash: 'SHA-256' },
  ...
);
```

**Docs (`TWO_LAYER_AUTH_ARCHITECTURE.md`)** suggest RS256 (asymmetric):
```typescript
const publicKey = await getSupabasePublicKey(env.SUPABASE_URL);
```

#### Trade-offs

| Aspect | HS256 (HMAC) | RS256 (Asymmetric) |
|--------|-------|-----------|
| **Verification** | Uses shared secret | Uses public key only |
| **Forgeability** | ⚠️ Any Worker with secret can forge | ✅ Only Supabase can sign |
| **Secret rotation** | Hard — must update all Workers | Easy — rotate private key, publish new public key |
| **Standard for Supabase** | ✅ Supabase default | Also supported |

#### Recommendation

**Phase 1 (Ship with HS256):**
- HS256 is Supabase's default and is safe if the secret is protected (stored in Cloudflare Workers secrets, not in `wrangler.toml`).
- **Update** `TWO_LAYER_AUTH_ARCHITECTURE.md` to reflect HS256 with explicit justification:
  ```markdown
  We use HS256 (HMAC-SHA256) verification in alignment with Supabase's default token format.
  The JWT secret is stored in Cloudflare Workers secrets and is not exposed in code.

  Future (Phase 3): Consider migration to RS256 using Supabase's JWKS endpoint
  at {SUPABASE_URL}/auth/v1/.well-known/jwks.json for asymmetric verification.
  ```

**Phase 3 (Optional upgrade to RS256):**
```typescript
// Fetch JWKS from Supabase (cache with short TTL)
const jwks = await fetch(`${env.SUPABASE_URL}/auth/v1/.well-known/jwks.json`)
  .then(r => r.json());

// Use asymmetric verification instead
const publicKey = crypto.subtle.importKey('jwk', jwks.keys[0], ...);
```

---

### FINDING 7: `org_ids` Array — Scope Leakage

**Severity:** 🟢 **LOW** | **Standard:** Principle of Least Privilege
**Phase:** 2 | **Effort:** 1-2 hours | **Status:** DEFERRED TO PHASE 2

#### Issue
```typescript
org_ids: string[];  // ALL orgs user belongs to
```

Every API call transmits the user's full org membership list. If a JWT is intercepted, the attacker learns the user's complete org structure.

#### Risk Assessment (Low)
- The org IDs are UUIDs (non-guessable).
- The risk is informational, not exploitable.
- Useful for client-side UI (showing all accessible orgs in a dropdown).

#### Recommendation

**Phase 2:**
- Consider removing `org_ids` from the JWT.
- Clients can query accessible orgs server-side via `/bootstrap` or `/list-orgs`.
- If kept: document it as a trade-off and note that JWT payloads are PII (don't log them).

---

### FINDING 8: No `iss` (Issuer) Claim Validation 🚨

**Severity:** 🔴 **CRITICAL** | **Standard:** RFC 7519 § 4.1.1 / OAuth 2.0 Security
**Phase:** 1 | **Effort:** 15 minutes | **Status:** QUICK WIN

#### Issue

Your `verifyJwt` function validates signature and expiry but does **not** verify the `iss` (issuer) claim:

```typescript
// workers/lib/auth.ts — ❌ Missing iss check
```

#### Risk
A JWT signed with a valid signature but issued by a different Supabase project (or attacker-controlled issuer) would be accepted, bypassing the intended authorization boundary.

#### Recommendation

Add issuer validation to `workers/lib/auth.ts` immediately:

```typescript
const EXPECTED_ISSUER = `${env.SUPABASE_URL}/auth/v1`;

function verifyJwt(payload: any, now: number): Result {
  // ... existing checks ...

  // Add issuer validation
  if (payload.iss !== EXPECTED_ISSUER) {
    return { ok: false, error: unauthorized('Invalid JWT issuer') };
  }

  return { ok: true, payload };
}
```

**Impact:** 15 minutes to implement, blocks token forgery from other Supabase projects.

---

## Compliance Summary Matrix

| # | Finding | Severity | Standard | Phase | Effort | Status |
|---|---------|----------|----------|-------|--------|--------|
| 1 | `email` PII in JWT | 🟡 MEDIUM | GDPR 5(1)(c) | 1 | 1-2h | ⏳ OPEN |
| 2 | `billing_status` staleness | 🔴 **CRITICAL** | SOC 2 CC6.1 | 1 | 2-3h | 🚨 **REQUIRES FIX** |
| 3 | `plan` staleness | 🔴 **CRITICAL** | Billing accuracy | 1 | 1-2h | 🚨 **REQUIRES FIX** |
| 4 | Missing `nbf` validation | 🟢 LOW | RFC 7519 | 1 | 15m | ✅ QUICK WIN |
| 5 | No `jti` replay protection | 🟡 LOW-MED | OWASP / RFC 7519 | 2 | 4-6h | ⏳ PHASE 2 |
| 6 | HS256 vs RS256 mismatch | 🟡 MEDIUM | OWASP / OAuth 2.0 | 2-3 | 4-8h | 📝 DOCUMENT & DEFER |
| 7 | `org_ids` scope leakage | 🟢 LOW | Least Privilege | 2 | 1-2h | ⏳ PHASE 2 |
| 8 | No `iss` validation | 🔴 **CRITICAL** | RFC 7519 / OAuth 2.0 | 1 | 15m | 🚨 **QUICK WIN** |

---

## Minimal Phase 1 Remediation Path

**To ship Phase 1 with compliant tokens, address these 5 items (~5-6 hours total):**

```
[ ] 1. Remove `default_org_billing_status` from JWT + query server-side (Finding 2) — 2-3h
[ ] 2. Remove `default_org_plan` from JWT + query server-side (Finding 3) — 1-2h
[ ] 3. Add `nbf` validation to workers/lib/auth.ts (Finding 4) — 15m
[ ] 4. Add `iss` validation to workers/lib/auth.ts (Finding 8) — 15m
[ ] 5. Update TWO_LAYER_AUTH_ARCHITECTURE.md with HS256 justification (Finding 6) — 15m
```

**Stretch (optional for Phase 1, but nice to have):**
```
[ ] Remove `email` from JWT + document PII handling (Finding 1) — 1-2h
```

### Recommended Minimal JWT (Post-Remediation)

```typescript
interface ComplianceMinimalJWT {
  // RFC 7519 standard claims
  sub: string;              // auth.users.id (user identity)
  iss: string;              // issuer (validated against SUPABASE_URL)
  aud: "authenticated";
  iat: number;              // issued at
  exp: number;              // expires (3600s)
  nbf: number;              // not before (iat or iat - 30s for clock skew)

  // Custom claims — references only
  default_org_id: string;
  default_org_role: string; // "owner" | "admin" | "member" | "billing_admin" | "viewer"
}
```

**Removed:**
- `email` (PII, not needed for every request)
- `default_org_plan` (mutable, resolved server-side)
- `default_org_billing_status` (mutable, resolved server-side)
- `org_ids` (informational leakage, query from `/bootstrap`)

**Added:**
- `nbf` (RFC 7519 SHOULD)
- `iss` validation

---

## Phase 2 & 3 Roadmap

### Phase 2 (Robustness & Observability)
- Add `jti` to JWT + implement replay detection (Finding 5) — 4-6h
- Remove `org_ids` from JWT (Finding 7) — 1-2h
- Implement server-side logging + Authorization header scrubbing — 3-4h

### Phase 3 (Optional: RS256 Migration)
- Migrate from HS256 to RS256 using Supabase JWKS endpoint (Finding 6) — 4-8h
- Consider third-party audit of JWT handling — varies

---

## Implementation Checklist

### Before Phase 1 Ship

- [ ] Remove `default_org_billing_status` from Supabase Custom Access Token Hook
- [ ] Remove `default_org_plan` from Supabase Custom Access Token Hook
- [ ] Add server-side plan/billing status query in Worker middleware
- [ ] Add `nbf` validation to `workers/lib/auth.ts`
- [ ] Add `iss` validation to `workers/lib/auth.ts`
- [ ] Update `TWO_LAYER_AUTH_ARCHITECTURE.md` to remove mutable claims
- [ ] Update `TWO_LAYER_AUTH_ARCHITECTURE.md` with HS256 justification
- [ ] Test JWT verification with updated claims
- [ ] Run compliance checklist with legal/security team

### Phase 2 Backlog

- [ ] Add `jti` to Supabase Custom Access Token Hook
- [ ] Implement JWT replay detection in sensitive endpoints
- [ ] Add logging/scrubbing policy for Authorization headers
- [ ] Consider removing `org_ids` from JWT
- [ ] Audit KV/Durable Object retention policies for PII

### Phase 3 Backlog

- [ ] Evaluate RS256 migration using Supabase JWKS
- [ ] Third-party JWT security audit (if regulatory required)

---

## Related Documentation

- **[Two-Layer Auth Architecture](../TWO_LAYER_AUTH_ARCHITECTURE.md)** — Updated to reflect compliant JWT design
- **[Durable Object Quota Enforcement](../DURABLE_OBJECT_QUOTA_ARCHITECTURE.md)** — Plan/billing status resolution
- **[Supabase Auth Setup](../supabase-auth-setup.md)** — Custom Access Token Hook configuration
- **[Workers Library Tests](../../workers/tests/)** — JWT verification tests

---

## References

- RFC 7519: JSON Web Token (JWT) — https://tools.ietf.org/html/rfc7519
- OWASP: JSON Web Token Best Practices — https://cheatsheetseries.owasp.org/cheatsheets/JSON_Web_Token_for_Java_Cheat_Sheet.html
- GDPR Article 5(1)(c): Data Minimisation — https://gdpr-info.eu/art-5-gdpr/
- SOC 2 CC6.1: Change Management — https://www.aicpa.org/interestareas/informationmanagement/audiencesandtopics/soc-2

---

## Appendix: Quick Reference — What Changed

### Before (Current)
```typescript
// JWT includes mutable state
default_org_plan: "growth",
default_org_billing_status: "active"
```

### After (Compliant)
```typescript
// JWT is lean reference only
default_org_id: "org-uuid",
default_org_role: "admin"

// Mutable state is queried server-side
const { plan, billing_status } = await supabase
  .from('organizations')
  .select('current_plan, billing_status')
  .eq('id', jwt.default_org_id);
```

---

**Document Status:** ACTIVE
**Last Updated:** 2026-03-20
**Review Cycle:** Quarterly (next: 2026-06-20)
**Owner:** Payment Processor Team / Security Lead
