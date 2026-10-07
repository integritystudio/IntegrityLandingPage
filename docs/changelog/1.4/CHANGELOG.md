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

---

<a id="cr49"></a>

### CR49: retire the sender's ROPC endpoints and the "My App" `password` grant

**Outcome:** ✅ **DONE and live 2026-10-07** — routes gone from production `sender-worker` `04afc2eb` (CI from `91f9a1f8`; 404 sampled twice); "My App" `password` grant removed, so production ROPC is on 0 of 6 clients. The six unread `AUTH0_*` secrets were unbound from both sender Workers the same day (12 → 6 each)

**Priority:** P2 | **Source:** CR48 | **Status:** ✅ done and live 2026-10-07 (steps 0–3).

After CR48 nothing in the app calls sender `/signin`, `/signup` or `/forgot-password`, and CR25's rule "do not strip the survivor" (`My App` keeps `password` because `/signin` uses it) stops applying — but only once no traffic reaches them.

**Fix shape:**
0. **Move the toolkit e2e off the sender's routes first** (added 2026-10-01). `observability-toolkit` `services/e2e/sender-receiver.e2e.ts` calls `${PROVISION_WORKER_URL}/signup` and `/signin`, and `createAuth0TestUser` (`helpers/supabase-admin.ts`, used by `dashboard-auth.e2e.ts` and `dashboard-auth-logout.e2e.ts`) calls `/signup`. Its CI `e2e` job runs them against `sender-worker-dev`. The routes are one source for both Workers, so step 2 removes them from dev too and that job fails. Create test users another way, for example the dev tenant's Management API plus the receiver's `provision_api_key`, as a Universal Login signup does.
   - ✅ **Done 2026-10-01** — toolkit PR #112, merged as `9056f55d`; its CI `e2e` ran 43 tests, 0 skipped. `createSignupUser` makes an unverified Auth0 identity through the dev tenant's Management API, writes the `public.users` row, and mints the token over ROPC via `integrity-dev-ropc`. It writes the row itself because the dev tenant has **no post-login Action bound**. The first `provision_api_key` creates the org. Sender-receiver tests 4–6 (`/signin`, `/signup` error mapping) are deleted; 7, 8 and 10 now call `/send`, which returns the same codes.
   - **Check on the step 1 re-check:** `sender-worker-dev` should show no `/signup` or `/signin` after the merge (2026-10-01 20:34Z), except manual runs.
   - Found on the way: `api-provisioning-receiver-dev` had not been deployed since 2026-08-22 (pre-CR47) and was redeployed from toolkit `main` (`afec26de`). Toolkit CI redeploys `obtool-ingest-dev` but not the receiver, so it will drift again; that is filed in the toolkit as E2E-DEV-RECEIVER-MANUAL-DEPLOY. The dashboard e2e suites also leaked two Auth0 identities per run, which the same PR fixes. All leftovers in dev were deleted by 2026-10-04: 293 orphaned test identities, plus two whole leaked users with their personal orgs. A sweep that day found no `e2e-dash-*`, `e2e-sender-*` or `e2e-signup-*` identities in the dev tenant and no such `users` rows.
1. After CR48 is deployed, confirm from sender-worker logs that `/signin` and `/signup` see no requests for a week (old tabs and bookmarks drain).
   - ✅ **Passed 2026-10-06 23:59Z.** Workers Observability, `$metadata.trigger` grouped for `$metadata.service = sender-worker` from 2026-09-29 08:24Z: only `GET /` 14, `POST /send` 3, `OPTIONS /send` 2, `GET /health` 1. `sender-worker-dev` since step 0's merge (2026-10-01 20:35Z): `POST /signup`, `/signin`, `/forgot-password` all 0.
2. Delete the three routes, their handlers and tests; update sender `test:live`/`test:e2e` and CLAUDE.md's route list.
   - ✅ **Done 2026-10-07 (code; live on push to `main`).** Gone from `sender-worker`: the three handlers and branches, the Auth0 and Supabase helpers only they used, `checkAuthRateLimit`, the `RATE_LIMIT_KV` binding (top level and `[env.dev]`), the `test:live` suite (`auth0.live.test.ts` covered only these routes), and their tests. A regression test asserts all three paths answer 404 without an outbound call (mutation-checked). Suites: unit 206 → 102, e2e 49 → 24; `tsc` and `lint:workers` clean; `deploy-environments` 52 green. Route lists updated in CLAUDE.md, README.md, `docs/architecture.md`, `docs/api-reference.md`, `docs/authentication.md`, `docs/TWO_LAYER_AUTH_ARCHITECTURE.md` and `docs/provisioning-environment-setup.md`.
   - **Cleanup:** the secrets `AUTH0_DOMAIN`, `AUTH0_CLIENT_ID`, `AUTH0_CLIENT_SECRET`, `AUTH0_CLI_ID`, `AUTH0_CLI_SECRET`, `AUTH0_AUDIENCE` were unbound from both sender Workers 2026-10-07 (see step 3); the sender no longer binds `RATE_LIMIT_KV`, but **do not delete either namespace**: `api-gateway` still binds `766332ec…` (prod) and `46a717cd…` (dev) for its own limiters. No sender route is rate-limited any more.
   - **More route lists to update (added 2026-10-06).** A staleness pass that day added `/forgot-password` wherever the sender's routes are listed, because the route was live and undocumented: CLAUDE.md (project tree and Workers section), README.md, `docs/architecture.md`, `docs/api-reference.md`. Remove all three routes from those too. The Flutter `/forgot-password` → `/login` redirect in `docs/routes.md` stays: it only catches old links and calls no Worker.
3. Remove `password` from `My App`'s `grant_types` (look the full client id up first; listings truncate it). Then ROPC is 0 clients in production. The toolkit e2e is unaffected: it mints through the dev tenant's own `integrity-dev-ropc` client.
   - ✅ **Done 2026-10-07.** `PATCH /api/v2/clients/vnFenjO3wtCMAfjHgcjdzRz5jOkfrgHq` set `grant_types` to `authorization_code, refresh_token` (was `+ password`), confirmed by re-reading the client; no production client holds a password grant (0 of 6). The six `AUTH0_*` secrets were then unbound from `sender-worker` and `sender-worker-dev` (`wrangler secret delete`; 12 → 6 secrets each, re-listed after). Both Workers answered `/health` 200 and `/send` 400 on an empty body afterwards, sampled twice.

**Investigated 2026-10-01** (Workers Observability query API, Auth0 logs; read-only).
- **Production `sender-worker`, last 7 days (Cloudflare's retention):**
  - `POST /signin` 13, `POST /signup` 4, `/forgot-password` 0.
  - The last request to any of the three was `POST /signin` (200) at 2026-09-29 08:23:18Z, from a browser on integritystudio.ai. CR48 reached Pages 15 minutes earlier (08:08:07Z, CI run `36539934431`), so it was most likely a tab still running the old site. Who it was cannot be read back: the 2026-09-30 smoke-test cleanup ([[CR51]]) deleted that account's `auth0_logs` rows, and Auth0 keeps about a day of logs on this tenant.
  - Everything earlier in the window was testing: curl smoke runs; browser sign-ins on the old site; and local runs of the old Flutter live test against production (Dart user agent, 09-24 to 09-28), where `/signup` got 400 and `/signin` 429 because brute-force protection had locked `test@example.com`. CI's live test targets `sender-worker-dev` and, since CR48, calls none of these routes.
- **Auth0 agrees** for the window it still holds (2026-09-30 20:30Z onward): no `sepft` (password exchange) on any client.
- **`sender-worker-dev`, same 7 days:** `POST /signup` 538, `POST /signin` 68. That is the toolkit e2e job, hence step 0, which stopped those calls on 2026-10-01.
- **Re-check on or after 2026-10-06 08:23Z, and before about 10-13**, when 09-29 leaves Cloudflare's 7-day window. Count `$metadata.trigger` grouped by route for `$metadata.service = sender-worker` through `POST /accounts/<id>/workers/observability/telemetry/query`.

---

<a id="cr54"></a>

### CR54: corporate signups land in a personal org and are never moved into their team org after verifying (review)

**Outcome:** ✅ **live 2026-10-07** — `api-gateway` `ad299722` (GET and POST `/v1/me/team` answer 401 unauthenticated, not the router 404; preflight 204) and the dashboard card via the Pages deploy from `91f9a1f8`. An authenticated join has not been run in production

**Priority:** P3 | **Source:** CR48 session 2026-09-29; `lib/pages/callback_page.dart` routing, toolkit receiver `handlers/provision-api-key.ts` (CR47)

CR47 groups by domain only when `/userinfo` says `email_verified === true`, and says an unverified user "joins the team org on a later provision once verified". But a database signup is unverified when it first reaches `/provision` (the verification email has not been clicked), so every corporate signup gets a personal org. After that the callback sees an org and routes to `/dashboard`; `provision_api_key` is sent only from `lib/pages/provision_page.dart`, and the dashboard SPA does not send it, so the "later provision" never happens. (The old sender `/signup` also created users unverified, so this predates CR48; CR48 makes the routing explicit.)

**Fix shape (decide first):** either re-provision on sign-in when the email has become verified and the user has only a personal org (callback or receiver `sign_in`), or accept personal orgs and offer an explicit "join your team" action. Acceptance: a verified `user@acme.com` whose first provision was unverified ends up a member of `team-acme.com`.

**Decided 2026-10-06 (owner): the explicit "join your team" action.** **Code done 2026-10-07, not deployed.**
- **`api-gateway`** (`src/routes/team.ts`): `GET /v1/me/team` returns `{ domain, team: {id, name} | null, member }`, the domain taken from `users.email`. `POST /v1/me/team` checks the address with Auth0 `/userinfo` (the access token carries no `email_verified`), finds `organizations` with `type = 'team'` and that domain, and inserts an active `member` row with `ON CONFLICT DO NOTHING`, plus an `org.member_joined` audit row. 403 unverified, 404 no team org, 409 for a suspended or invited row (an owner put it there; this route does not undo it), 200 `joined: false` for an existing active member. It joins only an existing team org: creating one stays with the receiver, so no free-mailbox list is needed here (production on 2026-10-06 had team orgs only for `integritystudio.ai` and `inventoryai.io`). Identity-throttled like `/v1/me`; no org quota. 25 route tests and 3 router tests; three seeded mutants (verification check, inactive-row check, domain source) and a dropped router branch each fail a test.
- **Flutter**: the in-app `/dashboard` shows a "Join your team" card when GET reports a team the user is not in. Joining reloads the org list with the team selected; the personal org stays. Service tests in `test/services/dashboard_team_test.dart`, card tests in `dashboard_page_test.dart`.
- **To ship:** `npm run deploy:prd` from `workers/api-gateway`, then push `main` for the Pages build. Acceptance stays as above; prove it on dev with a verified `@<domain>` user that has only a personal org.

---

<a id="cr59"></a>

### CR59: the gateway's quota headers are non-standard, and nothing can read them

**Outcome:** ✅ **live 2026-10-06** — `deploy:prd` from `34f80f24`: `api-gateway` `43f5184e`, `contact-form` `85d28a02`; `Access-Control-Expose-Headers` read back on both. The 429 path itself is unit-tested, not probed live. Code `f14f0b8f`; named constants plus tests for the expose lists and the minute reset `2db6eed3` (behaviour-neutral, not redeployed)

**Priority:** P4 | **Source:** CR52 review item 6, investigated 2026-09-29 (read-only)

- **Nobody reads them.** The gateway sends `X-RateLimit-Remaining-Minute` / `-Monthly` (`lib/quota.ts`).
  - No code in this repo, the toolkit, or its dashboard SPA reads them.
  - No worker sets `Access-Control-Expose-Headers` (verified: 0 matches in `workers/`), so a browser cannot read them cross-origin. The same applies to `Retry-After`.
  - Unverified side finding: `lib/services/contact_service.dart:370` reads `retry-after` from a cross-origin workers.dev response, so it probably always sees null in the browser.
- **Docs drift.** `docs/api-usage-ingestion.md`'s **Rate Limiting** section documents `X-RateLimit-Limit/Remaining/Reset`, which are never sent. It also gives an hourly Growth limit that does not exist.
- **Quota 429 gaps.** A quota 429 has no `Retry-After`, and each 429 carries only one of the two headers.
- **Standard.** The IETF standard for these headers, draft-ietf-httpapi-ratelimit-headers, is at version 11 (2026-05-23) and is still an Internet-Draft, not an RFC.
  - Syntax: `RateLimit-Policy: "minute";q=60;w=60, "month";q=10000` and `RateLimit: "minute";r=48;t=40, "month";r=1000;t=<seconds to 00:00 UTC on the 1st>`.
  - `w` is left off the month, because months run 28 to 31 days.
  - There is no way to say "unlimited", so enterprise has no month item.
  - Of the major APIs, only Cloudflare's sends the draft fields. GitHub and OpenAI send `x-ratelimit-*`, and Anthropic sends its own headers.
- **Fix shape, if wanted.**
  - Send both the draft fields and the old headers, add the expose-headers list to `buildCors`, and give each 429 a `Retry-After` for its window.
  - Fix the doc section.
  - Remove the `X-` pair after a deprecation note.
  - Risk is low, because nothing reads the current headers.
