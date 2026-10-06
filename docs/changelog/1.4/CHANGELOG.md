# Changelog — Version 1.4

All notable changes to the IntegrityStudio.ai Flutter project and Cloudflare Workers.

> Migrated verbatim from `docs/BACKLOG.md` on 2026-10-06. Heading normalised; body unchanged.

---

## [2026-10-06] - Infrastructure and Security Audit Fixes

### T28: Handle Persistent Storage Data Loss Risk in Quota DO

**Priority:** P3 | **Source:** session 2026-03-20, quota commit review (523518f)

Quota state is lazily persisted to Durable Object storage every 10 seconds (originally `quota.ts:174–177`; the save and the flush alarm are now `workers/api-gateway/src/durable-objects/quota.ts:242–255`). If the DO crashes or is evicted between saves, up to 10 seconds of quota usage is lost (counts are dropped, monthly counter reverts).

> **Audit 2026-07-27 — the risk cannot be assessed from production data, because there is none.** Step 1 asks whether 10-second loss is acceptable and notes it "needs confirmation". That confirmation is currently unobtainable: `api-gateway` has had zero secrets since 2026-03-31 ([[CR12]]) and no zone route ([[CR13]]), so the quota system **has never run against real traffic**. Eviction rate, save frequency, and realistic loss windows are all unmeasured. Step 4's DO metrics dashboard is likewise unbuildable today — the worker has `observability` unset entirely, so it emits nothing.
>
> Two things that raise the stakes once it does run: quota gates the **customer-facing** ingestion path ([[CR16]]), so dropped counts are a billing-accuracy question and not just an internal one; and the DO namespaces are confirmed distinct between environments (`14813730…` production, `30f146ce…` dev), so dev traffic cannot pollute production counters — that part is sound.
>
> **Sequence:** [[CR12]] → [[CR15]]-style observability on the gateway → measure → then decide the durability trade-off. Deciding it now would be picking a number from nothing.
>
> **Update 2026-07-27 evening — the first gate has opened.** [[CR12]] is largely resolved: the gateway has database access and answers healthy, so the quota system *can* now run. Two blockers remain before the measurement in step 1 is possible. Observability is configured but **not deployed** ([[W04]] step 1), so the Worker still emits nothing; and there is still no zone route ([[CR13]]), so real customer traffic cannot reach it. The sequence is unchanged, it has simply advanced one step.
>
> **Update 2026-07-30 — the observability blocker is gone; the traffic one is not.** `api-gateway` was deployed and now reports `enabled=True logs=True traces=True`, so the Worker emits for the first time and the quota DO's behaviour is finally readable. The same deploy also shipped `76706a1`, which flushes DO state via an alarm — **that partially pre-empts this item**, so re-read step 2 before designing anything: the 10-second loss window may already be narrower than this entry assumes. What still blocks a real measurement is that there is no zone route ([[CR13]]), so production quota traffic is whatever reaches the `workers.dev` hostname rather than a customer-facing endpoint.
>
> **Update 2026-10-06 — the traffic blocker is gone too.** The "no zone route" lines above went stale on 2026-08-08, when [[CR13]] gave `api-gateway` its own hostname, `api.integritystudio.dev`, so customer-facing requests reach the quota DO without going through `workers.dev`. Nothing in this item is blocked on routing or observability any more.

**Scope:**
1. Evaluate risk appetite: Is 10-second data loss acceptable for quota tracking? (likely yes for low-tier plans, needs confirmation)
2. If higher durability is required:
   - Change save interval to synchronous: save immediately after every reservation (impacts latency)
   - OR batch saves: write to Durable Object every 100 requests OR 5 seconds (hybrid approach)
   - OR implement eventual consistency mode: accept up-to-10s drift, document in API contract
3. Document the chosen strategy in `workers/docs/QUOTA_DURABLE_OBJECTS.md` with:
   - Data consistency SLA
   - Acceptable loss window
   - When DO eviction is expected (low-traffic orgs evicted after 15 min idle)
4. Add monitoring: Cloudflare Durable Object metrics dashboard to track eviction rate

**Files to modify:**
- `workers/api-gateway/src/durable-objects/quota.ts` — Adjust save strategy (if needed)
- `workers/docs/QUOTA_DURABLE_OBJECTS.md` — Document durability guarantees and trade-offs

**Status:** ✅ **DONE 2026-10-06** — All code-level items complete. Risk decision accepted and documented in `workers/docs/QUOTA_DURABLE_OBJECTS.md` "Durability Guarantee (T28 Decision)". Code: hybrid lazy persistence implemented with eager save every 10 s under load + a DO alarm armed on the first write after each save (fires ≤10 s later) as the sole flush path for sparse traffic; `blockConcurrencyWhile` guards cold-start races. Tests: 39 passing, including 4 dedicated `alarm — flush on eviction` cases. Monitoring (step 4) is not built: no Cloudflare DO metrics dashboard tracks eviction rate yet. It is no longer blocked — see the 2026-10-06 update above.

---

### CR64: revoking an `obtk_` key through api-gateway leaves its AUTH KV record live, so telemetry still accepts it

**Priority:** P2 | **Source:** cross-repo auth audit 2026-10-06; `workers/api-gateway/src/routes/api-keys.ts#handleRevokeApiKey`

- **The gap.** `POST /v1/orgs/:id/api-keys/:keyId/revoke` updates the `api_keys` row to `status = 'revoked'`, writes the audit row and answers 200 (`routes/api-keys.ts:176-183`). It never touches the obtool `AUTH` KV namespace, and cannot: only the `api-keys-*` edge functions hold that credential (toolkit `docs/auth-architecture.md`, "the only KV writer"). For an `obtk_` key, the format every service accepts, the KV record `apikey:<sha256>` keeps `status: "active"`, so obtool-ingest and obtool-api go on authenticating the key after the gateway, the dashboard and `/v1/orgs/:id/api-keys` all report it revoked.
- **Fix.** `handleRevokeApiKey` now delegates to the `api-keys-revoke` edge function (server-to-server, service key). The edge function's `handler.ts` was rewritten to use the same `isServiceCredential` pattern as `api-keys-rotate` (`verify_jwt = false` in config.toml; accepts `{ keyId }` in the body). The gateway handles auth/membership/key-lookup, calls the function, then writes the audit log. Tests updated and a new "edge function called with service key" assertion added.
- **Acceptance.** The gateway's test asserts the edge function is called with the service role key and the correct `keyId`; the audit log is written only after a successful function response.

---

### CR65: the post-login Action re-links any verified email from any connection, and two identities then flip one row between them

**Priority:** P2 (bounded today; becomes account takeover when a second connection is enabled) | **Source:** cross-repo auth audit 2026-10-06; `auth0/actions/provision-user-and-enrich-token.cjs:72-92`

- **The path.** When no row matches `event.user.user_id`, and `event.user.email_verified === true`, the Action finds the row by email and PATCHes its `auth0_id` to the new subject. [[CR51]] added the verified gate. Nothing checks `event.connection`, the IdP, or whether the row's existing subject belongs to the same person.
- **Today.** Only the database connection is in use, and it sets `email_verified` after an inbox click, so a re-link needs the same proof a password reset needs. That is why this is P2 and not P1.
- **The day it changes.** Enabling a social or enterprise connection makes `email_verified` the IdP's assertion. A Google account for `alice@acme.com`, or an enterprise IdP whose admin can mint any address, then inherits the existing row's memberships, roles and keys on first login. Auth0's own guidance is that `email_verified` from upstream providers is not uniformly trustworthy.
- **The second defect.** The PATCH overwrites rather than links. The original identity's next login finds no row by its subject, finds the row by email, and PATCHes `auth0_id` back. Two Auth0 identities oscillate over one `public.users` row, each login flipping it, and both carry the row's claims. Nothing in `users` records that a link happened.
- **Fix shape (decide first).**
  - Restrict re-link to an allowlist of connections whose verification is trusted (today: the database connection), read from `event.connection.name` or `strategy`; refuse the rest with `api.access.deny`, which also fixes the fail-open at line 107 for this case.
  - Or move linking to Auth0 account linking so one row keeps one subject, and drop the email PATCH.
  - Either way, make a successful re-link one-way: refuse to overwrite an `auth0_id` that is already set.
- **Tests.** `provision-user-and-enrich-token.test.ts`: a second connection with the same verified email is refused; a re-linked row is not re-linked back on the first identity's next login.
- **Acceptance.** A verified login from a non-allowlisted connection with an existing user's email gets no claims and no row; `users.auth0_id` never changes once set.

---

### CR69: Auth0 post-login Action fails open when Supabase cannot resolve a user

**Priority:** P2 | **Source:** cross-repo auth audit, 2026-10-06; `auth0/actions/provision-user-and-enrich-token.cjs:125`

When no `public.users` row can be resolved (Supabase down, insert rejected, unexpected body shape), the Action returned without claims — allowing the login with a token that carried no `app_user_id`, no roles, and no permissions. Downstream code treats an absent `app_user_id` as unauthenticated, so the user's own session answered every role-gate check with "not authorized." The silent failure mode meant Supabase degradation looked like an access-control problem to the user, with no observable signal at Auth0.

**Fix:** `api.access.deny('Unable to provision user account. Please try again.')` with a console.error when `appUserId` is falsy after the provision attempt. The login is hard-denied; the error is surfaced to the user through Auth0's login-failure page and to engineers through Auth0 logs. Tests updated: the two "no claims and does not throw" cases now assert `denials.length === 1` with a matching reason string.

**Decision 2026-10-06 (owner): keep the deny.** Reviewed after the fact because the audit filed this as a fragility, not an action item, and the deny changes two behaviours: a Supabase outage now denies every dashboard login instead of issuing claimless tokens, and the CR51 duplicate-email identity (insert rejected by `users_email_key`) is denied instead of logging in with nothing. Both accepted — a visible login failure beats a session that answers 403 everywhere.

---

### APIKEYLIST-UNVERIFIED-JWT: `api-keys-list` edge function reads JWT sub without verifying the signature

**Priority:** P2 | **Source:** cross-repo auth audit, 2026-10-06; `supabase/functions/api-keys-list/index.ts:21`

The function decoded the JWT payload with `atob` to read `sub` without verifying the signature. Its security relied entirely on `verify_jwt = true` in `supabase/config.toml` causing the Supabase platform to verify the token before the handler ran — a fragile, deployment-dependent guarantee. Deploying with `--no-verify-jwt` or removing the `[functions.api-keys-list]` config block would expose the function to forged `sub` values, letting any caller list any user's API keys.

**Fix:** The handler verifies the bearer itself with `jose.jwtVerify`, choosing the verifier by the token's `iss` and accepting the same two issuers the platform's `verify_jwt` admits: the project's own Supabase Auth (`${SUPABASE_URL}/auth/v1`, ES256 keys from its JWKS endpoint, audience `authenticated`) and, when the `AUTH0_DOMAIN` / `AUTH0_AUDIENCE` secrets are set, the Auth0 tenant through Third-Party Auth. The platform verification (`verify_jwt = true`) is kept as defence-in-depth; the function is now safe regardless of how it is deployed. Two wrong cuts preceded this on 2026-10-06, both caught before the e2e suite was green: one verified with `SUPABASE_JWT_SECRET`, which neither project has (both sign with asymmetric keys), and one verified against Auth0 only, which rejected the function's one real caller — the toolkit e2e suite (`services/e2e/api-key-auth.e2e.ts`) signs its test user in with `signInWithPassword` and sends that Supabase-issued token. The Auth0 secrets were set on both projects the same day (dev tenant on `tumhmtshahktumhqqamk`, production tenant on `cfrbahzzklwrnmbtqojl`); they are optional to the function.
