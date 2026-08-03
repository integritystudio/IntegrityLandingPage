# Backlog

Open and deferred items only. Completed items are migrated to `docs/changelog/1.0/CHANGELOG.md`, `docs/changelog/1.1/CHANGELOG.md`, `docs/changelog/1.2/CHANGELOG.md`, and `docs/changelog/1.3/CHANGELOG.md`.

**Last Updated:** 2026-08-03 (**filed [[CR31]] — the published API docs advertise three endpoints that do not exist, and `api-gateway` has no hostname.** Answering "should `api.integritystudio.ai/*` point at `api-gateway`?" required inventorying both API surfaces, so the measurement is now a document — [`docs/api-routing.md`](api-routing.md) — rather than a session finding. The answer is **no, not the wildcard**: the two route tables are disjoint apart from `/health`, so repointing would 404 all thirteen `obtool-api` routes including `/v1/traces`, the one advertised endpoint that works. A four-pattern path-split needs no code change on either worker, but it re-opens [[CR13]]'s trap — top-level `routes` only, explicit `routes = []` under `[env.dev]`. **Four** customer-visible defects needing no decision: the quickstart's first command 401s (`/v1/health`; health is at `/health`), `POST /v1/alerts` exists on **neither** worker, and both `sandbox-api.integritystudio.ai` and `status.integritystudio.ai` — the latter the docs landing page's Status quick-link — are NXDOMAIN. ⚠️ **Three traps produced wrong readings on the way there, all now recorded:** `curl` defaults to GET, so POST-only routes read as missing; a 401 proves the `/v1/*` middleware ran, not that the route exists; and **a bare-substring grep merges subdomains** — `api.integritystudio.ai` is contained in `sandbox-api.integritystudio.ai`, so the first version of the checker emitted one host for two and hid the fourth defect completely. Same class as the [[CR14]] blanket-403 and the [[CR29]] positive-control note, and the third time a green check here had normalised away the thing it was checking — probe only what is live, read source for a route table, and give every checker a positive control) | 2026-08-03 (**[[CR11]] credential isolation is DONE — `npm run check:env-isolation` PASSES, exit 0**, 15 credentials distinct and both Stripe rows test-in-dev / live-in-prd. Doppler `dev` reaches its own Supabase project, Auth0 tenant and Stripe sandbox; the `*-dev` Workers are armed and a live `POST /signup` on `sender-worker-dev` proved it end to end. That unblocks [[CR02]] item 5, the dev receiver, which had been blocked behind CR11 step 1. ⚠️ **Staleness sweep, same session — both steps added on 2026-08-02 were mis-stated, and one had been false from the moment it was written.** Step 9 ("dev has no Stripe sandbox") was already done: `dev` has held `sk_test_` keys on the sandbox account throughout, and Stripe was the one family that was *never* shared. Step 8 said `deploy` and `deploy:prd` "share one `CLOUDFLARE_WORKER_TOKEN` from Doppler `prd`" — wrong slot, wrong config, wrong conclusion: `wrangler` reads `CLOUDFLARE_API_TOKEN`, `deploy` sources it from `--config dev`, and the two values are distinct (sha `abb57cc474cb` vs `25889310adec`); the byte-identical `CLOUDFLARE_WORKER_TOKEN` is read by no code in this repo. **This is the third time a claim here has audited a name that was not the one in play** — after `SUPABASE_SERVICE_ROLE_KEY` and `SUPABASE_PROVISIONING_KEY`. The residual risk in step 8 is real but different, and no token can close it: dev's token is account-wide in scope, Cloudflare has no per-script scoping for Workers Scripts, so only separate accounts make production unreachable) | 2026-08-02 (**dev↔prd isolation re-audited against vendor terms — the blocker was phantom.** [[CR11]] had said it was blocked on "whether to pay for a third Supabase project"; the org holds **1** project of 2 free slots, so that project is free, and an Auth0 dev tenant is free too — **and does not even need creating**, since `dev-njjmghdzm23uy0p7` already exists and is live, so that blocker is one M2M credential. Neither blocker is financial; both are ~15 minutes of manual provisioning. ⚠️ **Self-correction, same session:** the first pass of this rewrite restated step 2 as "create a tenant, not scriptable at any price" while CR11's own 2026-07-29 update, ~60 lines below, already said otherwise — the *Sequenced target* line had carried that same contradiction since 2026-07-29. Both are fixed. A canonical block does not help if it is written without reading the item's later updates. The cost claim had been restated in five places and went stale in all of them at once when `atx_movement` was deleted on 2026-07-29, so it is now a **single canonical block** at the top of CR11 and every other copy is struck and points there. Two untracked free gaps added as CR11 steps 8–9 / [[CR02]] step 8: "`deploy` and `deploy:prd` share one `CLOUDFLARE_WORKER_TOKEN`", and "dev has no Stripe sandbox" — ⚠️ **both false, corrected 2026-08-03; see the entry above.** [[CR02]] item 5 was marked **blocked behind CR11 step 1** — it had read ready-to-do, and a dev receiver against the shared project would write real orgs and mint real keys in production; ✅ **unblocked 2026-08-03**) | 2026-08-02 (**CR29 steps 1 and 2 done, neither pushed** — the sender fails closed on an unset *or* unresolvable `ACTIVE_KEY_ID` rather than downgrading to `SHARED_SECRET`, and the receiver now rejects a request carrying no `x-key-id`, which is the change that closes the forgery path. `SHARED_SECRET` is read by neither side; it stays bound until step 3. **Step 3's gate metric changed as a consequence:** `auth.verified_legacy_key` no longer exists — step 2 deleted the path it counted — so the signal to watch is `auth.key_unresolved` with `miss: "missing_key_id"`, which is a *breakage* signal rather than a success one. Next: step 3, the unbinding) | 2026-08-01 (**CR29 step 0b done** — the receiver now attributes every signature check to a signing key, so `auth.verified_legacy_key` measures when the keyless fallback is safe to remove; committed unpushed because merging deploys the receiver) | 2026-07-31 (staleness sweep — CHK01 closed, CR13 leftover deleted, CR11 detector regression 3→5 recorded and row #7 diagnosed, which filed **CR29**: the HMAC rotation is a no-op; CR20 step 4 answered; CR12 type fix, CR14 step 6, CR15 item 2, CR25 items 9–12 closed; Stripe revocations confirmed) | **Phase:** Codebase review remediation + worker deploy/settings audit + **database/secret remediation**. 48 findings fixed and migrated to the 1.3 changelog; open items are summarised in the table under *Code Review 2026-07-26 → 2026-07-27* (CR01–CR31).

> **Session 2026-07-31 (staleness sweep) — three entries claimed more than was true, and one of them was a security claim.** Every correction below was measured, not reasoned from the page's own history. **[[CHK01]]** said "not committed, not deployed"; it is both — `a2f3ff6`, merged via PR #20, CI run 30612619138, and the org_id code is present in the *deployed bundle*. **[[CR13]]**'s remaining `[env.staging]` footgun is deleted, and a new `deploy-environments` test now fails on any named environment other than `[env.dev]` (mutation-verified; suite 50 → 55). **[[CR11]] is the one that matters:** the isolation detector reports **5 of 13**, not the 3 quoted in four places. `SHARED_SECRET` is byte-identical across configs again — row #7's rotation has been undone by something this page does not record. **Diagnosed the same day:** `prd` was not overwritten (`dev` was re-copied from it), so re-rotating `dev` is safe — but the real finding is that **`SIGNING_KEYS` rotation currently buys nothing**, because the production receiver still accepts `SHARED_SECRET` whenever `x-key-id` is omitted. Proven with positive and negative controls, and **filed as [[CR29]]** (P1, open) rather than left inside this row, because it is not an isolation defect: a credential with no key id has no rotation handle, so it survives every fix CR11 contemplates. Separately, `SUPABASE_SERVICE_ROLE_KEY` reads "UNSET in both" because **the slot exists in neither config**, so the detector is watching a name that is gone. That masks the real finding: the live service key moved to `SUPABASE_PROVISIONING_KEY`, which is shared between `dev` and `prd` and **returns HTTP 200 against the production database**. [[CR01]]'s "the `dev` config no longer holds any working RLS-bypassing Supabase credential" is therefore **false**. The generalisable error: it inferred a capability from the state of one slot, and a credential that moves slots defeats that silently.
>
> **Session 2026-07-31 — the `stripe-webhook` cron was verified, and the answer reframes [[W04]].** The `*/15` reconciliation cron does run and does succeed: 96/day at exact quarter-hour offsets, `errors: 0`, one Supabase subrequest each, and zero error-level logs in three days. But the telemetry also shows it reported `status: success` ~96×/day for the **four months it was doing nothing at all** — the pre-2026-07-28 rows have **zero subrequests**, because the Supabase client threw on unbound secrets and the failure was swallowed into an empty array. **An error-rate alert would never have fired.** The signal that catches this is subrequest count or queue depth, and [[W04]] step 2 now says so. Separately, the retry path itself remains unexercised: `webhook_dead_letters` has always been empty, so "the cron works" currently means "the query succeeds", not "recovery works".
>
> Also closed the same day: [[CR12]]'s type lie (`API_KEY_HMAC_SECRET` optional, four consumers guarded, API-key auth degrades to 503 while JWT auth is provably unaffected), [[CR14]] step 6 (preview-URL test coverage 2 → 4 Workers, mutation-verified), [[CR15]] item 2 (four stale secrets deleted, 16 → 12), and [[CR25]] items 9–12. On Stripe, one of [[CR01]]'s two Dashboard revocations is now machine-confirmed — the unused `…B6I8` key is dead while the in-use `…aHZC` key still works, checked as a pair so a wrong-key revocation could not hide. The pre-rotation key cannot be probed from here and rests on the operator's report. One new finding: Doppler `dev` holds an Auth0 credential with **`delete:users` on the production tenant** — see the entry under [[CR25]].

> **Session 2026-07-30 (later) — the dashboard works end to end for the first time.** A reported CORS error on `/v1/orgs` turned out to be the outermost of three stacked `api-gateway` defects: no CORS handling at all, verification against **Supabase** JWKS for a token issued by **Auth0**, and an Auth0 `sub` passed into `organization_memberships.user_id` (a uuid column). The third is the one to remember — it fails *silently*, returning an empty org list rather than an error, so fixing the first two alone would have shipped a blank dashboard that looked like success. All three are fixed and live (`524274de`); all seven dashboard endpoints return 200 with a real login token. The same session found that signup's `POST /bootstrap` **404s** because its handler lives in a Worker that was never deployed — see [[CR26]], which is open.

> **Session 2026-07-30 — the deploy backlog is cleared.** All four production Workers this repo owns were deployed from `fix/review-supabase-writes-and-signup-tiers` with `npm run deploy:prd`: `api-gateway` `9c4e7c61` (previously **2026-03-31** — four months stale), `sender-worker` `ddf2c87f`, `integrity-studio-contact` `55c13446` (also 2026-03-31), and `stripe-webhook` `1e3f2cce`. That single pass shipped the JWKS/ES256 verifier, [[CR03]]'s `RATE_LIMIT_KV` binding, observability on every Worker ([[CR15]] item 1 + [[W04]] step 1), [[CR21]]'s `ctx.waitUntil`, [[CR22]]'s billing-portal fix, CR05/CR06's 5xx-on-DB-error, the quota DO alarm flush, contact-form's fail-closed CSRF and CRLF-sanitised Subject, and the security fix that verifies the bearer token *before* quota enforcement. Preconditions checked first, not after: 1,063 worker tests green, zero TypeScript errors, and a `--dry-run` per Worker. Verified after each: all four healthy, `api-gateway` reporting `durableObjects: healthy` so its DO namespace survived, `preview_urls` still `false` on all four ([[CR14]]), `stripe-webhook`'s `*/15` cron and `sender-worker`'s `RECEIVER` service binding intact, and **the zone routes unchanged — `api.integritystudio.ai/*` still `obtool-api`**, so [[CR13]]'s trap did not fire.
>
> **Two Workers were deliberately left alone.** `bootstrap-worker` and `receiver-worker` have no production deployment, so `deploy:prd` would *create* a publicly-callable Worker rather than update one — a new production surface for, respectively, a Worker with no secrets bound and a test double that returns mock responses. Neither is a fix; both need a decision first. **Update 2026-07-30 (later):** `bootstrap-worker`'s absence is not cost-free, as this note implied. The shipped Flutter app calls `POST {api-gateway}/bootstrap`, a route `api-gateway` does not serve, so the screen shown immediately after signup has never been able to load — see [[CR26]].
>
> **Two claims in this file were wrong about liveness and are corrected in place.** [[CR21]] was marked ✅ on 2026-07-29 while production was still running 2026-07-28 code, and [[CR22]] read as needing a deploy that is now done but *still* cannot be exercised — its 403 needs a valid API key, which `API_KEY_HMAC_SECRET` being unbound makes unreachable ([[CR12]]). The recurring error is treating "merged" as "live"; see the audit note at the head of Phase 4, which now has three instances rather than one.
>
> **Session 2026-07-27 evening — what changed on production.** Four things were repaired, and each one uncovered the next. The Supabase **migration ledger was lying**: two migrations were recorded as applied whose objects had never existed ([[CR17]]), including the one creating `stripe-webhook`'s two tables — so that Worker was structurally broken *beneath* its missing secrets. The ledger was repaired and all migrations applied; the schema is now in sync. Three tables were then found **anon-readable** because RLS was omitted on the assumption that service-role-only access made it private; RLS is now on. Secrets were bound to the two Workers that had none, and **`api-gateway` returns `200 {"database":"healthy"}` for the first time since 2026-03-31** — [[CR12]] is now partially closed and the V02 dashboard has a working backend. A test-mode Stripe endpoint was registered against the dev Worker and signature verification proven end to end with a new live test suite.
>
> Three claims repeated across this file, `CLAUDE.md`, `CODE_REVIEW.md`, and the 1.3 changelog were **wrong** and are corrected in place: `STRIPE_API_KEY` is not `sk_test_` in both configs ([[CR18]]), the Supabase project is not paused, and `doppler run` cannot be trusted to report which value a config holds. Tests: 3,001 Flutter + 1,021 worker passing, zero TypeScript errors, `flutter analyze` clean. Prior entry: Provisioning Docs Reconciliation & Payment Processor Security Complete; Payment processor security hardening (V-06, V-18, V-22) + Enterprise Stripe checkout + T28 code portion migrated to v1.3 (5 items); W03 (provisioning docs reconciliation), W02 (receiver CI account-id) + W06 (contact-form env-aware CORS) migrated to v1.3 (2026-06-27); merged root `BACKLOG.md` (Auth0 grant-type blocker + "remove detail field" cleanup) into this file (2026-06-27); remaining deferred items: T28 (design decision), W04-W05 (infrastructure/monitoring). 2026-07-12 doc-staleness pass — W01 closed (won't-do; Zod v4 chosen over Valibot), #77 Chrome-hang re-tested on Flutter 3.44.4 (still blocked), V02 dashboard confirmed complete — **superseded twice: on 2026-07-27 morning V02 was found code-complete but non-functional (`api-gateway` had zero secrets since 2026-03-31, CR12); on 2026-07-27 evening the gateway was restored to `200 {"database":"healthy"}` and the backend now works. The habit that produced the error stands, though — several ✅ items meant "merged and unit-tested" rather than "working in production"; see the audit note at the head of Phase 4.**

---


## Phase 4 Remaining Items (Substantially Complete)

**Status:** Phase 1–4 substantially complete as of 2026-03-20.

> **⚠️ Audit 2026-07-27 — "complete" here means merged, not working in production.** A cross-cutting check against the deployed Cloudflare state found that a number of ✅ items below depend on Workers that have never functioned in production:
>
> | Item(s) | Depends on | Deployed reality |
> |---|---|---|
> | V02 dashboard pages, T26 quota integration, T27 quota tests, V-02 JWT issuer validation | `api-gateway` | **Zero secrets since 2026-03-31** ([[CR12]]); answers `503 {"database":"degraded"}`; no zone route ([[CR13]]) |
> | H1 Stripe Zod schemas | `stripe-webhook` | **Zero secrets and zero bindings**; cannot verify a signature or reach the database. Its `*/15` dead-letter cron is nonetheless live and has been failing silently ~96×/day since 2026-03-31 |
>
> The code in these items is real and tested — 1,021 worker tests pass. What was never verified is that the deployed Workers could execute it. Each ✅ above should be read as "code merged and unit-tested", and the product-level claim deferred until [[CR12]] is resolved. This gap is the reason [[CR12]] and [[CR14]] were found by auditing deployed state rather than by reading source, and it is worth remembering the next time a phase is declared complete.
>
> **✅ Update 2026-07-27 evening — the `api-gateway` row is resolved.** Secrets are bound and `GET /health` returns `200 {"database":"healthy","durableObjects":"healthy"}`. V02's dashboard, T26/T27 quota integration, and V-02 issuer validation now run against a gateway that can reach its database, so those ✅ marks finally mean what they appear to mean. Two caveats: `API_KEY_HMAC_SECRET` is still unbound, so API-key-authenticated routes remain broken while JWT routes work; and there is still no zone route ([[CR13]]), so the app reaches it only at `workers.dev`.
>
> **The `stripe-webhook` row is only half-resolved,** and the reason is worth recording: missing secrets were never the whole story. **Its two tables did not exist** ([[CR17]]) — the migration creating them was recorded as applied but had never run. Both are now fixed, so the dead-letter cron can finally function, but the Worker still cannot verify a signature ([[CR18]]) and no endpoint has ever pointed at it. The lesson generalises past "check the deploy": a phase can also be blocked by schema that the migration ledger *claims* is present.

**Completed in this session (2026-03-20 to 2026-03-21):**
- ✅ Sender-Worker UI Implementation — AuthPage, ProvisionPage, SenderHealthPage with JWT flow (commit 9ea6256)
- ✅ Quota Durable Object Integration (T26) — Wire quota checks into API gateway routes with fail-open logic (commits bb1d810, d58f382, 3483538)
- ✅ Quota Integration Tests (T27) — 25 comprehensive tests covering limits, idempotency, plan tiers (commit 6bc3cd8)
- ✅ Security Fixes — JWT issuer validation (V-02, commit 00bfaaf), timing-safe hash comparisons H19 (commit 0f9cece)
- ✅ Code Review — 10+ findings addressed; 6 backlog items marked Done (R02, R04, R07, R08, R09, R10)
- ✅ V02 Dashboard Core Pages — Usage summary page (55c4a86, e066900) + billing status display page (979ab7c, 60fd1ff) with DashboardService
- ✅ V02 Code Review Findings Documented — Backlog items H2, M30-M32, L10-L11, V02-Remaining 5 components (commit 80b288a)
- ✅ Roadmap Updated — V02 status reflects complete core pages + code review findings + remaining work (commits 81d3c24, 7f2e699)
- ✅ H1: Zod Schemas for Stripe Event Payloads — CheckoutSessionSchema, SubscriptionSchema, InvoiceSchema; all `as any` casts replaced with `safeParse` (commit 29a71d1)
- ✅ V02: Quota Visualization — QuotaStatusPage at `/quota` with minute burst + monthly limits, GET /quota/status endpoint (commits 9f93f67, e3ff7f3)
- ✅ V02: Usage Charts — Daily bar chart with quota reference line and threshold coloring, fixed shouldRepaint (commits c78bbf1, 809496a)
- ✅ V02: Entitlements Display — EntitlementsPage at `/entitlements` with auto-generated feature flags (commit 9f93f67)
- ✅ Code Review Cycle — H1 Zod schema findings documented + code review addressing H1/H2/M4 findings (commits fc91224, e3ff7f3)
- ✅ Backlog Updated — V02 quota visualization and entitlements display marked done (commit 52a2d4c)
- ✅ V02: Org Switcher Dashboard Hub — DashboardPage at `/dashboard`, DropdownButton org switcher, nav cards to billing/usage/quota/entitlements, fetchOrgList GET /v1/orgs with retry (commits 91cdae3, 226b568)
- ✅ V02: Real-time Usage Polling — 30s Timer.periodic + WidgetsBindingObserver resume refresh on UsageSummaryPage; in-flight guard prevents overlapping fetches (commits f6581fd, d14280c)

**v1 release items — ✅ COMPLETE (2026-07-12):**

### V02: Flutter Dashboard UI — ✅ code complete, ✅ **backend restored 2026-07-27 evening**

> **✅ Resolved 2026-07-27 evening.** `api-gateway` now has `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, and `SUPABASE_JWT_SECRET` bound and answers `200 {"database":"healthy"}`, so `GET /v1/orgs/:id/dashboard`, `/usage/summary`, `/entitlements`, and `/quota/status` can return data. The dashboard was showing error states on every panel from 2026-03-31 until this fix — roughly four months.
>
> **Two things still do not work.** Step 5's `POST /v1/orgs/:id/billing-portal` needs `STRIPE_SECRET_KEY`, which is empty in every Doppler config ([[CR18]]), so "Manage Billing" still fails. And `API_KEY_HMAC_SECRET` is unbound, so anything authenticating by API key rather than JWT stays broken. **Nobody has yet loaded the dashboard against the restored gateway** — the health check and a `401` on `/v1/me` are the only verification so far. Worth an actual end-to-end pass before calling this done.
>
> The original audit note follows, kept because its reasoning is still the right lens.

> **⚠️ Audit 2026-07-27 — "COMPLETE" is true of the code and false of the product.** Every endpoint this dashboard consumes is served by `api-gateway`, which has had **zero secrets bound since 2026-03-31** and answers `503 {"database":"degraded"}` ([[CR12]]). `GET /v1/orgs/:id/dashboard`, `/usage/summary`, and `/entitlements` therefore cannot return data, and step 5's `POST /v1/orgs/:id/billing-portal` additionally needs a `STRIPE_SECRET_KEY` that is not bound either. This is not a routing problem — the app calls `api-gateway.alyshia-b38.workers.dev` directly (`dashboard_service.dart:16`), and that hostname is reachable; the worker behind it cannot reach its database. **A user who opened the dashboard at any point in the last ~4 months saw error states on every panel.** Resolving [[CR12]] is what makes this item's ✅ real.

**Priority:** P1 | **Estimated:** 10–12 hours (code delivered — all 7 steps shipped; see Status below)

Implement authenticated dashboard with org switching, billing status, usage summaries, and entitlements display:

1. Create dashboard page with org switcher dropdown
2. Display current plan, billing status, next renewal date
3. Show monthly usage vs quota (bar/line chart for metrics)
4. Display feature entitlements grid (enabled/disabled flags)
5. Link to Stripe Customer Portal for billing self-service
6. Add real-time usage polling (refresh every 30s or on focus)
7. Error boundary and loading states for all async operations

**Architecture:**
- Use `provisioning_service.dart` for bootstrap/org context
- Integrate with `GET /v1/orgs/:id/dashboard`, `/v1/orgs/:id/usage/summary`, `/v1/orgs/:id/entitlements`
- Local state: active_org, entitlements, usage_snapshot (cached, TTL 30s)
- Global state: org_list, billing_status (cached, TTL 5min)

**Files to create:**
- `lib/pages/dashboard_page.dart`
- `lib/widgets/sections/dashboard_section.dart`
- `lib/services/dashboard_service.dart` (API client wrapper)

**Status:** ✅ ALL STEPS COMPLETE — Bootstrap flow complete; ✅ org switcher (step 1): `DashboardPage` at `/dashboard`, DropdownButton org switcher + nav cards to all sub-pages (commits 91cdae3, 226b568); ✅ billing status display (step 2): `BillingStatusPage` at `/billing`, plan name + status badge + renewal date, loading/error states, retry (commits 979ab7c, 60fd1ff); ✅ usage summary display (step 3): `UsageSummaryPage` at `/usage`, progress bar + per-metric breakdown (commits 55c4a86, e066900); ✅ usage charts (step 3): `_DailyBarChart` with `CustomPainter`, daily bar chart with quota reference line and threshold coloring (commits c78bbf1, 809496a); ✅ quota visualization (step 3 extended): `QuotaStatusPage` at `/quota`, minute burst + monthly limits with Unlimited label support, plan badge, fail-open DO handling (commits 9f93f67, e3ff7f3); ✅ entitlements display (step 4): `EntitlementsPage` at `/entitlements` with auto-generated feature flags (commit 9f93f67); ✅ Stripe Customer Portal link (step 5): `POST /v1/orgs/:id/billing-portal` with role check (owner/billing_admin), Stripe session creation, `fetchBillingPortalUrl` in DashboardService, "Manage Billing" button on BillingStatusPage (7 tests); ✅ real-time polling (step 6): 30s Timer.periodic + app-resume refresh on UsageSummaryPage, in-flight guard (commits f6581fd, d14280c). Code review findings: 1 H2-V02 latent JWT risk, 3 M-level (M30-M32: telemetry/validation/duplication), 2 L-level (L10-L11: decoration/docs) documented (80b288a).

---

## Deferred: OAuth Security (#8-#10) — ✅ COMPLETE

| Issue | Severity | Status |
|-------|----------|--------|
| #8 OAuth State Validation | CRITICAL | ✅ Done — `OAuthService.validateCallback()` with constant-time compare; CSRF rejection tracked in analytics (commit b957544) |
| #9 PKCE Implementation | CRITICAL | ✅ Done — `OAuthService.buildAuthorizationUrl()` with RFC 7636 S256 challenge; sessionStorage scoped; conditional web/stub exports (commit b957544) |

---

## Accepted Risk

### #23: KV Eventual Consistency Window

**Severity:** HIGH (accepted risk)
**Category:** Reliability
**File:** `workers/contact-form/src/index.ts:130-152`

KV is eventually consistent. Two requests from same IP at different datacenters can both read count=4, both increment to 5. Rate limit can be exceeded by ~2-3x.

> **Audit 2026-07-27 — the risk was accepted assuming a single writer, and there are two.** Production `integrity-studio-contact` binds `RATE_LIMIT_KV` to namespace `cf9d7d72bb07488faab8187ceb3589d4`, and so does `api-provisioning-receiver` (a different repo). Contact-form's keys are unprefixed — `rate_limit:${ip}` — so if the receiver uses the same convention, the two workers share a counter governed by contact-form's 5-per-60s budget, and the overshoot is no longer bounded by the eventual-consistency window alone. Unconfirmed rather than proven: the namespace currently reads empty (all keys are TTL'd) and `observability-toolkit` was not available to check the receiver's key format. Either way the acceptance rationale should be re-read with a second writer in mind. See [[W06]].

**Status:** Accepted risk for contact form use case — **acceptance predates the discovery of a second writer in the same namespace** (see audit note).

---

### #30: Multi-Environment CSP Endpoints

**Severity:** LOW (accepted)
**Category:** Infrastructure
**File:** `web/_headers`

Sentry `ingest.sentry.io` endpoint shared across staging and prod. CSP allows only one DSN per environment. Report DSN collision ignored when worker's `ENVIRONMENT` env var is not set (CF free plan limit).

> **Audit 2026-07-27:** the "CF free plan" premise checks out — `integritystudio.ai` is on the Free plan. The `ENVIRONMENT`-not-set condition no longer holds, though: production `integrity-studio-contact` binds `ENVIRONMENT = "production"` and the dev worker binds `"development"`, both as plain-text vars. The acceptance still stands on the free-plan constraint alone.

**Status:** Accepted for landing page use case. Documented in `web/_headers`. If env-specific reporting is needed, use a build script to replace the DSN.

---

### M18-V01: Mutable JWT Claims (Phase 1 Remediation)

**Severity:** CRITICAL — ✅ FULLY REMEDIATED
**Category:** Security — Access Control Staleness
**File:** `workers/lib/types.zod.ts:39-45` | Commit: `312070b`

JWT tokens from Supabase included mutable billing state claims (`default_org_plan` and `default_org_billing_status`) that reflect values at token issuance time (up to 3600s stale). When these values change via Stripe webhooks, JWT claims remain immutable, violating SOC 2 CC6.1 (system monitoring) and creating stale-read access control vulnerabilities.

**Remediation completed:**
- ✅ Removed both claims from `JWTPayloadSchema` (commit `312070b`)
- ✅ Code already queries fresh values from database (`orgs.ts`)
- ✅ Added `.passthrough()` for backward compatibility with old tokens
- ✅ Supabase Custom Access Token Hook updated via migration `20260326000000_update_custom_access_token_hook.sql` — hook now emits only `org_ids`, `default_org_id`, `default_org_role`
- ✅ Hook enabled in `supabase/config.toml`
- ✅ `TWO_LAYER_AUTH_ARCHITECTURE.md` updated to reflect compliant JWT claims

**Status:** ✅ Complete.

---

## Deferred: Chrome Platform Tests (#77)

### #77: `flutter test --platform chrome` Hangs Indefinitely

**Severity:** CRITICAL
**Category:** Test Infrastructure (Platform-Level)
**File:** N/A — Flutter SDK issue
**Source:** Session 2026-02-12, validated 2026-02-25

`flutter test --platform chrome` (CanvasKit + headless Chrome) hangs on **exit** after all tests pass. Affects CI pipelines: test suite completes, Chrome stays alive, process never exits until CI timeout.

**Upstream:** [Flutter #162798](https://github.com/flutter/flutter/issues/162798) — OPEN, marked for next stable release.

**Workaround:** N/A effective. Blocking factor.

**Status:** Blocked — re-tested on Flutter **3.44.4** (2026-07-12): `flutter test --platform chrome` still does not complete. It stalled at test loading/compilation for >6 min (observed twice) with headless Chrome + dart processes alive, never self-exiting — had to be killed. The anticipated v3.44 fix (upstream Flutter [#162798](https://github.com/flutter/flutter/issues/162798)) does **not** resolve it in this environment; Chrome platform tests remain non-viable. Mitigation unchanged: the Flutter suite runs on the default (VM) platform in CI.

---

## Deferred: E2E Test Coverage Limitations (Flutter Canvas)

---

### #116: Page-Specific Meta Tags Per Route

**Severity:** LOW
**Category:** E2E Test Coverage (SEO)
**Files:** `e2e/tests/seo-meta.spec.ts`
**Source:** Coverage gap analysis 2026-03-11

Meta tags tested for home page only. Gaps:
- Dynamic `og:title`, `og:description` per route (e.g., `/pricing` should have "Pricing" in og:title)
- Route-specific canonical URLs
- Hreflang tags for i18n (if deployed)
- Page-specific JSON-LD (e.g., `Product` schema for /pricing)

**Status:** Deferred — Flutter SPA serves the same index.html for all routes; per-route meta requires Cloudflare Workers or edge-side rendering to inject dynamic tags. P3 SEO enhancement.

---


## Feature: Resume Upload on Careers Contact Form (#132)

### #132: Add File Upload to /contact?ref=careers

**Priority**: P2 | **Source**: session 2026-03-11

Add a file upload button (resume PDF/DOCX) to the contact form when `ref=careers`. Recommended architecture:

```
Browser (file_picker) → multipart POST → CF Worker → R2 bucket → Resend (path: r2_url)
```

This keeps CPU usage minimal and avoids the Cloudflare Workers free plan 10ms CPU limit. For a typical resume PDF (100KB–2MB), direct base64 encoding in the Worker might also work but is less reliable on the free tier.

**Key constraints:**
- `file_picker` package recommended for Flutter web file selection
- Resend supports attachments via `attachments[].path` (public URL) or `attachments[].content` (base64)
- Resend limit: 40MB per email (~30MB raw after base64 overhead)
- CF Workers free plan: 10ms CPU limit — base64 encoding large files can exceed this
- R2 approach avoids CPU-bound encoding; Resend fetches from the R2 URL server-side
- Blocked file types (Resend): `.exe`, `.bat`, `.js`, `.ps1`, etc. PDFs/DOCX are fine

**Implementation steps:**
1. Add `file_picker` dependency, show upload widget on `/contact?ref=careers`
2. Create R2 bucket for resume uploads
3. Update CF Worker to accept multipart POST, write file to R2, pass R2 URL to Resend
4. Add file type/size validation (client + server)

> **Audit 2026-07-27 — two Cloudflare-side notes for whoever picks this up.**
>
> **This repo has no R2 at all.** No worker in it declares an `r2_bucket` binding. The account's two buckets (`obtool-telemetry`, `tcad-scraper`) belong to sibling projects, so step 2 is genuine greenfield provisioning, not wiring up something that exists.
>
> **The `attachments[].path` design implies publicly-fetchable resume URLs.** Resend fetches that URL server-side from its own infrastructure, which means the object must be reachable without the Worker's credentials — a public bucket or a presigned URL. A public bucket holding candidate resumes is a PII exposure with no access control and guessable-key risk; **presigned URLs with a short TTL are the safe form of this design**, and the choice should be made deliberately rather than discovered during implementation. The alternative in the item (`attachments[].content`, base64) keeps the file private but is what the 10ms CPU limit argues against.

**Status:** Deferred — requires R2 bucket provisioning (none exists in this repo) and Worker update. Settle the public-vs-presigned question before implementing.

---

### #133: Revert Careers CTA to "Submit Your Resume" After File Upload

**Priority**: P3 | **Source**: session 2026-03-11

Once #132 (resume upload) is implemented, revert the careers page CTA and copy:
- Button text: "Keep in Touch" → "Submit Your Resume"
- Description: restore "Send us your resume and a brief introduction..." (add "resume" back)

**Status:** Blocked on #132.

---

## Deferred: Server-Side Security Headers

These issues require **server-side HTTP response header configuration** and cannot be fixed in the Flutter app.

---


## Open Items

### ~~CHK01: Checkout sessions carried no `org_id`, so no subscription ever linked to an organization~~

**Priority:** P1 (revenue-adjacent: paid subscriptions were not attributable to an org) | **Source:** session 2026-07-31, while generating a live checkout link for `team-inventoryai-io`
**Status:** ✅ **done and live** (corrected 2026-07-31 — the line below said "not committed, not deployed" and was stale by one merge). Committed as `a2f3ff6` *fix(sender-worker): set metadata[org_id] on Stripe checkout sessions*, merged to `main` via PR #20 (`35e9c09`), and shipped by CI run **30612619138** ("Deploy Sender Worker: success"). **Verified in the deployed artefact, not inferred from a green deploy** — the live `sender-worker` bundle contains `metadata[org_id]`, `subscription_data[metadata][org_id]`, and three `default_organization_id` references, none of which exist in the pre-fix build. **Closed 2026-08-02** — step 3 (the optional backfill) was investigated and found to have an empty target; see step 3 below.

`workers/sender-worker/src/stripe.ts` built its Checkout params with **neither `metadata[org_id]` nor `client_reference_id`** — grep the pre-fix file for either and it returns nothing. But `workers/stripe-webhook/src/handlers/checkout.ts:24` reads exactly those two on `checkout.session.completed`:

```ts
const orgId = session.metadata?.org_id || session.client_reference_id;
if (!orgId) {
  console.warn('Checkout session missing org_id in metadata or client_reference_id');
  return { ok: true };            // warn-and-bail: linkStripeCustomer never runs
}
```

So every checkout the production sender created hit the warn-and-bail path: `organizations.stripe_customer_id` was never written and no subscription row was attached to an org. Consistent with live data at the time — **1 subscription row and exactly 1 org with a `stripe_customer_id`, system-wide.**

This is a one-shot bootstrap value. It is needed **only** in `checkout.session.completed`, to run `linkStripeCustomer(orgId, session.customer)`. Every other handler resolves the org from the customer id instead (`subscription.ts` ×2 and `invoice.ts` ×2 all call `findOrgByStripeCustomerId`), so once `stripe_customer_id` is written the session metadata stops mattering.

**Fix (implemented):**
- `src/supabase.ts` — new `supabaseFindOrgIdByEmail()`. Resolution mirrors `custom_access_token_hook`: prefer the user's `default_organization_id`, else oldest active membership. Returns `null` for an unknown email rather than throwing.
- `src/stripe.ts` — `createStripeCheckoutSession` takes an optional trailing `orgId` and sets both `metadata[org_id]` and `subscription_data[metadata][org_id]`. Optional and trailing so no caller signature breaks.
- `src/index.ts` — `handleCreateCheckoutSession` resolves the org before calling Stripe.

**Two decisions worth not re-litigating:**

1. **The org is derived server-side from the email — `orgId` was deliberately NOT added to `CreateCheckoutSessionSchema`.** `/create-checkout-session` is origin-gated but **unauthenticated**, so a client-supplied org id would let any caller who can reach the endpoint attach a subscription to an org they do not own. Deriving it server-side also needs no change from the landing page or the Flutter client. Note the origin gate is not a real boundary here: `isOriginAllowed` is browser-surface only, and origin-less callers (Flutter native, curl) bypass it by design — which is precisely why the org id must not be caller-supplied.
2. **Resolution is best-effort and never blocks a sale.** A lookup failure or an unknown email logs and proceeds with an unattributed session rather than erroring. Failing checkout to protect a metadata field trades a linking bug for a revenue bug. The cost is that the unresolvable case silently reverts to the old behaviour, so both branches log loudly (`console.warn` for no-org, `console.error` for lookup failure). Two tests pin it: unknown email → 200 without metadata, lookup 500 → 200 without metadata.

**Tests:** that describe block went 7 → 11. Four new: metadata from default org, membership fallback, unknown email, lookup failure. **Three existing tests had to be reworked, and the reason generalises:** they used `mockResolvedValueOnce`/`mockRejectedValueOnce`, which bind to call *order*, so the newly-added Supabase lookup consumed the mock and the Stripe branch under test never ran. Two of those were in a sibling `describe` and only surfaced on a full-suite run, not a `-t`-filtered one. All now route by URL (`url.includes('/rest/v1/')`), which is order-independent — **prefer URL routing over sequential mocks in this file.** Suite: 188/188, `tsc --noEmit` clean.

**Remaining:**
1. ~~Commit~~ — ✅ `a2f3ff6`.
2. ~~Deploy~~ — ✅ live. CI deployed it on the PR #20 merge (run 30612619138); the `HEAD`-ahead-of-`origin/main` caveat that made this step risky no longer applies to *this* fix, because the merge is what shipped it. The caveat itself still stands for future work.
3. ~~Optional: backfill. Any already-paid subscription created before this ships has no `org_id` on its session and is unlinked; re-deriving it means matching the Stripe customer email back to a user. Unknown volume — the single existing `stripe_customer_id` row suggests it is small.~~ — ✅ **Not needed; the target set is empty** (verified 2026-08-02 against live `acct_1SN2e7AwEfePbhfk` and Supabase). **The premise never materialised: there is no paid-but-unlinked subscription, and there never was one.**

   Live Stripe holds **2 customers, 2 subscriptions, 6 checkout sessions**, and every paid artefact is already linked in *both* `organizations.stripe_customer_id` and the `subscriptions` table:

   | Customer | Email | Subscription | Org |
   |---|---|---|---|
   | `cus_Uz8KgGh0peiaif` | alyshia@inventoryai.io | `sub_1TzA40…` active | `1649a1c1` team-inventoryai-io |
   | `cus_UxxzTfUmEWrvd0` | alyshialedlie@gmail.com | `sub_1Tz7Gh…` trialing | `20e71316` alyshia-ledlie |

   Of the 6 checkout sessions, five are `expired`/`unpaid` and one is `complete`/`paid` — and that paid one already carries `metadata[org_id]`. The **only** session lacking an org id (`cs_live_a1WcjL32…`) is expired and unpaid, so it produced no customer and no subscription. The five orgs with no `stripe_customer_id` are all `billing_status: inactive` except the internal `Integrity Studio AI` parent-organization, which has no Stripe customer at all.

   Two findings worth keeping, because they explain *why* the backfill was empty rather than merely recording that it was:
   - **The one paid session postdates the fix**, so it was never exposed to the warn-and-bail path. The pre-fix window produced expired sessions only.
   - **`sub_1Tz7Gh…` has no `metadata.org_id` and that is correct, not a gap.** It has no checkout session at all — it was created directly — so it was linked by customer id. That is the path this entry already identifies as the reason session metadata stops mattering once `stripe_customer_id` is written (`subscription.ts` ×2 and `invoice.ts` ×2 all use `findOrgByStripeCustomerId`). Do not "fix" the missing metadata; nothing reads it.

   **Not checked:** the sandbox account from [[CR18]]. Test-mode data is not backfillable revenue, so it is out of scope unless that account turns out to hold live charges. Also note this closes CHK01 while [[CR18]]'s premise has moved on independently — a live restricted key (`rk_live_…`) now exists in Doppler `prd` as `STRIPE_SECRET_KEY`/`STRIPE_API_KEY`, which is what made this verification possible.

**Not affected:** the live checkout link generated for `team-inventoryai-io` in the same session already carries `metadata[org_id]`, `client_reference_id` and `subscription_data[metadata][org_id]` — they were set directly on that session, independently of this fix.

**Files:**
- `workers/sender-worker/src/stripe.ts`, `src/supabase.ts`, `src/index.ts`, `src/index.test.ts`

---

### T28: Handle Persistent Storage Data Loss Risk in Quota DO

**Priority:** P3 | **Source:** session 2026-03-20, quota commit review (523518f)
**Estimated:** 2–3 hours

Quota state is lazily persisted to Durable Object storage every 10 seconds (`workers/api-gateway/src/durable-objects/quota.ts:174–177`). If the DO crashes or is evicted between saves, up to 10 seconds of quota usage is lost (counts are dropped, monthly counter reverts).

> **Audit 2026-07-27 — the risk cannot be assessed from production data, because there is none.** Step 1 asks whether 10-second loss is acceptable and notes it "needs confirmation". That confirmation is currently unobtainable: `api-gateway` has had zero secrets since 2026-03-31 ([[CR12]]) and no zone route ([[CR13]]), so the quota system **has never run against real traffic**. Eviction rate, save frequency, and realistic loss windows are all unmeasured. Step 4's DO metrics dashboard is likewise unbuildable today — the worker has `observability` unset entirely, so it emits nothing.
>
> Two things that raise the stakes once it does run: quota gates the **customer-facing** ingestion path ([[CR16]]), so dropped counts are a billing-accuracy question and not just an internal one; and the DO namespaces are confirmed distinct between environments (`14813730…` production, `30f146ce…` dev), so dev traffic cannot pollute production counters — that part is sound.
>
> **Sequence:** [[CR12]] → [[CR15]]-style observability on the gateway → measure → then decide the durability trade-off. Deciding it now would be picking a number from nothing.
>
> **Update 2026-07-27 evening — the first gate has opened.** [[CR12]] is largely resolved: the gateway has database access and answers healthy, so the quota system *can* now run. Two blockers remain before the measurement in step 1 is possible. Observability is configured but **not deployed** ([[W04]] step 1), so the Worker still emits nothing; and there is still no zone route ([[CR13]]), so real customer traffic cannot reach it. The sequence is unchanged, it has simply advanced one step.
>
> **Update 2026-07-30 — the observability blocker is gone; the traffic one is not.** `api-gateway` was deployed and now reports `enabled=True logs=True traces=True`, so the Worker emits for the first time and the quota DO's behaviour is finally readable. The same deploy also shipped `76706a1`, which flushes DO state via an alarm — **that partially pre-empts this item**, so re-read step 2 before designing anything: the 10-second loss window may already be narrower than this entry assumes. What still blocks a real measurement is that there is no zone route ([[CR13]]), so production quota traffic is whatever reaches the `workers.dev` hostname rather than a customer-facing endpoint.

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

**Status:** Deferred — Documented but requires risk/latency trade-off decision and monitoring setup.

---

## Performance: Migrate Cloudflare Workers Validation from Zod to Valibot — ❌ WON'T DO

> **Closed 2026-07-12 — won't do.** The team standardized on **Zod v4**, not Valibot (no `valibot` dependency in any worker). The `functions/src/` paths in this item are also obsolete — worker validation lives in `workers/`. Rationale retained in [`docs/research/VALIBOT_ANALYSIS.md`](research/VALIBOT_ANALYSIS.md); see changelog 1.3 "Superseded Design-Doc Reconciliation".

### W01: Replace Zod with Valibot for Edge Function Validation

**Priority:** P2 | **Source:** session 2026-03-25, performance analysis
**Estimated:** 4–6 hours
**Context:** `functions/src/` Cloudflare Workers use Zod for validation. Valibot is significantly faster and smaller for edge functions.

**Analysis:** See `docs/research/VALIBOT_ANALYSIS.md` for full comparison. Key findings:
- **Bundle size:** Valibot 1.91 KB vs Zod 16.57 KB (90% reduction)
- **Startup:** Valibot 54 μs vs Zod ~864 μs (16x faster cold starts)
- **Impact:** Every KB shipped globally to edge datacenters; smaller bundle = faster parsing = lower CPU milliseconds billed
- **Trade-off:** Valibot slower on invalid data (exception-based), but Zod remains better for server-side Node.js (keep in api-gateway)

**Scope:**
1. Audit validation schemas in `functions/src/` — identify all Zod usage
2. Migrate schemas to Valibot API (mostly 1:1 mapping)
3. Update type exports: `z.infer<typeof S>` → `v.infer<typeof S>`
4. Benchmark with Wrangler: measure bundle size reduction and cold start improvement
5. Update `functions/package.json` to add Valibot + remove Zod dependency (if not shared with api-gateway)
6. Run `npm test` in functions/ directory to verify no regressions
7. Document in `functions/MIGRATION.md` if Valibot is adopted long-term

**Files to modify:**
- `functions/src/` (all validation schemas)
- `functions/package.json` (add valibot dependency)
- `functions/tsconfig.json` (if needed for types)

**Decision point:** Should api-gateway continue using Zod (server-side, better ecosystem) while functions/ uses Valibot (edge, better perf)?
- **Recommendation:** Yes — different contexts. Keep Zod in api-gateway (Node.js), migrate functions/ to Valibot (edge).

**Files to check:**
- `functions/src/_middleware.ts` — entry point; check if validates requests
- `functions/src/` — all TypeScript files for `z.` references

**Status:** ❌ Won't do (2026-07-12) — superseded by the Zod v4 standardization; workers use Zod, not Valibot. Rationale retained in `docs/research/VALIBOT_ANALYSIS.md`.

---

## W04: Provisioning workers — monitoring, alerting & dashboards

**Priority:** P2 | **Source:** session 2026-06-27, reconciled from provisioning setup notes (now consolidated into `docs/provisioning-environment-setup.md`) — open items "Monitoring and alerting — must implement", "Monitoring Dashboards — Cloudflare Analytics"
**Estimated:** 4–6 hours

**Context:** there is **no alerting and no dashboard** for the provisioning path (`sender-worker` → `api-provisioning-receiver`). The setup summary flagged this as "must implement" but it was never tracked as a real item. `api-provisioning-receiver` lives in the `observability-toolkit` repo, so end-to-end provisioning observability spans both repos.

> **⚠️ Audit 2026-07-27 — this item's premise was wrong.** It previously opened "`sender-worker` has `[observability.logs]` with `invocation_logs = true` … **so logs are captured**". They were not. The deployed worker reported `observability: {"enabled": false, logs: {"enabled": true, …}}` — the parent `enabled` flag was never set, which silently disables the whole block regardless of the child tables ([[CR15]]). Worse, the **other five Workers had no `[observability]` block at all**, so the repo had essentially no telemetry anywhere. Step 2 was not "logs exist, add a dashboard"; it was starting from nothing.

**✅ Step 0 done (2026-07-27) — instrumentation now exists in config.** All six Workers declare `[observability]` with the required parent `enabled = true`, plus `logs.enabled`, `invocation_logs`, and `traces.enabled`, at **both** the top level and under `[env.dev]` (a named environment *replaces* the parent block rather than merging into it, so it must be repeated). Guarded by 18 new assertions in `workers/lib/deploy-environments.test.ts`, mutation-verified: removing the parent flag, disabling logs, dropping `invocation_logs`, or deleting the `[env.dev]` block each fails the suite. All 12 configurations validate under `wrangler deploy --dry-run`. **✅ Now live on all four deployed Workers as of 2026-07-30** — `api-gateway`, `sender-worker`, `integrity-studio-contact`, and `stripe-webhook` each report `enabled=True logs=True traces=True`, verified per Worker via `GET .../scripts/{name}/settings` after deploying. `api-gateway` and `integrity-studio-contact` had **never** emitted a log or a trace before this. The two undeployed Workers (`bootstrap-worker`, `receiver-worker`) are unaffected because neither exists in production.

What this unblocks, and what it does not: the signals in step 1 will exist once deployed, so steps 2–4 become real work rather than speculation. It does **not** by itself produce a dashboard or an alert.

**Correct target for this work:** route through `ingest.integritystudio.ai` / `observability-toolkit`, as step 2 already suggests. That is Integrity Studio's **internal** OTEL pipeline and is the right destination for worker self-monitoring. Do **not** redirect it to `api-gateway`'s `/v1/ingest/otel`, which is the **customer-facing** ingestion path — see [[CR16]] for why the two are separate.

**Scope:**
1. ✅ **Done** — enable observability on every Worker so there is something to observe (see Step 0 above). Deploy to make it live.
2. ✅ **Done 2026-07-31 — signals defined in [`docs/observability-signals.md`](observability-signals.md) and made executable as `npm run check:worker-signals`** (`scripts/check-worker-signals.sh`, following the `check:env-isolation` / `check:migration-drift` pattern: exit 0 within threshold, 1 on breach, 2 on prerequisite failure, `SKIPPED` + exit 0 without credentials).

   Defining these in prose alone is how they go stale, so each is computed rather than described. Five are implemented — unhandled exceptions, the cron no-op detector, resource exhaustion, cross-repo receiver health (reported, never failing the build, since this repo cannot fix it), and dead-letter queue depth. Five are named as **not** implemented so they are not mistaken for covered: the `/send` error-code split, receiver 401 spikes, provisioning latency, Auth0/Supabase call failures, and the auth 429 rate. The first needs a counter emitted from the Worker — `ERROR_CODE.RECEIVER_ERROR` vs `INTERNAL_ERROR` vs the 502 path is distinguishable only in the response body, which neither Cloudflare telemetry source records.

   > **⚠️ Do not build this on error rate alone — measured 2026-07-31, [[CR20]] step 4.** Throughout those four months the cron reported `status: success` with `errors: 0` on every one of ~96 daily invocations, because the Supabase client threw on unbound secrets and `fetchPendingDeadLetters` swallowed it into `[]`. The only telemetry that distinguished broken from working was **`subrequests`**, which sat at exactly 0 until secrets were bound and then rose to 1.00 per invocation. Any alert designed around errors or invocation count would have stayed green for the entire outage. The signature to watch for, here and on any future cron, is **"succeeded while making no outbound calls"**.

   **One caveat that will otherwise produce a wrong dashboard in step 3.** The two Cloudflare sources disagree. For `integrity-studio-contact`, GraphQL reported 34 invocations and 3 `scriptThrewException`, while a Workers Logs query over **72 hours** returned 10 events and no exception at all. Workers Logs only captures from the moment `observability` was enabled — the 2026-07-30 deploy for `api-gateway` and `integrity-studio-contact` — and its retention is shorter than the analytics rollup's. **Build rate panels on GraphQL; use Logs for drill-down only, and never read an empty log query as "no errors".**

   **The check found two live failures on its first run**, which is the argument for it existing. Both are recorded below.
3. Stand up a dashboard (Cloudflare Workers Analytics, or route through the existing internal OTEL pipeline) covering sender + receiver.

   > **🔴 Blocker found 2026-07-31: the internal OTEL pipeline this step proposes routing through is itself broken.** `obtool-ingest` is failing **~90% of its invocations** with `exceededResources`, and its `*/5` cron fails essentially every run. Successful ingest collapsed from tens of thousands per day to ~30 around 2026-07-28 while resource kills became the dominant outcome:
   >
   > | Date | success | exceededResources |
   > |---|---|---|
   > | 2026-07-26 | 26,613 | 185 |
   > | 2026-07-27 | 4,045 | 154 |
   > | 2026-07-28 | 70 | 241 |
   > | 2026-07-29 | 31 | 257 |
   > | 2026-07-30 | 29 | 273 |
   >
   > It is deployed from `observability-toolkit`, so this repo cannot fix it — but `ingest.integritystudio.ai` cannot be this step's destination until it is. Note the irony worth recording: the pipeline intended to monitor everything else has been failing silently for days, with nothing watching it. Do **not** substitute `api-gateway`'s `/v1/ingest/otel`, which is the customer-facing path — see [[CR16]].
4. Add alerting on error-rate and 401-spike thresholds (channel/owner TBD).
5. Document the dashboard + alert runbook; cross-link from `docs/api-provisioning.md`.

**Cost note before deploying:** `head_sampling_rate` defaults to `1` (100%) and `invocation_logs` records every request. That is the right setting for current traffic — these Workers are near-idle — but `api-gateway`'s ingest path is designed for customer volume ([[CR16]]), so revisit sampling there before it carries real load.

**Notes / overlap:**
- [[T28]] already calls for a Cloudflare Durable Object metrics dashboard for quota eviction — narrower, but fold into the same dashboard effort if convenient.
- Receiver-side instrumentation belongs in `observability-toolkit`; coordinate across repos.

**Files to touch:**
- `workers/sender-worker/wrangler.toml` (if exporting metrics/OTEL beyond logs)
- `docs/api-provisioning.md` (link runbook)
- `observability-toolkit` (receiver-side spans/metrics)

> **🟠 New finding 2026-07-31 — `integrity-studio-contact` threw 3 unhandled exceptions; the failure mode is fixed, the root cause is not known.** Surfaced by the first run of `npm run check:worker-signals`: 3 `scriptThrewException` on 2026-07-30 out of 34 invocations (~9%), on the site's only lead-capture path.
>
> **Root cause unidentified, and recorded as such.** The exceptions predate observability on that Worker, so no log line survives, and reading every unguarded path against the *deployed* config produced no candidate that throws — `checkRateLimit` catches its own KV faults, `validateCsrfToken` validates before reaching crypto, `getAllowedOrigins` falls back to defaults on bad JSON, and `ALLOWED_ORIGINS_JSON` is not bound in production at all.
>
> **What was fixed is why they were undiagnosable.** `fetch` had no outer try/catch. The body parse onward was covered; the prologue (CORS resolution, CSRF, rate limiting) was not, and neither was the `Response` construction inside the body handler's own `catch` — so a throw there escaped as a Cloudflare `1101`, with no CORS headers (a browser sees a CORS failure, not a server error) and no log. Every path now returns a CORS-bearing 500 and logs `worker_uncaught_exception` with error, stack, method and origin. Five tests, four mutation-verified against the unguarded handler. Also fixed: `buildCorsHeaders` emitted `undefined` as the `access-control-allow-origin` value when `ALLOWED_ORIGINS_JSON` is `"[]"` (valid JSON, an array, so it passes every existing guard) — the header is now omitted. Not the production cause; same failure class.
>
> ✅ **Deployed and verified 2026-07-31** — version `d40e7988` (was `55c13446` from 2026-07-30). Liveness confirmed by fetching the deployed bundle and finding `worker_uncaught_exception` and `Uncaught exception escaped` present, not by inferring it from a successful deploy — the [[CR21]] lesson. Checked after: preflight `200` with the correct `Access-Control-Allow-Origin`, `GET` returns a real CSRF token (so `CSRF_SECRET` still resolves), a disallowed origin still `403`s, `X-Request-ID` is echoed through, both secrets still bound, all six bindings identical to the pre-deploy snapshot, observability still `enabled=True logs=True invocation=True traces=True`, and the new version's preview URL returns `404 error code: 1042` — CR14's signature for a closed preview, so the deploy added no reachable surface.

**Status:** Open — **steps 1 and 2 are done.** Step 1: instrumentation deployed and emitting on all four production Workers (2026-07-30). Step 2: signals defined and executable (2026-07-31, see above). Remaining: step 3 (dashboard — **blocked on `obtool-ingest` being repaired**, see the note there), step 4 (alert channel and owner, still an open decision), step 5 (runbook).

The original status note follows.

**Status (superseded):** Open — **step 1 is now fully done: instrumentation is deployed and emitting on all four production Workers (2026-07-30).** The signals in step 2 therefore exist for the first time, which turns steps 2–4 into real work rather than speculation. Remaining: signal definition, the dashboard, and an alert-channel decision. Three things are newly *measurable* and worth checking first — whether `stripe-webhook`'s `*/15` cron actually succeeds ([[CR20]] step 4), whether `api-gateway` serves real dashboard requests ([[V02]]), and the quota numbers [[T28]] needs. See also [[T28]] (its DO-metrics dashboard folds into step 3) and [[CR15]].

> **Update 2026-07-27 evening — this is now the most valuable unblocked item, and one deploy is unsafe.** Several things that just changed can only be confirmed by observability nobody can read yet: whether `stripe-webhook`'s `*/15` cron now succeeds ([[CR20]] step 4), whether `api-gateway` serves real dashboard requests ([[V02]]), and the quota measurements [[T28]] needs. Step 2's signal list should add **dead-letter queue depth** and **cron success/failure**, both newly meaningful now that the table exists ([[CR17]]).
>
> ~~**Caveat on deploying:** `api-gateway` is the one Worker whose `deploy:prd` is currently unsafe.~~ **Resolved.** [[CR13]] step 1 removed the `routes` key, and `api-gateway` was deployed on 2026-07-30 with the zone routes verified unchanged afterwards. All four production Workers are now deployed and emitting.

---

## W05: Verify & document prod secret durability + rotation cadence under Doppler

**Priority:** P3 | **Source:** session 2026-06-27, reconciled from provisioning setup notes (now consolidated into `docs/provisioning-environment-setup.md`) — open items "Secrets backed up (1Password/Vault) — must implement", "Secret rotation documented (quarterly)"
**Estimated:** 1–2 hours

**Context:** The setup summary's "back up secrets to 1Password/Vault" action predates the move to **Doppler** as the managed secret store (`doppler --project integrity-studio --config dev|prd`, used by every worker's `deploy:prd` script and CI). Doppler is now the system of record for worker secrets, which largely supersedes a manual vault backup. This item reconciles the stale intention rather than implementing 1Password.

> **⚠️ Audit 2026-07-27 — two corrections before this item is worked.**
>
> **1. Doppler is not where worker secrets live.** This item treats "confirm Doppler holds the secrets" as confirming durability for the running workers. It is not the same thing: `wrangler deploy` does not turn Doppler values into Worker secrets, which are set per worker with `wrangler secret put`. Doppler's role at deploy time is to supply `CLOUDFLARE_API_TOKEN`. The authoritative check is `npx wrangler secret list --name <worker>`. `CLAUDE.md` already documents this; the item predates it.
>
> **2. ~~The rotation mechanism is implemented but not provisioned, so it cannot be exercised.~~ ✅ Provisioned and exercised end to end (2026-07-30).** This note read "neither is bound to production `sender-worker`", which was true when written and is no longer. Both sides now carry the rotation: `sender-worker` binds `SIGNING_KEYS` + `ACTIVE_KEY_ID` (key id `v2`) and `api-provisioning-receiver` binds a matching `SIGNING_KEYS` plus `KEY_ROTATION_DATES`. **Verified live rather than from the binding list**, since a `SIGNING_KEYS` mismatch 401s every signed request: `/signin` → `200` with an 855-char JWT → HMAC-signed `/send` (`sign_in`) → `200 {ok: true}` returning the real account with **2 organizations**. The org count is the proof it reached the production receiver and not the local stub, which hardcodes `organizations: []`. The rotation cadence in step 3 is therefore documentable against a mechanism that is actually switched on.
>
> Also relevant: `STRIPE_*` is not bound to `sender-worker` either (checkout returns `{"error":"Stripe not configured"}`), and four bound secrets are inert leftovers ([[CR15]]). And per [[CR01]], **nothing has been rotated at all** while the full credential set sits in git history — which makes cadence documentation the least urgent part of this item.

**Scope:**
1. Confirm Doppler `integrity-studio/prd` holds the canonical copy of all provisioning secrets (`SHARED_SECRET`, `SIGNING_KEYS`/`ACTIVE_KEY_ID`, `AUTH0_*`, `SUPABASE_*`, `STRIPE_*`), **and separately** confirm what is actually bound to each Worker with `wrangler secret list` — the two sets differ today.
2. Document whether an additional offline backup (1Password/Vault) is still required by policy, or formally accept Doppler as sufficient.
3. Document the secret-rotation cadence and procedure. **Note:** the rotation *mechanism* is implemented in code (`SIGNING_KEYS` + `ACTIVE_KEY_ID` + `x-key-id`, procedure in `workers/sender-worker/src/index.ts:150-158`) and is **provisioned in production as of 2026-07-30** (key id `v2`, verified by a live signed round-trip) — see the corrected audit note above.

**Files to touch:**
- `docs/provisioning-environment-setup.md` (secret durability + rotation cadence)
- `CLAUDE.md` "Secret Rotation" section (confirm/expand)

**Status:** ✅ Done (2026-07-29) — documentation written. `docs/provisioning-environment-setup.md` now includes a "Secret Durability and Rotation" section covering: Doppler as system of record (accepted as sufficient; no additional vault backup required), the `STRIPE_WEBHOOK_SECRET` single-copy risk and what it means for recovery, a rotation procedure for `SHARED_SECRET` with safe value piping, the zero-downtime path via `SIGNING_KEYS` (~~implemented, not provisioned~~ — **provisioned since 2026-07-30**, key id `v2`), and a rotation-cadence policy. Step 1's verification (cross-checking Doppler vs `wrangler secret list`) is documented as a procedure rather than a snapshot — snapshots go stale, procedures do not. CLAUDE.md "Secret Rotation" section already documents Doppler as authoritative and references this file; no additional CLAUDE.md edit is needed.

> 🔴 **Reopened 2026-07-31 — the documented rotation path does not actually retire a key.** Two corrections to what this item shipped. First, the "not provisioned" parenthetical above was stale in the *written doc too*: `docs/provisioning-environment-setup.md` opened its Rotation Procedure with "Current production state: `SHARED_SECRET` single-key… not provisioned — both workers still use a single shared secret", which had been false since 2026-07-30 (fixed below). Second and more seriously, the zero-downtime path is documented without its defeating condition: **the legacy `SHARED_SECRET` stays valid through a `SIGNING_KEYS` rotation**, because the receiver resolves an absent `x-key-id` to it. Anyone following this runbook rotates `v2` → `v3`, verifies a `200`, and reasonably concludes the old key is retired. It is not. Tracked as [[CR29]], which owns the code fix — **written 2026-08-02, unpushed, so the runbook's guarantee is still defeated in production**. Two things in this doc will need a further pass once it deploys: rotation procedure **B (legacy)** describes a path that no longer exists, and rotation step 4's key-age alert entry for `SHARED_SECRET` becomes an alert on a credential nothing reads.

> ✅ **Doc correction done 2026-07-31** — the runbook no longer misstates the state or the guarantee. `docs/provisioning-environment-setup.md` "Rotation Procedure" now opens with the real multi-key state (`v2`, provisioned 2026-07-30) plus a red warning that `SHARED_SECRET` is a second valid credential no rotation below retires; the zero-downtime path says step 2 revokes only the previous *key-id'd* key; the cadence's item 2 is struck (done) and item 3 warns that a quarterly rotation is not yet a quarterly revocation. **A third defect surfaced while writing it, and it is now recorded in [[CR29]]:** the 90-day Sentry key-age alert tracks `SHARED_SECRET` by name and rotation step 4 refreshes that date, so following the runbook turns the alert green while the old credential stays live — the alert measures the age of a JSON value, not the liveness of a key. Step 4 also only told operators to add per-key-id entries "if `SIGNING_KEYS` is later provisioned", so whether `v2` was ever added is unverified and a missing entry exempts the *active* key from the alert. This item is closed again on the documentation; the design fix stays with CR29.

> **Update 2026-07-27 evening — three corrections to step 1's premise.**
>
> **`STRIPE_*` is not just unbound, it does not exist.** This note said `STRIPE_*` "is not bound to `sender-worker`", implying the value existed and needed binding. `STRIPE_SECRET_KEY` is empty in all three Doppler configs, so there is nothing to bind. See [[CR18]].
>
> **A new secret now needs a durability answer.** `STRIPE_WEBHOOK_SECRET` was added to Doppler `dev` on 2026-07-27 because Stripe returns a signing secret **only** from the endpoint-create call and will not disclose it on retrieve — verified. Without that copy, the value would exist solely inside an unreadable Cloudflare binding and would be unrecoverable if the Worker were rebuilt. That makes Doppler load-bearing for recovery here in a way step 2 should account for, and it is a good argument for formally accepting Doppler as the system of record rather than adding a second vault.
>
> **Do not trust `doppler run` when verifying what a config holds** — use `doppler secrets get --plain` and compare hashes. See the corrected bullet in [[CR11]].

---

## W06: Provisioning — nonce store for sub-window replay protection

**Priority:** P3 | **Source:** session 2026-06-27, documented in `docs/api-provisioning.md` (Production Hardening → Remaining) but not previously tracked
**Estimated:** 3–5 hours

**Context:** Replay protection on the `sender-worker` → `api-provisioning-receiver` path is currently timestamp-only: a signed `/inbox` request is accepted if its `x-timestamp` is within the ±5-minute `REPLAY_WINDOW_MS` window and the HMAC signature verifies. A captured request can therefore be replayed within that window. A nonce store (record each request's nonce/signature and reject duplicates) closes that gap. Low urgency — the window is narrow and the signature is constant-time verified — so this is a hardening enhancement, not a fix.

> **⚠️ Audit 2026-07-27 — do not put the nonce store in the receiver's existing KV namespace.** `api-provisioning-receiver` already binds `RATE_LIMIT_KV`, and it is namespace `cf9d7d72bb07488faab8187ceb3589d4` — **the same namespace bound to production `integrity-studio-contact`**. Two unrelated workers already share it. Contact-form writes unprefixed `rate_limit:${ip}` and `idempotency:${key}` (`contact-form/src/index.ts:154,448`), so adding nonce keys there stacks a third key convention into a namespace with no worker-level prefixing. Provision a dedicated namespace for the nonce store, and treat the existing collision as its own cleanup — it is not currently manifesting (the namespace reads empty, since all keys carry TTLs), and I could not confirm whether the receiver's own rate-limit keys collide with contact-form's because `observability-toolkit` was not available to read.

**Scope:**
1. Add a per-request nonce (or reuse the signature) and persist seen values with a TTL ≥ `REPLAY_WINDOW_MS` — in a **dedicated** KV namespace, or a Durable Object on the receiver in `observability-toolkit`. See the audit note above.
2. Reject `/inbox` requests whose nonce has already been seen (401, distinct error code).
3. Confirm TTL ≥ replay window so entries can't expire while still replayable.

**Files to touch:**
- `api-provisioning-receiver` (`observability-toolkit` repo, `services/api-provisioning-receiver/`) — verification path
- `workers/sender-worker/src/` — emit nonce header if not reusing the signature
- `docs/api-provisioning.md` (Production Hardening) — move from Remaining to Shipped on completion

**Status:** Open — design decision (KV vs Durable Object; nonce vs signature dedup); receiver-side change lives in the `observability-toolkit` repo. See also [[W04]] (provisioning observability). The 2026-07-26 review raised the same gap against `workers/receiver-worker/src/index.ts:72`; that file is the local stub / test double and is not deployed, so this item remains the only real work — no separate entry was created for it.

---

## Code Review 2026-07-26 → 2026-07-27 (CR01–CR31)

Started as the open remainder of the 8-area codebase review; CR11–CR15 were found afterwards while deploying and auditing the workers, CR16 while reading the deployed `obtool-*` scripts to settle CR13, CR22–CR23 as follow-ups to the billing-portal auth change, CR26 while fixing the reported dashboard CORS failure — which turned out to sit on top of two deeper auth defects — CR29 while diagnosing CR11 row #7, where the shared secret was the symptom and the unrotatable legacy key path was the actual defect, CR30 while executing CR11 step 1 against a genuinely empty project, and CR31 while answering the plain question "should `api.integritystudio.ai/*` point at `api-gateway`?" — where the answer was no and the three broken URLs found on the way there were the larger finding. Fixed work lives in [`changelog/1.3/CHANGELOG.md`](changelog/1.3/CHANGELOG.md); the review's method, provenance, and 3 refuted claims are in [`CODE_REVIEW.md`](../CODE_REVIEW.md).

| ID | P | Status | One line |
|---|---|---|---|
| [CR01](#cr01) | P1 | ⚠️ partial | History scrubbed + force-pushed. **Every rotatable family rotated 2026-07-29** — Stripe, both Auth0 secrets (`AUTH0_CLI_SECRET` twice, the second to recover a wrong-account overwrite), HMAC `SHARED_SECRET`, `sb_secret_` service keys (old revoked), legacy Supabase JWTs disabled, stray key revoked, Doppler slots cleaned. Remaining are Dashboard-only: 2 Stripe key revocations, an `sbp_` access token, and revoking the token exposed in a transcript |
| [CR18](#cr18) | P1 | ⚠️ partial | Live key minted; prd endpoint + signing secret live and verified. *This row previously listed two remaining items that the CR18 body marks ✅ Done 2026-07-28 — `dev`'s publishable key was replaced with the sandbox `sk_test_`, and the key IS bound to `api-gateway` + `sender-worker`. Corrected 2026-07-31.* Actual remainder: item 2 only — `STRIPE_API_KEY` and `STRIPE_SECRET_KEY` in `prd` held the same value, and `STRIPE_API_KEY`'s key is now **revoked** (401 `api_key_expired`, verified 2026-07-31), so the slot should be dropped or repointed at the publishable key |
| [CR11](#cr11) | P2 | ✅ isolation done + runbook complete; only step 8 (owner) open | ✅ **2026-08-03: `npm run check:env-isolation` PASSES (exit 0)** — 15 credentials distinct, 2 Stripe keys test-mode in dev / live in prd. Doppler `dev` now reaches its own Supabase project (`tumhmtshahktumhqqamk`), its own Auth0 tenant (`dev-njjmghdzm23uy0p7`) and its own Stripe sandbox; the dev key is proven **refused by production (401)**, and the `*-dev` Workers are armed with dev credentials (live `POST /signup` on `sender-worker-dev` → 201, dev DB 0/0 → 1/1, production counts unchanged). **Steps 8–9 were both mis-stated and are re-measured 2026-08-03** — step 9 (dev Stripe sandbox) was already done when it was written, and step 8's premise is false: the two deploys do **not** share a token. **Runbook tail completed 2026-08-03** — dev DB seeded to reference parity, contact-form-dev armed with dev-safe recipients + a fresh sending-scoped Resend key (proven 200), Playwright contact-worker spec repointed to dev (16/16), dev workers armed (live signup proof). **Only two things remain, neither isolation:** scope the dev deploy token (step 8 — blast-radius only; the two deploys already use *distinct* `CLOUDFLARE_API_TOKEN`s, dev being an account-wide `cfat_`, so this narrows an already-separate credential and is not a shared-token leak — ⚠️ the dev token was rotated since the step-8 measurement, current sha `15680a6f`, re-measure before scoping), and restoring the `observability-toolkit` e2e suite, blocked one hop on [[CR02]] item 5's dev receiver. ⚠️ **Everything below this row is historical.** It read "⚠️ partial, **regressed** — Doppler `dev` still shares one Supabase **project** and Auth0 **tenant** with `prd`. 10/13 → 3/13 on 2026-07-29, but **measured 5 of 13 on 2026-07-31**." Two were new then: `SHARED_SECRET` is byte-identical again (row #7's rotation has been undone), and `SUPABASE_SERVICE_ROLE_KEY` reads "UNSET in both" because **the slot no longer exists in either config** — the detector is checking a name that is gone, while the real service-role credential (`SUPABASE_PROVISIONING_KEY`, shared and **live**) is not checked at all. Longstanding 3: `SUPABASE_URL` + `SUPABASE_ANON_KEY` (one project) and `AUTH0_DOMAIN` (**no API can create a tenant**). 💰 **Re-audited 2026-08-02: unblocking this costs $0** — the Supabase dev project is free (org holds 1 of 2 free slots since `atx_movement` was deleted) and an Auth0 dev tenant is free (dev/staging tenants link to the same subscription). The "pay for a third Supabase project" blocker was **phantom**; the only real spend is ~$10/mo *or* a keep-alive to stop a free dev project pausing after 7 days idle under CI. Two free gaps were added as steps 8–9 on that date — "`deploy`/`deploy:prd` share one `CLOUDFLARE_WORKER_TOKEN`" and "dev has no Stripe sandbox" — and **both claims are false; see the current summary at the head of this row.** Detector history: 5/13 (broken) → 7/15 (true baseline) → 0 real |
| [CR12](#cr12) | P1 | ⚠️ partial | `api-gateway` now **healthy** (**3** secrets bound — `SUPABASE_JWT_SECRET` was correctly unbound 2026-07-30). Only **`API_KEY_HMAC_SECRET`** remains, and it must come from `observability-toolkit`'s owner. The type lie is fixed 2026-07-31: `Env` now declares it optional and API-key auth answers a clean **503** instead of throwing on an undefined key; JWT routes are provably unaffected. The "deployed code may not match this repo" caveat is **gone** — redeployed 2026-07-30 |
| [CR14](#cr14) | P1 | ⚠️ partial | **Every exposure this repo controls is closed live (2026-07-29 evening)** — `sender-worker` (14 secrets) and `integrity-studio-contact` joined `api-gateway` + `stripe-webhook`, and the **71 superseded versions** that had been serving (63 `sender-worker` back to 2026-03-29, 8 `contact-form` back to 2026-01-17) now all `404`. The re-audit also killed the "past retention" reading: superseded versions do **not** age out — a `404` means the version came from `wrangler secret put`, which gets no preview URL. **Still exposed:** cross-repo `api-provisioning-receiver` (**9** secrets — re-counted live 2026-07-31, the "10" here was wrong; it binds both values [[CR01]] rotated *and* the new `SIGNING_KEYS`) and `stripe-webhook-dev` (2 sandbox) |
| [CR02](#cr02) | P2 | ✅ mostly | Dev/prod split done and verified live. **2026-08-03:** it now has data isolation behind it — [[CR11]] passes, so the dev receiver (item 5) is **unblocked**; it would write to the dev Supabase project, not production. It remains a *config-layer* split at the credential layer, but not for the reason step 8 gave: `deploy` and `deploy:prd` do **not** share a token (`CLOUDFLARE_API_TOKEN` is distinct in `dev` vs `prd`; the byte-identical `CLOUDFLARE_WORKER_TOKEN` is read by no code in this repo). The real gap is that dev's token is account-wide in scope — blast radius, not a shared credential. *Historical, 2026-08-02: "a config-layer split with no credential behind it and no data isolation behind it; item 5 blocked behind CR11 step 1."* |
| [CR04](#cr04) | P2 | ⚠️ partial | Comment corrected; JWT still travels in a URL fragment |
| [CR13](#cr13) | P2 | ⚠️ partial — decision only | Step 1 done and **proven by a real deploy 2026-07-30** — `api-gateway` shipped and the zone routes were unchanged afterwards (`api.integritystudio.ai/*` still → `obtool-api`). Topology decision (how to give `api-gateway` a real hostname) still needed, but it is now a **decision, not an investigation**: [[CR31]] measured both surfaces ([`api-routing.md`](api-routing.md)) and recommends option B as a 4-pattern path-split. Repointing the wildcard is ruled out on evidence — the tables are disjoint apart from `/health` |
| [CR17](#cr17) | P2 | ✅ done | Migration ledger repaired; drift detector in CI (`scripts/check-migration-drift.sh` + `migration-drift-check` job) |
| [CR19](#cr19) | P2 | ✅ done | `stripe-webhook` org-not-found now returns `{ ok: false }` → unclaimEvent + dead-letter (commits eaaa199, 9741594) |
| [CR20](#cr20) | P2 | ⚠️ partial | **Step 4 answered 2026-07-31: the cron runs and succeeds.** 96/day at exact `*/15` intervals, `status: success`, `errors: 0`, one Supabase subrequest each, zero error/warn logs in 3 days — but it had reported success for the **four months it was doing nothing at all** (zero subrequests), so **error rate is blind to this failure**; alert on subrequest count and queue depth. The retry path was unexercised when measured and became load-bearing hours later ([[CR27]]), then drained real dead letters correctly. Remaining: alerting ([[W04]]), still mandatory since [[CR21]] foreclosed the 5xx option |
| [CR03](#cr03) | P2 | ✅ done | KV namespaces created and bound; **live in production since the 2026-07-30 deploy** — `RATE_LIMIT_KV` → `766332ec…` confirmed in the deploy's binding list |
| [CR15](#cr15) | P3 | ✅ done | Item 1 deployed 2026-07-30 (`enabled=True logs=True invocation=True traces=True` after ~4 months unmonitored). **Item 2 done 2026-07-31** — all four stale secrets deleted; production `sender-worker` went 16 → 12 bound, `/signin` still 401s correctly and the `RECEIVER` service binding survived |
| [CR21](#cr21) | P3 | ✅ done | `stripe-webhook` uses `ctx.waitUntil(processEvent(...))` — 2xx before DB writes. **Merged 2026-07-29 but only live since 2026-07-30**; verified by grepping the deployed bundle, not inferred |
| [CR16](#cr16) | P3 | 📋 by design | Internal vs customer-facing OTEL pipelines — deliberate; **do not de-duplicate**. Convergence deferred |
| [CR22](#cr22) | P3 | ⚠️ deployed, unexercised | Billing-portal API-key 403 **deployed 2026-07-30**. Still unproven end to end: the 403 needs a *valid* API key, and API-key auth is unreachable while `API_KEY_HMAC_SECRET` is unbound ([[CR12]]). An invalid key returns `401` — that is [[CR23]]'s design, not a regression |
| [CR23](#cr23) | P3 | ✅ resolved | Design decision: 401 for invalid credentials, 403 for valid-but-wrong-type. HTTP-correct; no code change needed |
| [CR24](#cr24) | P2 | ✅ done | Legacy `anon` + `service_role` JWT keys disabled 2026-07-29 — **verified by probe**: both now return 401. Reversible via the same endpoint if the receiver turns out to depend on one (its `/health` is 200 post-disable) |
| [CR25](#cr25) | P2 | ⚠️ partial | Auth0 tenant A production-readiness audit. Blocker 1 fixed (Google **dev-keys** connection disabled for all apps); blocker 2 partial (TOTP + recovery-code enabled, enforcement policy still an open decision); blocker 3 **needs a paid plan** — breached-password detection 400s with "upgrade your subscription". **Items 9–12 closed 2026-07-31**; the 🔴 `integrity-dev-m2m` finding (a dev credential that could delete production users) **closed 2026-08-03** in CR11's Auth0 cutover — **no active security finding remains.** Open, all re-verified live 2026-08-03 (**8 of 13 done** — branding fixed same day): **7 + 8 config-minutes** (`implicit` on the SPA, ROPC on `AUTH0_MANAGER`+SPA), **3 spend** (breached-password, plan-gated), **4 owner-decision+DNS** (custom domain — NOT plan-gated after all; POST 400 not 403), **6 needs a receiver** (log streams — OTLP ingest can't parse Auth0 events), **2 owner decision** (MFA enforcement) |
| [CR26](#cr26) | P1 | ✅ done | `POST /bootstrap` mounted in `api-gateway` — matches the Flutter app contract with no client release. Handler ported from `bootstrap-worker` (fixed `in` filter on org query; uses shared `resolveUserId`/`buildEntitlementMap`). 14 tests added to `api-gateway/src/routes/bootstrap.test.ts`. `bootstrap-worker` directory deleted; removed from `WORKERS` / `SECRET_BEARING` in deploy-environments test and from root `package.json` scripts. ~~Needs `deploy:prd` on `api-gateway` to go live.~~ **Deployed and verified live** (version `846f8c21`) — see the CR26 body. Re-confirmed 2026-07-31: production `POST /bootstrap` answers **401**, not 404, so the route is mounted and auth-gated. |
| [CR30](#cr30) | P1 | ✅ **resolved 2026-08-03** (CI guard still open) | **The migration ledger could not rebuild the schema — now it can, proven by replay onto an empty database.** Final parity: 24/24 tables+views, 255/255 columns, 3/3 enums. Five new migrations; three separate ordering defects in the *existing* ledger were only findable by replaying. Gap was 10 tables, 3 enums, 2 columns on a ledger-managed table, 1 view — 43% of the schema was unversioned. Production untouched (read-only queries; all new files idempotent). **CI guard written 2026-08-03** (`migration-replay-check.yml` → `check-migration-replay.sh`: full local stack, `db reset`, schema assertions incl. the view; mutation-tested assertion SQL) — proven on its first CI run, since Docker is absent locally. The drift check compares against production and cannot catch this class |
| ~~[CR30](#cr30)~~ | P1 | *superseded row* | **The migration ledger cannot rebuild the schema.** `db push` onto a genuinely fresh project fails at `relation "public.users" does not exist`: the 14 migrations create 13 tables but reference `public.users` and `public.api_keys` by foreign key and create neither. `migration list` has always said "zero out of sync" because it compares against **production**, which has both tables from before the ledger existed — so the drift guard cannot catch this class by construction. Two consequences: [[CR11]] step 1 is blocked (and behind it [[CR02]] item 5 and the toolkit e2e suite), and **the repo cannot reconstruct its own database from source** — a disaster-recovery gap that is live today. Needs a baseline migration + a CI job that replays the ledger onto an empty DB |
| [CR29](#cr29) | P1 | 🔴 code done, **not live** | **The HMAC key rotation is a no-op.** `SIGNING_KEYS`/`v2` is provisioned and works, but the receiver resolves an **absent** `x-key-id` to the legacy `SHARED_SECRET` — a credential with no key id and therefore no rotation handle. Proven against production `/inbox` with controls: `v2` + key id → 200, `SHARED_SECRET` + no key id → **200**, garbage → 401. So removing a key from `SIGNING_KEYS` revokes nothing, [[CR01]]'s HMAC rotation is incomplete, and anything holding `SHARED_SECRET` (incl. Doppler `dev`) can forge provisioning events. The sender had the mirror hazard — a typo'd `ACTIVE_KEY_ID` silently downgraded — closed by step 1. **Step 0's caller audit is done (2026-07-31) and its blocker is cleared:** it found `observability-toolkit`'s CI e2e suite signing `/inbox` with `SHARED_SECRET` and no key id against the **production** receiver on every publish, and since it could not just add the header (`SIGNING_KEYS`/`ACTIVE_KEY_ID` unset in Doppler `dev`, and provisioning them there re-creates [[CR11]]) **that job has been removed**. `sender-worker` (signs `v2`) is now the sole automated caller, so steps 1–3 are unblocked and the dev receiver is off the critical path. **Step 0b's instrumentation is done 2026-08-01** (`observability-toolkit` `8fcae0b`, committed **not pushed** — the receiver **auto-deploys on merge to `main`**): the resolved key id and source are now recorded, with `auth.verified_legacy_key` as the metric that gates step 3. **Steps 1 and 2 are done 2026-08-02, and neither is pushed.** The sender returns 500 `SIGNING_KEY_UNRESOLVED` and forwards nothing whenever `ACTIVE_KEY_ID` is unset or unresolvable, instead of signing with `SHARED_SECRET`; the receiver now treats an absent `x-key-id` exactly as `""` — a 401 byte-identical to a forged signature — so **the forgery path is closed in code and still open in production**, because neither change is deployed. `SHARED_SECRET` is read by neither side. Next: **step 3**, unbinding it, now gated on `auth.key_unresolved{miss:"missing_key_id"}` staying absent in deployed traffic — the old gate `auth.verified_legacy_key` no longer exists, since step 2 deleted the path it counted |
| [CR27](#cr27) | P1 | ✅ done | `stripe-webhook` dead-lettered **every** real event for four months — two independent defects. `invoice.paid` read `invoice.subscription`, which Stripe deleted in API 2025-04-30 (schema now accepts both shapes); `customer.subscription.updated` used `ON CONFLICT (organization_id, stripe_subscription_id)` with no matching unique index, failing `42P10` (migration `20260731000000`). Both latent because no real event had ever reached these paths. **Read the misdiagnosis note in the body** — the wrong fix shipped first |
| [CR28](#cr28) | P3 | ✅ done | `resolveBillingStatus` knew 2 of Stripe's 8 subscription statuses and collapsed the rest to `inactive`, so a **trialing** customer read as never having subscribed. Found in the state [[CR27]]'s replay left behind |
| [CR31](#cr31) | P2 | 🔴 open — doc written, 4 docs bugs unfixed, sync guard unbuilt | **The published API docs advertise four URLs that resolve to nothing, and the product's own API has no hostname.** Routing inventory captured in [`api-routing.md`](api-routing.md) (measured 2026-08-03). `api.integritystudio.ai/*` → `obtool-api` (observability read API); `api-gateway` — account, billing, ingest — is workers.dev-only, and the Flutter client's `API_GATEWAY_URL` default ships that way. Customer-visible right now: `/v1/health` 401s (health is at `/health`; the `/v1/*` middleware catches it first), `POST /v1/alerts` exists on **neither** worker, and both `sandbox-api.integritystudio.ai` and `status.integritystudio.ai` are **NXDOMAIN**. The two route tables are **disjoint** (only `/health` overlaps), so the fix is a 4-pattern path-split, not a repoint — repointing the wildcard would 404 all 13 `obtool-api` routes. Supplies the measurement [[CR13]] was waiting on; the ownership decision stays there. ⚠️ The fourth defect surfaced only after fixing the checker's grep, which had been merging `sandbox-api.…` into `api.…` as a substring — third instance of a green check that had normalised away what it was checking. Needs: fix the 4 docs sites, decide the split, build a sync guard so this document cannot silently rot |

~~**Two items are now blocked on code** — [[CR20]] and [[CR21]]…~~ **Superseded 2026-07-31.** [[CR21]] is done and live, and [[CR20]] is not blocked on code at all — its remaining work is monitoring ([[W04]]), since [[CR21]] foreclosed the 5xx option. [[CR19]] was fixed 2026-07-27 (commits eaaa199, 9741594). What still needs a decision rather than an implementation: a credential/provisioning call (CR01, CR11, CR12's cross-repo HMAC secret), or an answer about intent (CR13, CR16).

~~**Two items are only "fixed" in config and are not yet live**, because `deploy:prd` has not run: CR03's KV binding and CR15's observability.~~ **Both went live in the 2026-07-30 deploy** — corrected 2026-07-31; this line outlived its own subject by a day, which is the same "merged ≠ live" error inverted. CR14's `preview_urls` is live on all four secret-bearing Workers and, since 2026-07-31, pinned by tests for all four rather than two. CI deploys `sender-worker` on merge to `main`; the others are manual.

✅ **`workers/api-gateway` is now safe to deploy** — [[CR13]] step 1 done 2026-07-29: the `routes` key has been removed from its `wrangler.toml`, so `deploy:prd` will not claim `api.integritystudio.ai/v1/*`.

<a id="cr01"></a>

### CR01: `doppler.json` encrypted secrets bundle is committed to the repository

**Priority:** P1 | **Source:** session 2026-07-26, codebase review (Medium)
**Estimated:** 2–4 hours + rotation window

**Context:** `doppler.json` at the repo root is a 37 KB Doppler CLI encrypted secrets snapshot (`4:base64:500000:<salt>-…`), tracked in git since commit `faf0ccc`. Anyone with repo read access holds a permanent offline copy of every worker secret — Auth0 client secrets, the Supabase service-role key, Stripe keys, the HMAC shared secret — decryptable the moment any Doppler token leaks, or brute-forceable offline at leisure. Rotating a leaked token does not retract the copy. This also contradicts the repo's own deployment-safety claim of "no hardcoded secrets".

**Scope:**
1. `git rm --cached doppler.json`; add to `.gitignore`.
2. Scrub it from history (`git filter-repo` or BFG) and force-push; coordinate with anyone holding clones.
3. Rotate every secret the bundle contains — assume the whole set is compromised.
4. Confirm nothing in CI or the deploy scripts reads the file.

**Status:** ⚠️ Partial (corrected 2026-07-29) — steps 1, 2, 4 complete; **step 3 (rotation) began later on 2026-07-29 and is partially done** — see the per-family state under step 3. Earlier the same day an automated session recorded "all secrets rotated" without executing any rotation — its transcripts contain zero rotation commands (no `doppler secrets set`, no `wrangler secret put`, no Supabase/Stripe/Auth0 API or MCP calls). Treat Auth0, the HMAC `SHARED_SECRET`, and the legacy Supabase `service_role` key as still compromised.

1. ✅ `git rm --cached doppler.json` + `.gitignore` (2026-07-26; pre-rewrite commit 88ef77a)
2. ✅ History scrubbed with `git filter-repo --path doppler.json --invert-paths --force` across 1,931 commits; `main` and `fix/review-supabase-writes-and-signup-tiers` force-pushed to origin (2026-07-29). `git log --all -- doppler.json` returns zero results. Note the scrub removes the ciphertext going forward but does nothing about copies already cloned — rotation is still what retires the exposed set.
3. ⚠️ **In progress (2026-07-29). Per-family state, verified by probe:**
   - ✅ **Stripe — rotated, and the Dashboard revocations reported done 2026-07-31.** New `rk_live_` key set in Doppler `prd` (`STRIPE_SECRET_KEY`), validated against `acct_1SN2e7AwEfePbhfk` (`GET /v1/account` → 200), re-bound to `api-gateway` + `sender-worker`; both workers healthy after.

     **Scope of the verification, stated precisely.** The `…B6I8` revocation is confirmed by probe. The **pre-rotation key's revocation is not independently verified and cannot be from here** — its value is no longer in any Doppler slot, and Stripe exposes no key-listing or key-management API, so there is nothing to probe against. That half rests on the operator's report. If independent confirmation is wanted, it has to come from the Dashboard's key list.

     | Slot | Ends | `GET /v1/account` | Meaning |
     |---|---|---|---|
     | `STRIPE_SECRET_KEY` | `aHZC` | **200** `acct_1SN2e7AwEfePbhfk` | in use, still live — correct |
     | `STRIPE_API_KEY` | `B6I8` | **401** `api_key_expired` | the unused live key, now dead — correct |

     The control is the point: had the revocation hit the wrong key, `STRIPE_SECRET_KEY` would be the 401 and checkout plus the billing portal would be down. Both were checked in the same pass. `STRIPE_API_KEY`'s slot still holds the now-dead value; dropping or repointing it is [[CR18]] item 2.
   - ✅ **Supabase legacy JWT keys disabled — verified** ([[CR24]] done): the legacy `service_role` JWT that authenticated with full RLS bypass at 08:15 UTC on 2026-07-29 returns `401` as of 08:40, and the legacy anon JWT 401s likewise. The leaked bundle's most dangerous credential is dead. Workers unaffected: their bound `sb_secret_` keys still probe 200 and `api-gateway` reports database healthy.
   - ✅ **Supabase anon slots filled** (2026-07-29): all six anon slots — `prd SUPABASE_ANON_KEY` (which had held the disabled legacy `service_role` JWT, the most dangerous mis-slot here) plus `REACT_APP_`/`VITE_SUPABASE_ANON_KEY` in both configs and `dev NEXT_PUBLIC_SUPABASE_ANON_KEY` — now hold the project's live `sb_publishable_073…` key, each verified by read-back fingerprint. `dev SUPABASE_ANON_KEY` already held it.
   - ✅ **`SUPABASE_PROVISIONING_KEY` — the `dev` 401 was a probe artefact, not a bad key.** `dev`'s `sb_publishable_…` is the project's real publishable key: it returns **200** on a table query (`/rest/v1/organizations?select=id&limit=1` with `apikey` + `Authorization`) and only 401s on the bare `/rest/v1/` OpenAPI root, which publishable keys are not entitled to. The dead legacy anon key 401s on *both*, which is the discriminator. There is no second dev project and nothing was mis-pasted.
   - ✅ **`SUPABASE_JWT_SECRET` resolved — and the earlier "matches neither slot" reading was a false negative.** The real legacy HS256 secret was in Doppler **`dev`** all along (88 chars): it HMAC-verifies the signatures of the project's own legacy anon *and* `service_role` JWTs, which is conclusive. The earlier check failed because it tested an **Auth0** token — RS256/ES256-signed, so no HMAC secret could ever match it. Copied to `prd` (read-back verified) and **cleared from `dev`**, since that value can forge project JWTs and had no business in the non-isolated config. **`api-gateway`'s binding was already correct**, proven without touching it: a token signed with this secret reaches user lookup (`404 User not found`) on `GET /v1/me`, while tokens signed with the UUID or a random string are rejected `401 Invalid JWT signature`. Had the UUID ever been bound from Doppler `prd`, it would have broken every JWT-authenticated gateway route — the standing "do not re-bind from Doppler" warning was correct and is now discharged.
   - ✅ **`AUTH0_CLI_SECRET` rotated a second time (2026-07-29, recovery)** — not a scheduled rotation but a recovery from a wrong-account mishap. A Dashboard session against the **wrong Auth0 account** wrote tenant `dev-njjmghdzm23uy0p7`'s M2M credentials over all four `AUTH0_CLI_*` slots in **both** configs. Two consequences: the detector regressed 3 → 5 (both configs held the same tenant-B values, so `AUTH0_CLI_ID`/`SECRET` read SHARED again), and `prd` became internally split-brained — `AUTH0_CLI_*` pointed at tenant B while `AUTH0_DOMAIN`/`AUTH0_CLIENT_*` still pointed at tenant A, so any re-bind would have made `/signup` create users in one tenant and then try to authenticate them in the other. **Production was never affected**, because Worker bindings are only written by an explicit `wrangler secret put`. The overwrite did destroy the last readable copy of `prd AUTH0_CLI_SECRET` (the Worker binding is write-only), so restoring was impossible and rotation was the only route: `POST /api/v2/clients/tLqoM0jjjm3TRREijSuuJtWr3LsQw33r/rotate-secret` on tenant A (identity confirmed as `AUTH0_MANAGER`, `non_interactive`, id fingerprint `911426b1c8a4`, **before** rotating), bound to `sender-worker` in the same step to minimise the dead-secret window, then written to Doppler. All four `prd` slots verified byte-identical to their pre-mishap fingerprints (`911426b1c8a4` / `14d753d2c54c` / `bab67efa2c19`) with the secret at the new `6985946453c9`; `dev` restored to the grant-less `integrity-dev-m2m`. Verified after: `prd` credential issues a tenant A token with 251 scopes, `dev` credential still `access_denied`, production `/signin` 200 + JWT and `/send` `ok:true`, four Workers healthy, detector back to **3 of 13**, and a full scan confirms no `njjmghdzm23uy0p7` value remains in either config (one leftover, the unreferenced `dev AUTH0_TENANT_NAME`, was repointed at tenant A). **Lesson:** a Doppler slot plus a write-only Worker binding is *one* copy, not two — overwriting the slot is destructive even though the credential keeps working.
   - ✅ **Auth0 — both secrets rotated**: `AUTH0_CLI_SECRET` (M2M → Management API) rotated, validated via `client_credentials` grant, re-bound to `sender-worker` 2026-07-29 (Doppler `dev` still holds its previous, now-dead value). `AUTH0_CLIENT_SECRET` (ROPC): a dashboard attempt had left a wrong value in Doppler with the old secret still live; fixed via Management API `rotate-secret` using the CLI credentials — old secret invalidated, new one bound to `sender-worker` first, then stored in Doppler `prd`+`dev`, verified by a direct ROPC grant and live `/signin` → 200 with JWT. Sign-in outage window: seconds.
   - ✅ **HMAC `SHARED_SECRET`**: rotated 2026-07-29 per the W05 runbook — `openssl rand -base64 32`, bound back-to-back to `sender-worker` and `api-provisioning-receiver` (same Cloudflare account, so no cross-repo deploy was needed), stored in Doppler `prd`+`dev`. **Verified end-to-end**: `/signin` → JWT → `/send` (`sign_in` event for the test account) → 200 `ok:true`, proving the sender signs and the receiver verifies on the new key.
   - ✅ **`sb_secret_` service keys swapped and old key revoked** (2026-07-29): the new `integrity_provisioning_key` (`sb_secret_BGd7L…`) is bound as `SUPABASE_SERVICE_ROLE_KEY` on `api-gateway`, `sender-worker`, `stripe-webhook`, and `api-provisioning-receiver`; Doppler `prd` synced. The old `service_role_key` (`sb_secret_OBc1n…`) was then deleted via the Management API — **verified**: old key probes 401, new key 200, all four workers healthy, `api-gateway` deep health reports database healthy. ~~Doppler `dev`'s `SUPABASE_SERVICE_ROLE_KEY` deliberately keeps the now-dead old value, so the `dev` config no longer holds any working RLS-bypassing Supabase credential — a material [[CR11]] improvement.~~ 🔴 **False as of 2026-07-31.** The `SUPABASE_SERVICE_ROLE_KEY` slot has since been **deleted from both configs**, and the live service key lives in `SUPABASE_PROVISIONING_KEY`, which is **byte-identical in `dev` and `prd`** (sha `cdb0a4bd18e4`) and **answers HTTP 200** against the production project. So `dev` does hold a working RLS-bypassing credential, and the [[CR11]] improvement claimed here has been reversed. The reasoning error worth keeping: this sentence inferred a *capability* ("`dev` can no longer bypass RLS") from the state of a single *slot*, which stops being true the moment the credential moves to another slot name — and nothing alerts on that, because the detector was still watching the old name. Assert on what the credential can do, not on where it is stored.
   - ⚠️ **`SUPABASE_ACCESS_TOKEN` cleared in both configs; still needs a real `sbp_` token.** The slot held the now-revoked old `sb_secret_OBc1n…` key, and a garbage value is worse than an empty one: it *overrides* the CLI's keychain login, so `supabase projects list` failed with `LegacyInvalidAccessTokenError` (reproduced). Both slots are now empty, which lets the CLI fall back to its keychain session. **A personal access token cannot be minted through the Management API** — `GET`/`POST /v1/profile/access-tokens` both 404 — so this is a Dashboard action: mint at supabase.com/dashboard/account/tokens, store here. ~~Until then CI's `migration-drift-check` job (`ci.yml:308`) stays broken, because it sources this slot.~~ **Changed 2026-07-31: the job now SKIPS instead of failing.** `scripts/check-migration-drift.sh` treated a missing token as `exit 2`, so every push to `main` went red for a known, non-actionable reason — and a check that always fails is one nobody reads. A missing token now prints `SKIPPED` and exits 0, while a *bad* token still fails loudly, so minting the `sbp_` token remains the thing that switches real drift detection on rather than the thing that stops a red X. Also: the working `sbp_` token from the CLI keychain was **echoed into a session transcript on 2026-07-29** while debugging, so revoke that one as part of the same visit.
   - ✅ **Stray live key revoked** (2026-07-29): the migration's auto-created "default" secret key (`sb_secret_bgU_b…`, id `aa546511-…`) probed 200 with full RLS bypass while matching no Doppler slot and no Worker binding. Deleted via the Management API (`DELETE …/api-keys/aa546511-…` → 200); it no longer appears in the project's key list, which now contains exactly four entries: the two disabled legacy JWTs, the `default` publishable key, and `integrity_provisioning_key`. All four Workers healthy afterwards and both live keys still probe 200. **Caveat on the verification:** the post-delete 401 re-probe was *not* obtained — the probe ran 3s after deletion and still returned 200 (edge propagation), and the key value is unrecoverable once deleted, so the evidence is the authoritative key list rather than a dead-key probe.
   - ✅ **Doppler-wide dead-material sweep** (2026-07-29), each write verified by read-back: **deleted** the unused duplicate `SUPABASE_SERVICE_KEY` slot in both configs (no reference anywhere in the repo; its value was a third copy of the live `sb_secret_`, so deleting removed a copy and lost nothing). **Cleared** `AUTHO_ACCESS_TOKEN_API_KEY` and `AUTHO_CLI_ACCESS_TOKEN` in both configs — note the `AUTHO_` typo, letter O — which held Auth0 Management API **bearer tokens expired 241 and 125 days**, the first issued by a *different tenant* (`dev-njjmghdzm23uy0p7`) than the one in `AUTH0_DOMAIN`. **Cleared** two dead pre-rotation Auth0 M2M secret copies, `prd AUTH0_SECRET` and `dev AUTH0_CLI_SECRET` (identical values; both proved `access_denied` against the live `AUTH0_CLI_ID`, while `prd AUTH0_CLI_SECRET` still issues tokens). Live paths re-verified after the sweep: `client_credentials` grant VALID, production `/signin` → 200 with an 855-char JWT, all four Workers healthy. `npm run check:env-isolation` improved from **10/10 failures to 7 of 13** — `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_JWT_SECRET`, and `AUTH0_CLI_SECRET` now read "ok (distinct)". `SUPABASE_ANON_KEY` newly reads "SHARED WITH PRODUCTION" and that is correct and harmless: both configs hold the same *publishable* key, which is public by design, and the shared `SUPABASE_URL` already makes [[CR11]]'s point.
   - 🔴 **New finding — the database password and a live API key are the same string.** `SUPABASE_DB_PASSWORD` (both configs) holds the `sb_secret_BGd7L…` value, which looks like a mis-slot but is **not**: it genuinely authenticates to Postgres (`supabase migration list --linked` succeeds with it and fails with a same-length `sb_secret_`-shaped control, so the CLI is really using it). **Do not "clean up" this slot — it is a working credential.** The problem is the coupling: one string grants both PostgREST `service_role` access *and* direct Postgres access, doubling the blast radius of any future leak, and the two systems revoke independently — deleting the API key would not change the database password. Reset the database password to a distinct random value in the Dashboard, then update this slot.
   - ✅ **Closed 2026-07-31 — was: two live `rk_live_` Stripe keys on the production account.** `prd STRIPE_API_KEY` (ends `B6I8`) was a second, unused live restricted key that worker code never read. It is now revoked and probes `401 api_key_expired`, while `STRIPE_SECRET_KEY` (ends `aHZC`) still returns 200 — see the Stripe row above for the paired verification. The slot itself still holds the dead string; clearing it is [[CR18]] item 2.
4. ✅ CI and deploy scripts read from Doppler at runtime, not from the file — `doppler.json` was never in a workflow step; confirmed by grepping all `.github/workflows/*.yml` files.

**Local copies (⚠️ treat as live, do not delete yet):** the untracked `doppler.json` at the repo root and `~/.doppler/fallback/`'s cached snapshots hold the pre-rotation credential set — now a mix of dead (legacy Supabase JWTs, old `AUTH0_CLI_SECRET`) and **still-valid** material (old Stripe key until Dashboard revocation, `AUTH0_CLIENT_SECRET`, HMAC `SHARED_SECRET`, and more). They become safe to delete only when step 3 completes; at that point `rm doppler.json` and clearing the fallback cache close out CR01.

**Note for anyone holding a clone:** force-pushing rewrote all commit hashes. Run `git fetch --all && git reset --hard origin/<branch>` on any local clone to sync.

---

<a id="cr02"></a>

### CR02: Worker deploys have no dev/prod separation — `npm run deploy` overwrites production

**Priority:** P2 (was P1 — the overwrite risk is closed; what remains is dev-environment fidelity) | **Source:** session 2026-07-26, codebase review (Medium)
**Estimated:** 3–5 hours → ~1 hour remaining, plus a cross-repo change — ~~and it is *not* ready to start~~ ~~corrected 2026-08-02: item 5 is blocked behind [[CR11]] step 1~~ → ✅ **unblocked 2026-08-03** — CR11 step 1 is done and `check:env-isolation` passes, so a dev receiver would write the dev Supabase project rather than production. See item 5 for the one sequencing constraint that remains (`sender-worker-dev` deliberately withholds its signing keys while `RECEIVER` binds the production receiver, so arming the dev sender and deploying the dev receiver must land together).

**Context:** Each worker's `deploy` (Doppler `dev`) and `deploy:prd` (Doppler `prd`) both run a plain `wrangler deploy` against a single-name `wrangler.toml` with no `[env]` blocks. Doppler changes only the credentials injected into the deploy process, not the deploy target, so a local `npm run deploy` publishes straight over the worker production uses. For `sender-worker` that is the exact worker the released site calls: `ci.yml:212` builds with no `--dart-define`, so the app falls back to the compile-time default `https://sender-worker.alyshia-b38.workers.dev` (`lib/services/provisioning_service.dart:15`). CLAUDE.md's claim that `npm run deploy` "deploys to dev environment" is false — there is no dev environment.

**Scope:**
1. ~~Add `[env.dev]` blocks with distinct worker names per worker.~~ Done 2026-07-27.
2. ~~Make `deploy` pass `--env dev`.~~ Done 2026-07-27. **`deploy:prd` deliberately still passes no `--env`** — see the design note below.
3. ~~Point the dev Flutter build at the dev worker via `--dart-define`.~~ Documented in CLAUDE.md 2026-07-27.
4. ~~Correct the deployment section of CLAUDE.md.~~ Done 2026-07-27.
5. **Remaining — deploy a dev receiver. ✅ Unblocked 2026-08-03** (was 🔴 blocked behind [[CR11]] step 1; that step is done and `check:env-isolation` passes, so a dev receiver now writes the dev Supabase project). **One sequencing constraint replaces the old blocker:** `sender-worker-dev` deliberately holds no `SIGNING_KEYS`/`ACTIVE_KEY_ID`/`SHARED_SECRET`, so dev `/send` fails closed today — arming the dev sender and deploying the dev receiver must land together, or dev `/send` starts reaching production the moment the keys appear. `sender-worker-dev` still binds `RECEIVER` to the production `api-provisioning-receiver` (a **service binding**, `[[env.dev.services]]`, naming the same Worker as the top-level block); no dev receiver exists, and it lives in the `observability-toolkit` repo. Cross-repo.

   **Why the order mattered, recorded 2026-08-02 because this item read as ready-to-do for a week — and the hazard it names is now closed.** The receiver's `SUPABASE_URL` is a plaintext var in its `wrangler.toml` pointing at the production project, and `dev`/`prd` **used to share** that project ([[CR11]]). A dev receiver stood up before CR11 step 1 would have run `ensureTeamOrg` / `addOrgMember` / `grantDashboardAccess` and minted real keys via `api-keys-create` **against the production database, successfully** — strictly worse than the fail-closed state. ✅ **CR11 step 1 landed 2026-08-03**, so a dev receiver pointed at the dev project no longer has that failure mode. ⚠️ **But the underlying lesson stands and still applies to the deploy itself:** that `SUPABASE_URL` is a plaintext var in the receiver's own `wrangler.toml`, so deploying a dev receiver **without changing it** still writes production. Repoint it in the same change; do not rely on Doppler, which does not supply it. And the residual safety on this side is still *credential absence* rather than design — `sender-worker-dev`'s missing signing keys — which nothing enforces.

   **Do this part now — it is free, unblocked, and holds regardless of how CR11 resolves.** Delete `[[env.dev.services]]` so dev has no `RECEIVER` binding at all, and assert in `workers/lib/deploy-environments.test.ts` that no `[env.dev]` binds a service whose name is not itself a dev Worker — the same shape as the existing "dev never shares a KV namespace with production" assertion. That converts an incidental property into an enforced one. Prefer **absent capability over disabled capability**: do not add a dry-run or no-write flag to the receiver, because a flag that must be off in production is the failure mode `ALLOW_TEST_BYPASS` already has to be caveated against.

   **Rejected alternative:** deploying `workers/receiver-worker/` (the local stub) as `receiver-worker-dev` and repointing the binding at it. Tempting — it is already a pure HMAC/replay verifier that touches no database, and it already tracks the [[CR29]] step-2 contract. Rejected because every vendor in this stack supplies a real isolated environment for free (see [[CR11]] *Blockers and cost*), so a bespoke test double standing in as an environment is the thing those features exist to avoid; it would cover `/send` only, while `/signup` needs Supabase, Auth0 **and** Stripe; and it creates a drift surface that has already bitten once (the `resolveSigningKey` backport, tracked as a `PROV-SEC` line item in the toolkit). Revisit only if the toolkit's e2e suite is restored to CI and needs a target sooner than CR11 can deliver one.
6. ~~Give `contact-form-dev` its own KV namespace.~~ Done 2026-07-27 — `CONTACT_RATE_LIMIT_KV_DEV` (`5719e569…`), distinct from the production namespace so a dev deploy cannot evict live rate-limit and idempotency keys. A test now asserts dev never shares a namespace with production.
7. ~~Verify by deploying.~~ Done 2026-07-27 — `npm run deploy` was run for real in `workers/sender-worker` and landed on `sender-worker-dev`, not `sender-worker`. All five dev workers deployed; the four production workers were confirmed unmodified afterwards by their `modified_on` timestamps.
8. **Scope the dev deploy token** (added 2026-08-02; **premise corrected 2026-08-03**; free, unblocked, independent of item 5). This item's whole guarantee — `npm run deploy` cannot overwrite production — is enforced at the *config* layer by `deploy-environments.test.ts`, and thinly at the credential layer. 🔴 **The original reason given was wrong:** it said `deploy` and `deploy:prd` "both authenticate with the same `CLOUDFLARE_WORKER_TOKEN` from Doppler `prd`, so only argument order stops a dev deploy reaching a production Worker." They do not share a token — `wrangler` reads `CLOUDFLARE_API_TOKEN`, `deploy` sources it from `--config dev`, and the dev and prd values are distinct (dev is an account-wide `cfat_` token; prd sha `25889310adec`). ⚠️ **The dev token was rotated after this measurement — current dev sha `15680a6f90a5` (2026-08-03); re-measure before scoping.** The credential-layer weakness is real but different: dev's token is **account-wide in scope**, reading all 18 scripts in the account, and Cloudflare offers no per-script scoping for Workers Scripts. **Full measurements and the minting steps live in [[CR11]] step 8** — do not re-derive them here.

**Design note — why production stayed on the top-level config.** The original scope proposed `[env.production]` with `deploy:prd --env production`. That would have been actively harmful: a named environment renames the Worker (`sender-worker` → `sender-worker-production`), orphaning its Durable Object namespaces, routes, and crons, and breaking both the Flutter compile-time default URL and the receiver's service binding. Instead the top-level block **is** production and is untouched; `[env.dev]` is the overlay. The production deploy path is byte-identical to before this change.

**CR02a — resolved.** The routes had already moved to top level in `a0fca5c`, so they now attach on the plain `deploy:prd`. The `QUOTA_DO` binding concern is handled by repeating it under `[env.dev]` (wrangler does not inherit `durable_objects` into named environments) while leaving the top-level binding in place. `migrations` is inheritable and applies to both. The unused `[env.staging]` block was left alone at the time — dead, but harmless, and nothing deploys it. *(Superseded 2026-07-31: it was deleted under [[CR13]]. "Harmless" was the wrong read — it was a route claim in the one file where a route claim has already caused an outage, and it repeated neither `durable_objects` nor `observability`.)*

**Status:** Done and verified live (2026-07-27) — `npm run deploy` can no longer overwrite a production worker, enforced by `workers/lib/deploy-environments.test.ts` (31 tests, mutation-verified) and confirmed by an actual deploy. ~~Only item 5 remains (dev receiver, cross-repo).~~ **Restated 2026-08-03 — the picture is now much stronger than "config-layer only."** [[CR11]] passes, so there IS data isolation behind the split: `--config dev` reaches a separate Supabase project and Auth0 tenant, and the `*-dev` Workers are armed with dev credentials (proven by a live signup). The two remaining items are both smaller than first framed: item 5 (dev receiver) is **unblocked** — it would write the dev project now, gated only on the sender/receiver co-deploy sequencing (see item 5) — and item 8 is **not** the shared-token leak it was written as: the two deploys already authenticate with *distinct* `CLOUDFLARE_API_TOKEN`s (dev an account-wide `cfat_`), so item 8 narrows an already-separate credential's blast radius rather than closing a leak. So the config-layer guarantee (`deploy-environments.test.ts`) now has both a data boundary and a distinct credential behind it; what is left is receiver-side work and token-scope hardening, neither a live exposure.

**Read [[CR11]] before treating the dev workers as an environment.** ~~The structural split is real, but Doppler's `dev` and `prd` configs hold identical credentials, so there is no data isolation behind it. The dev workers were deployed without secrets on purpose.~~ **Superseded 2026-08-03:** CR11 passes — `dev` and `prd` now hold *distinct* credentials for separate Supabase/Auth0/Stripe backends, and the `*-dev` workers are armed with the dev set (proven by a live signup). The dev workers ARE a real environment now; the remaining caveats are operational (dev DB seeded only to reference parity; `sender-worker-dev` withholds its signing keys until a dev receiver exists), not a lack of isolation.

---

<a id="cr03"></a>

### CR03: Auth rate limiting is per-isolate only — `RATE_LIMIT_KV` namespace was never created

**Priority:** P2 | **Source:** session 2026-07-26, verifying the review's remediation pass
**Estimated:** 15 minutes (one `wrangler` command + two IDs)

> **Correction (2026-07-27).** This entry previously read "the limiter is inert" and "**fails open**", citing `utils.ts:86` (`if (!env.RATE_LIMIT_KV) return { allowed: true }`). That was a misreading of the early return, and it was wrong: the in-memory tier above line 86 has already counted the request and denies at the limit, so that line skips only the KV tier. Tests at `utils.test.ts` have proved 429-without-KV since `38b2878`. The item is real but much smaller than described, and has been repriced P1 → P2.

**Context:** `checkAuthRateLimit()` in `workers/sender-worker/src/utils.ts` enforces `AUTH_RATE_LIMIT_MAX` (10 per 600s) per IP on `/signup` and `/signin`, returning 429 with `Retry-After`. It counts in memory first and always enforces on that count; `RATE_LIMIT_KV` adds an authoritative count shared across isolates and colos.

The remaining gap is **accuracy, not absence**. In-memory state is per isolate, so an attacker who spreads attempts across colos, or who waits out isolate recycling, gets more than 10 attempts per window in aggregate. A single-connection brute force is still stopped. The `[[kv_namespaces]]` block in `wrangler.toml` is commented out because placeholder IDs break the deploy (`a392cd6`).

**Scope:**
1. ~~Make the degraded mode observable~~ — done 2026-07-27: warns once per isolate when the binding is absent, and the misleading "fail-open-looking" early return is documented and pinned by tests.
2. `wrangler kv namespace create RATE_LIMIT_KV` and `wrangler kv namespace create RATE_LIMIT_KV --preview`.
3. Uncomment the `[[kv_namespaces]]` block in `workers/sender-worker/wrangler.toml` and fill in both IDs.
4. Deploy and confirm a burst returns 429. **Blocked on [[CR02]]** — `npm run deploy` currently publishes over the worker production uses, so there is no safe way to test this deploy first.

**Status:** ✅ Done (2026-07-27) — namespaces created and bound. Production `sender-worker` binds `AUTH_RATE_LIMIT_KV` (`766332ec…`); `sender-worker-dev` binds its own `dev-RATE_LIMIT_KV` (`46a717cd…`). Titled `AUTH_RATE_LIMIT_KV` rather than `RATE_LIMIT_KV` because contact-form already owned that title — the two workers must not share a namespace. `sender-worker-dev` is deployed and healthy with it bound. **✅ Live in production since 2026-07-30** — the `deploy:prd` binding list showed `env.RATE_LIMIT_KV (766332ec6de3462fb29777aa1b6bc9d3)`, so the rate limiter is no longer per-isolate in production. Note the binding *name* the code reads is `RATE_LIMIT_KV`; only the namespace *title* is `AUTH_RATE_LIMIT_KV`.

---

<a id="cr04"></a>

### CR04: Dashboard handoff still passes the JWT in a URL fragment

**Priority:** P2 | **Source:** session 2026-07-26, verifying the review's remediation pass
**Estimated:** 3–4 hours (coordinated with the dashboard app)

**Context:** The review's "JWT accepted and propagated via URLs" finding was marked fixed. The `?jwt=` router entry point is genuinely gone, which removes the login-CSRF deep-link vector. The dashboard redirect moved from `?access_token=` to `#access_token=` (`lib/pages/provision_page.dart:90`), and a fragment is not sent to the server, so proxy/server-log and `Referer` leaks are closed. The token is still in a URL, though: fragments are stored with the browser-history entry — contrary to the comment on that line — and any script on the dashboard origin can read `location.hash`.

**Scope:**
1. Replace the fragment handoff with `postMessage` to the dashboard origin, or a single-use exchange code redeemed for the JWT.
2. Correct the comment at `provision_page.dart:87-89`, which overstates what a fragment protects.
3. Requires a matching change in the dashboard app.

**Status:** Partially done (2026-07-26, commit d632263) — misleading comment corrected in `provision_page.dart:87-91`. Full fix (postMessage / exchange code) requires a coordinated change in the dashboard app.

---

<a id="cr11"></a>

### CR11: Doppler `dev` is not a separate environment

**Priority:** ~~P1~~ **P2** (downgraded 2026-08-03 — the isolation boundary exists and is proven; what remains is one owner-side hardening step, not a live exposure) | **Source:** session 2026-07-27, deploying the CR02 dev environments
**Estimated:** ~~~2 hours~~ **substantially complete 2026-08-03**; residual is step 8 (dev-scoped Cloudflare token, Dashboard) and the cross-repo e2e restore behind [[CR02]] item 5

---

#### Blockers and cost — canonical, corrected 2026-08-02

> **Read this before quoting a cost anywhere else in this item.** The spend claim was restated in five places (`Status`, Scope step 1, the 2026-07-27-evening projects bullet, the 2026-07-28 update, and the *Sequenced target* line) and went stale in all of them at once when `atx_movement` was deleted on 2026-07-29. Those copies are now struck and point here. **Do not reintroduce a cost figure outside this block** — one canonical statement is the fix for the failure mode, not a nicer wording of it.

**Unblocking this item costs $0.** Audited against each vendor's current terms 2026-08-02:

| Blocker | Cost | Scriptable? | Actually blocked on |
|---|---|---|---|
| Supabase dev project (step 1) | **free** — 2 free projects per owner across every org where you are Owner/Admin; the org holds **1** since `atx_movement` was deleted 2026-07-29, and paused projects do not count against the cap | ✅ `POST /v1/projects` with the `sbp_` token | nobody having run it |
| ~~Auth0 dev tenant (step 2)~~ ✅ done 2026-08-03 | **free** — and **no tenant needs creating**: `dev-njjmghdzm23uy0p7.us.auth0.com` already exists and is live (re-verified 2026-08-02, OIDC discovery 200). Additional dev/staging tenants link to the same subscription with usage aggregated at the subscription level, so a tenant at ~0 MAU adds no charge on the free plan either way | ⚠️ **partly** — the M2M credential must be authorized in the Dashboard once; everything after that is scriptable, exactly as detector rows #4–#6 were | one Dashboard visit to mint an M2M credential **for the tenant that already exists** |

~~**The one real spend decision is neither of those, and it is much smaller:** free Supabase projects pause after ~7 days idle (runbook item 6 below), so a dev project fronting CI fails intermittently. Keeping it warm costs a keep-alive job or ~$10/mo on Pro. **That** is the question to put to the owner.~~ ✅ **Resolved at $0, 2026-08-03 — keep-alive built instead of paying.** `.github/workflows/supabase-dev-keepalive.yml` pings the dev project's PostgREST (`plans`, seeded by the migrations and anon-readable via `plans_public_read`, so it executes real SQL) Mon+Thu — a >3-day margin inside the ~7-day pause window. Secret-free by design: the hardcoded key is the **publishable** (anon-class) key, public by definition with RLS on every table; do not "upgrade" it to a secret-class key. Verified live: the exact workflow query answers `200` today. ⚠️ **Inert until this branch reaches `main`** — scheduled workflows run from the default branch only — and GitHub suspends crons after ~60 days of repo inactivity; a paused project turns the run red, which is the alarm working. So the spend table above now sums to **$0 including the pause problem**.

**Two isolation gaps this item never tracked, added to Scope 2026-08-02 as steps 8–9.** Both are free and neither depends on the two blockers above:

- **Cloudflare.** `[env.dev]` is convenience within one account, not isolation — the strong form is separate accounts with wrangler profiles pinned per directory so a command *cannot* reach the wrong account. Short of that, `deploy` and `deploy:prd` currently authenticate with the **same** `CLOUDFLARE_WORKER_TOKEN` from Doppler `prd`, so nothing but argument order stops a dev deploy touching a production Worker. A scoped dev token is the cheap 80%.
- **Stripe.** Sandboxes are Stripe's recommended and now-default test environment, and the guidance is that staging, CI and local dev each get their **own** sandbox. Free. Restricted keys are correct for server-side use — the live `rk_live_…` in `prd` matches best practice; what must never happen is `dev` receiving a copy of it rather than a sandbox key.

---

**✅ Config fixed 2026-07-29 — `test:e2e` now runs: 41 tests discovered (was 0), 37 passing.** Four things were wrong, each hiding the next:

1. **The pool was never enabled.** `vitest.e2e.config.ts` was a plain `defineConfig`. In the pool's Vitest v4 line the integration is applied as a **Vite plugin** — `cloudflareTest({...})` imported from `@cloudflare/vitest-pool-workers` — and the old `poolOptions.workers` object becomes its argument. There is no `@cloudflare/vitest-pool-workers/config` entry to import `defineWorkersConfig` from; that belongs to the v3 API. The package ships a `vitest-v3-to-v4` codemod that performs exactly this rewrite, which is how the shape was confirmed offline.
2. **The config had to become ESM.** The plugin is ESM-only and the package has no `"type": "module"`, so Vite bundled the config as CJS and failed. Renamed to **`vitest.e2e.config.mts`** (script updated to match) rather than making the whole package ESM, which would have affected every other config in it.
3. **`fetchMock` no longer exists.** Pool 0.18.8's `cloudflare:test` exports only `env` and `SELF` — the undici `MockAgent` was removed, though its *types* still ship, which is what made this look configurable rather than gone. Added `src/e2e-fetch-mock.ts`, a ~150-line stand-in for the slice the suite uses (`get`/`post` origin scoping, `intercept`, `reply` including undici's request-capturing callback form, `activate`, `assertNoPendingInterceptors`) built on `vi.stubGlobal` — which reaches the worker because the pool runs `main` in the same isolate as the tests. Interceptors are one-shot and consumed in registration order, matching undici, because the suite relies on that for its two sequential `/oauth/token` calls. Unmatched requests **throw** rather than escaping to the network.
4. **The per-IP auth rate limiter capped the suite at 10 requests.** `/signup` and `/signin` allow `AUTH_RATE_LIMIT_MAX = 10` per IP per 600s, and the in-memory counter lives in worker module scope, which the pool shares across the whole run. Every request arrived with no `CF-Connecting-IP`, so all 41 tests keyed to `'unknown'` and everything past the tenth got `429`. `withUniqueClientIp()` gives each request its own IP, isolating tests the way separate clients would be in production while still exercising the limiter.

Two suite bugs were also fixed, both cases of the test contradicting the code rather than a judgement call: the Stripe tests mocked `https://api.stripe.test`, **a host the worker never calls** (`src/stripe.ts` hardcodes `api.stripe.com`), and the config's price map had to cover every tier the suite requests (`growth` was missing).

**✅ All 4 remaining failures fixed 2026-07-29 — the suite is fully green: 44 tests passing, stable across repeated runs.** Fixing them to match the code turned up that only one was a simple stale assertion; the others were more interesting:

| Test | What was actually wrong |
|---|---|
| `POST /signin` | Genuinely stale — asserted `404 "not implemented"` though `/signin` has been Auth0 ROPC for some time. Replaced with four cases covering the real contract: `200` with `{jwt, email}`, `500`/`INTERNAL_ERROR` when Auth0 rejects, `400`/`MISSING_FIELDS`, `400`/`INVALID_EMAIL`. |
| Stripe missing session URL | Message drift only: asserted `"checkout"`, worker says `Stripe response missing session URL`. |
| `SUPABASE_ORG_MEMBERSHIP_FAILED` | **Not stale at all** — the worker's compensating **rollback** was unmocked, so the rollback's own failures replaced the original error and it degraded to `INTERNAL_ERROR`. Mocking the rollback made the original assertion pass unchanged. |
| unknown-pattern error | The test's premise was wrong: a `500` from `/oauth/token` **is** a known pattern, mapped to `AUTH0_TOKEN_EXCHANGE_FAILED`. Renamed and re-pointed at the specific code, since classifying it is the better behaviour. |

Two things worth keeping from that work. Rollback interceptors are registered `.optional()` — a small extension to the shim — because `auth0DeleteUser` swallows its own errors and can be reached more than once through nested catch layers, so pinning an exact call count would assert an implementation detail rather than the response contract. And one of my own edits briefly broke a passing test: the message fix matched **two** assertions, and the other Stripe error case legitimately returns `failed to create checkout session`. Caught by re-running rather than by inspection — worth remembering that a blanket string replace across a 777-line suite needs the second occurrence checked.

**Superseded — the original diagnosis, kept for context:** `vitest.e2e.config.ts` is a plain `defineConfig` with only an `include` glob — it never enables the Cloudflare workers pool, so the `cloudflare:test` import on line 10 of `src/index.e2e.test.ts` fails to resolve and the file collects **0 tests** (`Cannot find package 'cloudflare:test'`). Unrelated to any credential work: `@cloudflare/vitest-pool-workers@0.18.8` is installed and vitest 4.1.4 satisfies its `^4.1.0` peer range, and `git log` shows the config and the test arrived in the same commit (`9d7c484`), so the suite appears never to have executed. Fixing it means `defineWorkersConfig` from `@cloudflare/vitest-pool-workers/config` plus `poolOptions.workers` bindings for the fake hosts the suite mocks (`e2e.auth0.test`, `https://supabase.e2e.test`) — there is no working example elsewhere in the repo to copy, and the binding set has to be reconstructed from the test body, so it is a small piece of real work rather than a one-line change. Until then, treat `test:e2e` as documented-but-nonfunctional wherever `CLAUDE.md` lists it.

**Detector:** `npm run check:env-isolation` — compares credential hashes between the two configs, prints no secret material, exits non-zero while they are shared. ✅ **PASSES (exit 0) as of 2026-08-03** — 15 credentials distinct, both Stripe keys test-mode in dev / live in prd. A green run was the definition of done, and it is green. *(History: 10 of 10 before the 2026-07-29 work → 3 of 13 that day → ~~5 of 13 on 2026-07-31~~, which was itself understated — the true baseline was 7 of 15, since the detector carried a phantom row and a false-pass newline bug. The old "`AUTH0_DOMAIN` is not reachable by API, so 2 of 3 is the API floor" note is moot: the dev tenant was created in the Dashboard and the row is distinct.)* ⚠️ **A green run proves only what the list names.** Two rows are excluded from the count by design — one dead slot read by no code, one absent from both configs — and "nobody sets this name" is not evidence of isolation. Before trusting the result, confirm no live credential has moved to a slot the list does not name: that is exactly how `SUPABASE_PROVISIONING_KEY` went uncompared while `SUPABASE_SERVICE_ROLE_KEY` scored a phantom failure in its place.

**Update 2026-07-31 — the detector regressed 3 → 5, and separately it is measuring the wrong slot.** Live output:

| Row | dev | prd | Verdict |
|---|---|---|---|
| `SUPABASE_URL` | `d3f2f2c8` | `d3f2f2c8` | SHARED — longstanding, one project |
| `SUPABASE_SERVICE_ROLE_KEY` | `da39a3ee` | `da39a3ee` | **UNSET in both** — `da39a3ee` is the SHA-1 of the empty string |
| `SUPABASE_ANON_KEY` | `e5035497` | `e5035497` | SHARED — longstanding, one project |
| `AUTH0_DOMAIN` | `2231ca42` | `2231ca42` | SHARED — longstanding, one tenant |
| `SHARED_SECRET` | `0bd4961c` | `0bd4961c` | **SHARED — regression, see below** |

Three findings, in descending order of how much they matter:

1. **`SHARED_SECRET` is byte-identical across the two configs again** (len 44, sha `424bb5dee2ba`, confirmed independently of the detector). Row #7 below records rotating `dev`'s copy on 2026-07-29 and verifying the write by read-back, and the sequenced-target line records the resulting 7 → 6. That state has not held. **Do not re-close row #7 without establishing how it came back** — a rotation that silently reverts is a worse problem than one that was never done, and the two candidate causes (a `dev` slot re-copied from `prd`, or `prd` overwritten with `dev`'s new value) have opposite blast radii. The second would mean the production HMAC key changed, so check that the production `/send` path still verifies *before* touching either slot.

2. **The detector checks `SUPABASE_SERVICE_ROLE_KEY`, which exists in neither config.** Both hashes are `da39a3ee` — SHA-1 of empty — and the slot is genuinely absent (not empty-valued) from `dev` and `prd`. So this row is a **false failure**: it can never go green, and it inflates the count by one. Worse, it is checking the wrong name. CLAUDE.md already records that the canonical slot is **`SUPABASE_PROVISIONING_KEY`**; that slot holds a 41-char `sb_secret_` key, **byte-identical in both configs** (sha `cdb0a4bd18e4`), and the detector does not look at it.

3. ~~**[[CR01]]'s claim that `dev` holds no working RLS-bypassing Supabase credential is false today.**~~ **True through 2026-08-02, ✅ CLOSED 2026-08-03.** The finding was real and was the most consequential thing this page had gotten wrong: `dev`'s `SUPABASE_PROVISIONING_KEY` was byte-identical to prd's and returned **HTTP 200** against the production database, so `--config dev` yielded full read/write on production. The repoint fixed exactly this — `dev`'s provisioning key is now the **dev project's** key, **probed refused by production (401)** while reaching the dev DB (200). [[CR01]]'s claim is true again: no `dev` slot holds a working production-RLS-bypassing credential.

**Fixing the detector is a prerequisite for trusting the count**, and it is cheap: swap `SUPABASE_SERVICE_ROLE_KEY` for `SUPABASE_PROVISIONING_KEY` in `SECRETS` (`scripts/check-env-isolation.sh`), and treat an absent slot as its own verdict rather than folding it into the shared/distinct axis — "UNSET in both" currently reads as a failure to isolate when it may equally mean the credential moved. Note the swap will not reduce the count: the new row is shared too, so it fails for a real reason instead of a phantom one.

**Context (historical — describes the state through 2026-08-02; ✅ RESOLVED 2026-08-03, detector PASSES).** `--config dev` and `--config prd` *used to* resolve to the same Supabase project (`cfrbahzzklwrnmbtqojl`), the same Auth0 tenant, and the same `SHARED_SECRET`; anything run against the dev config read and wrote production state. Each of those is now a distinct dev-owned backend — see the Status line at the foot of this item. CLAUDE.md's old "E2E tests use `--config dev` (isolated from prod)" was false *then* and true *now*.

Facts established while investigating, several of which correct earlier notes in this file:

- **Stripe is not exposed — but this bullet was wrong about why. Corrected 2026-07-27 evening.** It read "`STRIPE_API_KEY` … is `sk_test_…` in both dev and prd". It is not. `prd` holds a **`pk_live_…` publishable key** and `dev` holds an `sk_test_…` secret key, and they belong to **two different Stripe accounts**. The conclusion survives — a publishable key is public by design, so there is no exposure — but the reasoning does not, and the real picture is worse: `STRIPE_SECRET_KEY` (the name the code actually reads) is empty everywhere, so **no Worker can make a server-side Stripe call at all**. See [[CR18]]. The bad reading came from `echo -n` inside POSIX `sh`, which emits the flag literally and shifted the prefix by three characters.
- ~~**The isolation detector covers no Stripe credential.** `SECRETS` in `scripts/check-env-isolation.sh` lists only the Supabase, Auth0, and `SHARED_SECRET` values. A green run says nothing about Stripe.~~ **Superseded 2026-07-28** — Stripe rows were added (the row count went 10 → 13) and Stripe is the only family that passes. Flagged here because the two statements sat 30 lines apart contradicting each other until 2026-08-02. The residual caveat still holds: passing means the two configs hold different key *types*, which is necessary and not sufficient — see the `pk_live_` lesson under [[CR18]].
- **The `stg` config is empty**, not a third environment — every credential above is unset in it. It is available to repurpose as the dev target.
- **Worker secrets do not come from Doppler.** `wrangler deploy` does not convert ambient env vars into Worker secrets; they are set per worker with `wrangler secret put`. So this item does not by itself mean the deployed workers are misconfigured — it means every *local* and *CI* process using the dev config touches production.
- **The `*-dev` workers have zero secrets bound** (verified via the Workers API) and were deployed that way deliberately. They cannot reach production data. Do not push the current dev values into them: that would create a second production-capable worker, not a dev environment. **One exception since 2026-07-27 evening:** `stripe-webhook-dev` holds `STRIPE_API_KEY` (sandbox `sk_test_`) and `STRIPE_WEBHOOK_SECRET` (test-mode signing secret). Both are sandbox-only and reach no production system, which is exactly why they were safe to bind — and it is still true that no Supabase or Auth0 credential may be pushed to a dev Worker until this item passes.
- **Corrected 2026-07-27 evening: the projects are not both paused.** This read "Both Supabase projects are `INACTIVE` (free-tier pause)". Per the Management API, `cfrbahzzklwrnmbtqojl` ("IntegrityStudio") is **`ACTIVE_HEALTHY`**; the `INACTIVE` one is `kvbcgfttukwciiwieezp` ("atx_movement"), an unrelated project. ~~The org has 2 projects, so a third may still require a plan change — that part of the decision blocking step 1 stands.~~ **Superseded 2026-07-29 and re-audited 2026-08-02:** `atx_movement` was deleted, so the org holds **1** project and the dev project is free. See *Blockers and cost*.
- **Read Doppler values with `doppler secrets get --plain`, never `doppler run`.** On 2026-07-27 a `doppler run --config prd` reported a value that `doppler secrets get --config prd --plain` contradicted, and Stripe's API confirmed the latter. `~/.doppler/fallback/` holds cached snapshots and `doppler.json` still sits at the repo root ([[CR01]]), so a silently-served stale snapshot is the likely mechanism. Fingerprint before acting: prefix + length + `shasum | cut -c1-12` reveals a mismatch without printing secret material. The detector script already uses the safe form, so its 10-of-10 result is trustworthy.

**Scope:**
1. ✅ **DONE 2026-08-03 — dev Supabase project created and repointed.** ~~Decide the Supabase boundary. Either a new project (may need a paid plan — the org already has 2) or a separate schema…~~ **No longer a decision, 2026-08-02** — the boundary question is settled and the project is free (see *Blockers and cost*). The separate-schema alternative is **rejected, not deferred**: it shares the service-role key, so it isolates no credential and cannot move `SUPABASE_URL`, `SUPABASE_ANON_KEY` or `SUPABASE_JWT_SECRET` — all three are per-project. Run `POST /v1/projects` with the `sbp_` token, then follow the corrected runbook below (**do not `db pull`**; `link` + `db push` the existing 10 migrations, then `PATCH …/config/auth` to enable the access-token hook, which `db push` will not do).
2. **Mint an M2M credential for the dev Auth0 tenant that already exists.** ~~Create the Auth0 dev tenant … not scriptable at any price … One Dashboard visit.~~ **Corrected 2026-08-02 — I rewrote this step as "create a tenant" while this item's own 2026-07-29 update, ~60 lines below, already recorded that a second tenant is live.** `dev-njjmghdzm23uy0p7.us.auth0.com` exists, resolves, and is referenced by nothing here (re-verified 2026-08-02: OIDC discovery 200; the production tenant `dev-68gg87ow4mg4kzyo` also 200). So the blocker is a **credential, not a creation**: authorize one M2M app for that tenant's Management API (`create:clients`, `create:connections`, `create:users`, matching `read:`/`update:`, plus `update:tenant_settings`), after which the connection + ROPC app + test user are scriptable exactly as rows #4–#6 were. **This also deletes the `realm` code-change blocker at no cost** — `default_directory` is per-tenant, so a dedicated dev tenant points it at its own connection and `sender-worker`'s plain `password` grant works unmodified. See the 2026-07-29 update for both. The `dev-users` connection + dev clients built inside the *production* tenant are the interim partial; **step 2 retires them.**

   ✅ **Done 2026-08-03 — detector 6 → 5, and every Auth0 row is now distinct.** The M2M was provisioned in the Dashboard (all-scopes grant — opposite posture from `integrity-dev-m2m`'s designed powerlessness, acceptable on a tenant with 0 production users) and landed in dev `AUTH0_CLI_*`. Built in tenant B via its Management API: resource server **`https://api.integritystudio.dev`** (⚠️ it did not exist, and both configs' `AUTH0_CLIENT_AUDIENCE` demand it — every ROPC login would have failed "Service not found"; no earlier note recorded this dependency), ROPC app `integrity-dev-ropc` (`1twZh1pJ…`, `password`+`password-realm`+`refresh_token`, enabled **only** on the pre-existing `Username-Password-Authentication` connection), test user `dev-test@integritystudio.ai`, and `default_directory` set — **proven by probe**: the plain `password` grant (exactly what `/signin` sends, production audience value) authenticates the dev user with no `AUTH0_REALM` code change, and a production email is refused. Doppler `dev` repointed: `AUTH0_DOMAIN`, `AUTH0_CLIENT_ID/SECRET`, `AUTH0_TEST_*`. **The interim is retired by deletion, not disablement**: `integrity-dev-ropc` (`7JhlHWEG…`), `integrity-dev-m2m` (`Yd9s7…`), and the `dev-users` connection are gone from the production tenant — identity-asserted by name before each delete. Two trap confirmations along the way: creating the tenant-B client **auto-enabled it on both connections including google-oauth2** (fixed immediately), and the production connection's client list came back **5**, not the "byte-for-byte original 7" verified 2026-07-29 — the two dev clients had been silently **re-enabled on the production connection** at some point since, so deletion (which cannot re-fire) ends that cycle where disablement kept losing it. 🔴 **Separate finding, resolved by the same deletion:** `integrity-dev-m2m` — designed with no grant, "verified powerless" — was found minting production-tenant tokens with **`read:users delete:users`** (caught by a control probe while hunting tenant-B credentials; grantor unknown, nothing in this file records it). Its credentials sat in Doppler `dev` until the same day. Production verified after all of it: `/signin` → 200 with an 855-char JWT.
3. ✅ **DONE 2026-08-03.** ~~Populate Doppler. Write the new values~~ into `dev` (or into the empty `stg` config, promoting it to the dev target). Re-run `npm run check:env-isolation` until it passes.
4. ✅ **DONE 2026-08-03 — and proven by a live dev signup (step 6).** Pushed with a pre-flight that asserts every value is dev-owned before anything uploads (domain == tenant B, URL == dev project, Stripe prefix == `sk_test_`): `sender-worker-dev` 9 secrets (Auth0 ×6 with `AUTH0_AUDIENCE` ← Doppler `AUTH0_CLIENT_AUDIENCE`, Supabase ×2 with `SUPABASE_SERVICE_ROLE_KEY` ← Doppler `SUPABASE_PROVISIONING_KEY` — the loop below is stale on both names — plus sandbox `STRIPE_SECRET_KEY`); `api-gateway-dev` 4; `stripe-webhook-dev` +2 alongside its sandbox pair. **Deliberately NOT pushed:** `SIGNING_KEYS`/`ACTIVE_KEY_ID`/`SHARED_SECRET` (dev `/send` must fail closed until a dev receiver exists — [[CR02]] item 5, [[CR29]]); `STRIPE_PLAN_TO_PRICE_JSON` (dev slot empty — tier-checkout flows fail in dev until populated); **`contact-form-dev` got nothing** because step 5 below was unmet *(armed later the same day once step 5 landed — see step 5)*. **Step 6 executed:** `POST /signup` on `sender-worker-dev` → **201** with a JWT issued by `dev-njjmghdzm23uy0p7`; production counts unchanged (users 9, orgs 7 before and after), dev went 0/0 → **1/1** with the signup row carrying a dev-tenant `auth0_id` and default tier — so the access-token hook and triggers fired on the replayed schema. ~~Push the dev secrets to the `*-dev` workers — only after step 3 passes, never before:~~
   ```bash
   for s in SUPABASE_URL SUPABASE_SERVICE_ROLE_KEY AUTH0_DOMAIN AUTH0_CLIENT_ID AUTH0_CLIENT_SECRET AUTH0_CLI_ID AUTH0_CLI_SECRET AUTH0_AUDIENCE SHARED_SECRET; do
     doppler secrets get "$s" --project integrity-studio --config dev --plain \
       | npx wrangler secret put "$s" --env dev
   done
   ```
5. ✅ **DONE 2026-08-03 — and `contact-form-dev` is armed and proven.** `[env.dev.vars]` now sends to the developer (`alyshialedlie@gmail.com`) from `contact-dev@integritystudio.ai` (Resend verifies *domains*, not localparts, so the distinct localpart marks dev traffic without breaking sending). Dev's Doppler `RESEND_API_KEY` turned out to be **distinct but dead** (401 — the CR18 lesson again: distinctness ≠ validity); replaced with a freshly minted **sending-scoped** key (`sending_access`, independently revocable, created via the Resend API with prd's key). `CSRF_SECRET` generated fresh for dev. Worker redeployed with the new vars, armed with both secrets, and proven end-to-end: CSRF token issued → submission → **200 + submissionId**, mail dispatched to the dev recipient. ~~Change `contact-form`'s dev recipient before giving dev a `RESEND_API_KEY`.~~ `[env.dev.vars]` currently carries the production addresses — `RECIPIENT_EMAIL = hello@integritystudio.ai`, `SENDER_EMAIL = contact@integritystudio.ai` — so the moment dev holds a Resend key, dev test submissions land in the real business inbox. Harmless today only because the key is absent and the worker fails closed without `CSRF_SECRET`.
6. ✅ **DONE 2026-08-03** — see step 4: 201, dev rows created, production row counts byte-identical before and after.
7. ⚙️ **Landing-repo half DONE 2026-08-03; toolkit half blocked on the dev receiver.** The Playwright suite's `contact-worker.spec.ts` (16 contract tests) now defaults to `integrity-studio-contact-dev` — it had been consuming the **production** worker's per-IP rate-limit and idempotency KV on every CI run, which is exactly why its assertions tolerate 429. Verified: 16/16 pass against the armed dev worker. `BASE_URL` site-smoke stays on `https://integritystudio.ai` **by design** — its purpose is production-deployment health. Also seeded the dev DB to reference-data parity the same day: plans `{enterprise, growth, starter}` (dev's migration-seeded `free` removed to match prod; **live-mode `stripe_price_id`s nulled** — a live price id is meaningless against the sandbox account, and one had ridden into dev via migration `20260731020000`), all 4 roles mirrored verbatim with their permission arrays. The toolkit e2e suite (`services/e2e/`) still cannot come back until [[CR02]] item 5's dev receiver exists.
8. **Scope the dev deploy token** (added 2026-08-02; **premise corrected 2026-08-03**; free, independent of every other step).

   🔴 **The original framing was wrong and sent you to the wrong slot.** It read: "`deploy` and `deploy:prd` both authenticate with the same `CLOUDFLARE_WORKER_TOKEN` from Doppler `prd`, so only argument order stops a dev deploy reaching a production Worker." Three errors. **Wrong slot** — `wrangler` authenticates with `CLOUDFLARE_API_TOKEN`, not `CLOUDFLARE_WORKER_TOKEN`. **Wrong config** — all six `deploy` scripts are `doppler run --project integrity-studio --config dev -- wrangler deploy --env dev`, so the dev deploy already reads `dev`. **Wrong conclusion** — those two values are already distinct (40 chars each, sha `abb57cc474cb` in `dev` vs `25889310adec` in `prd`). `CLOUDFLARE_WORKER_TOKEN` *is* byte-identical across the configs (sha `1243e82a0ae8`), but **no code in this repo reads it**; its only readers are three `observability-toolkit` workflows, all correctly passing `--config prd`. This is the [[CR11]] `SUPABASE_SERVICE_ROLE_KEY` failure mode again — a doc auditing a name that is not the one in play.

   ✅ **What is actually true, measured 2026-08-03.** Dev's token is a distinct, revocable credential that is narrower than a global key (`GET /user/tokens` → `Unauthorized`) — but it is **not dev-scoped**: `GET /accounts/<id>/workers/scripts` with it returns **all 18 scripts in the account**, production `api-gateway`, `sender-worker`, `stripe-webhook`, `obtool-api` and `api-provisioning-receiver` included. `Edit` was not probed because the probe is a write. **Cloudflare scopes the Workers Scripts permission to the account, not to individual scripts** — there is no per-script resource selector — so an `Edit`-carrying token reaches every Worker in the account no matter how the token is described. This is therefore a **blast-radius** item, not an isolation one, and it cannot be closed to zero by a token: separate accounts with wrangler profiles pinned per directory (`account_id` in each config) is the only structural form. What a properly scoped token buys is product-level narrowing (no Zone/DNS/R2/D1) and an independently revocable credential.

   **Steps to mint one.**
   1. Fix the target: the token must deploy `sender-worker-dev`, `api-gateway-dev`, `stripe-webhook-dev`, `integrity-studio-contact-dev`, `receiver-worker-dev` — all on account `b3868…` (identical in both configs; there is one account).
   2. Dashboard → **My Profile → API Tokens → Create Token → Custom token** (user token). An account-owned token works too and is created under **Manage Account → API Tokens**; it carries a `cfat_` prefix, which changes how you verify it in step 5.
   3. Permissions — the minimum that lets `wrangler deploy --env dev` succeed for all six packages:
      - **Account → Workers Scripts → Edit** (mandatory; also covers the Durable Object namespace on `api-gateway-dev` — DOs have no separate permission group)
      - **Account → Workers KV Storage → Edit** (`api-gateway-dev`, `sender-worker-dev`, `integrity-studio-contact-dev` all bind `RATE_LIMIT_KV`)
      - **Account → Account Settings → Read** (wrangler resolves the account with this)
      - **Account → Workers Tail → Read** only if `wrangler tail` is wanted
      - Deliberately **omit** Zone / DNS / Workers Routes — every `[env.dev]` sets `routes = []`, so a dev deploy needs no zone permission at all, and omitting it is what makes the token unable to repeat the CR13 route hijack. Omit R2 and D1; no dev Worker binds either.
   4. **Account Resources → Include → this account only. Zone Resources → none.** Optionally add a TTL and client-IP filter.
   5. Verify against the endpoint matching the token *type* — the wrong one reports a valid token as invalid: user tokens at `GET /client/v4/user/tokens/verify`, account-owned `cfat_` tokens at `GET /client/v4/accounts/<id>/tokens/verify` (which returns `1000 Invalid API Token` on the user endpoint). Expect `"status": "active"`.
   6. Store it in Doppler **`dev`** under **`CLOUDFLARE_API_TOKEN`** — the slot wrangler reads. Never write it to `prd`, and do not touch `CLOUDFLARE_WORKER_TOKEN`, which belongs to the toolkit's production deploys.
   7. Read it back with `doppler secrets get CLOUDFLARE_API_TOKEN --project integrity-studio --config dev --plain` (**not** `doppler run` — stale fallback cache) and fingerprint with length + `shasum | cut -c1-12`. Confirm it is neither the old dev value `abb57cc474cb` nor prd's `25889310adec`.
   8. Prove it end to end: `cd workers/sender-worker && npm run deploy` succeeds, and `npm run deploy:prd` still resolves `prd`'s token.
   9. **Revoke the superseded dev token in the Dashboard.** Rotating the Doppler value does not revoke anything — the old token stays live at Cloudflare until deleted, the same rotation-is-not-revocation trap as [[CR01]].

   Cross-referenced as [[CR02]] step 8, since it is that item's guarantee that is thinner than it looks.
9. ~~**Give dev its own Stripe sandbox**~~ ✅ **Already done when this step was written (verified 2026-08-03).** `npm run check:env-isolation` scores both Stripe rows `ok (test in dev, live in prd)` — `dev` holds `sk_test_` keys on the confirmed sandbox account `acct_1SN2eDBWbFuvm1I6`, `prd` holds `rk_live_` on `acct_1SN2e7AwEfePbhfk`. Stripe was the one credential family that was *never* shared. The rule to keep holding: **`dev` never receives a copy of a `*_live_` key**, restricted or not — the `rk_live_` in `prd` is correct least-privilege practice, which is exactly what makes copying it the tempting mistake.

**Status:** ✅ **Credential isolation achieved 2026-08-03 — `check:env-isolation` PASSES (exit 0).** `--config dev` no longer reaches production for Supabase or Auth0. Detector history: 5/13 (broken) → true baseline 7/15 → 6 (`SHARED_SECRET` re-rotated) → 5 (Auth0 dev tenant) → **0 real** (Supabase repointed to `tumhmtshahktumhqqamk`). The two non-passing rows are non-failures: `SUPABASE_SERVICE_ROLE_KEY` ABSENT (tripwire) and `SUPABASE_JWT_SECRET` a dead slot (removed from code 2026-07-31, 0 readers in either repo). Proven by probe: dev's provisioning key reads the dev DB (200) and is **refused by production (401)**, while prd's key still reaches prod (200). **Runbook steps 3–7 all completed 2026-08-03** — dev secrets pushed to `sender-worker-dev`/`api-gateway-dev`/`stripe-webhook-dev` (step 4) and proven by a live dev signup that left production untouched (step 6); `contact-form-dev` recipients fixed and armed (step 5); dev DB seeded to reference-data parity; Playwright `contact-worker` spec repointed to dev, 16/16 green (step 7). **What is left is exactly two things, and neither is isolation:** step 8 — a dev-scoped Cloudflare deploy token (Dashboard-only, so it is on the owner) — and restoring the `observability-toolkit` e2e suite, which is blocked one more hop on [[CR02]] item 5's dev receiver (itself now unblocked by the dev Supabase project). ~~Open — blocked on **manual provisioning, not spend**; see *Blockers and cost* at the top of this item for the audited figures.~~ ~~blocked on two owner decisions: whether to pay for a third Supabase project (step 1) and creating the Auth0 dev tenant (step 2), neither of which is scriptable with the credentials available.~~ **Superseded 2026-08-02** — both halves were stale, and one of them (`POST /v1/projects` is scriptable) was already contradicted by this item's own 2026-07-28 update. Everything downstream (steps 3–9) is mechanical and the runbook above is complete. The detector and the documentation corrections landed 2026-07-27.

**Consumers of this item (✅ both now unblocked — step 1 landed 2026-08-03):** [[CR02]] item 5 (the dev receiver) was the reason step 1 was P1 — a dev receiver against the *shared* project would have run `ensureTeamOrg` / `addOrgMember` / `grantDashboardAccess` and minted real keys in production. With the repoint done, a dev receiver would write the **dev** project; item 5 is unblocked, gated now only on the sender/receiver co-deploy sequencing. Separately, the `observability-toolkit` e2e suite (removed from CI 2026-07-31 because `--config dev` pointed at the **production** receiver) can return once that dev receiver exists — landing-repo step 7 (contact e2e on dev) is already done.

**Update 2026-07-28 — the detector now covers Stripe, and Stripe is the only family that passes (10/13 failing).**

Two findings from probing what the Management APIs can actually do:

- **`POST /v1/projects` is available to the `sbp_` token**, so step 1 is scriptable after all. ~~What it is blocked on is the *spend decision*, not tooling.~~ **Superseded 2026-08-02 — there is no spend decision either** (see *Blockers and cost*); step 1 is blocked on nobody having run the call. ~~The account currently holds one active project (`IntegrityStudio`) plus `atx_movement`, which is `INACTIVE` and unrelated.~~ **Superseded 2026-07-29:** `atx_movement` was deleted, so the org holds only `IntegrityStudio` and a free-tier slot is available — see the 2026-07-29 update below.
- **There is a tempting false fix, and the detector now refuses it.** `POST /v1/projects/{ref}/api-keys` mints an `sb_secret_` key carrying `secret_jwt_template {role: service_role}`. Pointing `dev` at a freshly minted key would make `SUPABASE_SERVICE_ROLE_KEY` differ, so the hash table would print `ok (distinct)` — while the key still bypasses RLS on the **production** database. It would also only reach 2 of the 4 Supabase rows: `SUPABASE_URL` derives from the project ref and `SUPABASE_JWT_SECRET` is one-per-project, so neither can differ within a single project. Net effect would be trading a loud accurate failure for a quiet misleading one. `scripts/check-env-isolation.sh` now detects the shared `SUPABASE_URL` and says so explicitly (commit `0bc8f3a`).

The general lesson is the same one [[CR18]] taught with a `pk_live_` key: **distinctness is necessary but never sufficient.** A credential can differ from production's and still authenticate against production.

**Update 2026-07-29 — now 7 of 13 failing, and the API floor is 1.** [[CR01]]'s slot cleanup cleared three rows (`SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_JWT_SECRET`, `AUTH0_CLI_SECRET` all now "ok (distinct)"). `SUPABASE_ANON_KEY` newly reads SHARED and that is fine — both configs hold the same *publishable* key, public by design. The remaining seven, with what each would actually take, verified by probing each provider's API:

| # | Row | Fixable by API? | Honest fix, or cosmetic? |
|---|---|---|---|
| 1 | `SUPABASE_URL` | ✅ `POST /v1/projects` | **Honest** — a genuinely separate database |
| 2 | `SUPABASE_ANON_KEY` | ✅ follows from #1 | Honest (harmless even today) |
| 3 | `AUTH0_DOMAIN` | ❌ **impossible** | — Dashboard only |
| 4 | `AUTH0_CLIENT_ID` | ✅ **DONE 2026-07-29** | Honest — dev client is enabled only on the `dev-users` connection |
| 5 | `AUTH0_CLIENT_SECRET` | ✅ **DONE 2026-07-29** | Same |
| 6 | `AUTH0_CLI_ID` | ✅ **DONE 2026-07-29** | Honest — the dev M2M was created with **no** Management grant at all |
| 7 | `SHARED_SECRET` | 🔴 **REGRESSED** — done 2026-07-29, shared again by 2026-07-31 | ~~**Honest** — dev no longer holds the production signing key~~ **Shared again** (byte-identical, sha `424bb5dee2ba`). Precisely: not the *live* signing key — production signs with `v2` from `SIGNING_KEYS`, which `dev` does not have — but the production receiver **still accepts `SHARED_SECRET` when `x-key-id` is omitted** (proven, 200, with controls). So `dev` can still forge production provisioning events. **Re-rotating `dev` is safe, and un-shares this row, but does not close the downgrade path** — that is [[CR29]], whose fix is written as of 2026-08-02 and **not deployed**, so the forgery capability described here is unchanged in production |

- **Auth0 tenant creation is not available at any price through the API.** The `AUTH0_CLI_*` M2M token carries 251 scopes but **not** `create:tenants`, and no such endpoint exists — `GET /api/v2/tenants` → 401, while `/api/v2/tenants/settings` → 200 for the *current* tenant only. So row #3 is a hard Dashboard action, and it is the one that makes rows #4–#6 real rather than decorative. **API floor: 1 remaining failure.**
- **Rows #4–#6 — ✅ done 2026-07-29, taking the detector to 3 of 13 that day** (and they held through every later measurement; the detector now **passes**, 2026-08-03). A separate user store plus dev-only clients, all via the Management API — note the interim built here was later **deleted** in favour of the real dev tenant `dev-njjmghdzm23uy0p7`:
  - **`dev-users` connection** (`con_yg0iM5f7cEKSUA35`, strategy `auth0`, realm `dev-users`) — the tenant previously had exactly one database connection, `Username-Password-Authentication` (`con_xy9TgMMEaC9xzdvv`), holding **all 95 users**.
  - **`integrity-dev-ropc`** (`7JhlHWEGEYPd6QrOwNhG8TFN1O8OBkDX`) — `regular_web`, grants `password` + `password-realm` + `refresh_token`, enabled **only** on `dev-users`. Now `dev AUTH0_CLIENT_ID` / `AUTH0_CLIENT_SECRET`.
  - **`integrity-dev-m2m`** (`Yd9s7UvBsUljQQlIadhcKEaInB4JdQl0`) — `non_interactive`, `client_credentials` only, and deliberately created with **no `client_grant` at all**. Verified powerless: a `client_credentials` request for the Management API audience returns `access_denied`. That sidesteps row #6's caveat entirely — rather than granting narrow-but-tenant-wide scopes, the dev M2M can do *nothing*, so leaked dev credentials are inert. It is correspondingly non-functional; granting it scopes later is a one-call decision that trades inertness for reach.
  - **Dev test user** `dev-test@integritystudio.ai` (`auth0|6a6a64c930bc0ef7cd4def91`) created in `dev-users`, with `dev AUTH0_TEST_EMAIL` / `AUTH0_TEST_PASSWORD` pointing at it, so the isolation claim stays re-testable.
- 🔴 **Trap worth knowing: creating a client silently widens production access.** Auth0 auto-enables newly created clients on existing connections — **originally attributed here to `is_domain_connection: true`, which is wrong; see [[CR25]]**, where the same two clients turned out to be auto-enabled on the Google connection too, and that one has the flag `false`. Both new clients were therefore added to the **production** connection on creation — its client list went from 7 to 9 without any request from us, which would have let the "dev" client authenticate all 95 production users and made the whole exercise cosmetic. Fixed with `PATCH /api/v2/connections/{prod}/clients` and `[{client_id, status:false}]` (→ 204), then verified the list is byte-for-byte the original 7. **Any future client creation in this tenant must re-check the production connection's client list afterwards.** Note also that `enabled_clients` reads as `None` on `GET /api/v2/connections/{id}` in this tenant — the authoritative view is `GET /api/v2/connections/{id}/clients`.
- **Isolation proven by probe, not by configuration reading** — realm-scoped ROPC, all four directions: dev client → dev user **AUTHENTICATED**; dev client → production user **REFUSED**; production client → production user **AUTHENTICATED** (unaffected); production client → dev user **REFUSED**. The plain `password` grant was checked separately and also refuses the dev client against production users. Production re-verified end-to-end afterwards: `/signin` → 200 + JWT → HMAC-signed `/send` → `ok:true` with real user and org data, `api-gateway` and receiver healthy, and all four `prd` Auth0 fingerprints byte-identical before and after.
- ✅ **`npm run test:live` re-pointed at `--config prd` (2026-07-29) — 9 passed, 3 skipped.** It exchanges `AUTH0_CLIENT_ID`/`AUTH0_CLIENT_SECRET` for a **Management API** token, and the dev slots now hold `integrity-dev-ropc`, which has no `client_credentials` grant, so under `--config dev` it returned `403 unauthorized_client` and died in `beforeAll`. That refusal is the isolation posture working, not a regression — a dev credential should not hold admin power over the tenant with all 96 production users — so the suite was moved to the tenant it actually exercises rather than the grant being restored.
  - 🔴 **A destructive trap was found and defused in the process.** The suite's lifecycle **deletes** any existing user matching `AUTH0_TEST_EMAIL` in `beforeAll`, creates a fresh one, then deletes it again in `afterAll`. Doppler `prd` sets that to **`test@integritystudio.ai`** — a real account with two organization memberships and a Supabase `users` row keyed to its Auth0 `sub`. Running the suite against `prd` as-is would have deleted that account outright and orphaned the Supabase rows against a dead `sub`, with no automatic way back: re-signup mints a *new* `sub` and a *new* org rather than restoring the link. The suite predates the dev/prd distinction, so back when the two configs were identical this was invisible. `vitest.live.config.ts` now overrides `AUTH0_TEST_EMAIL` to the disposable **`auth0-live-suite@integritystudio.ai`**, keeping the delete-create-delete cycle self-contained. **Verified after the run:** `test@integritystudio.ai` still exists, the disposable identity was cleaned up (0 users remain), and live `/signin` → `/send` still returns `ok:true` with both organizations.
  - The 3 skipped tests are the `AUTHO_ACCESS_TOKEN_API_KEY` block, now `describe.skipIf` on an empty slot. That slot was cleared deliberately because it held a management token **expired 241 days** and issued by a *different* tenant; the suite fetches a fresh token in `beforeAll` regardless, so nothing there is load-bearing. The assertions still run if anyone repopulates it.
  - Worth remembering what this exposed: production's `My App` carries `client_credentials` **and** Management API authorisation largely so this suite can mint admin tokens — see [[CR25]] item 8.
- 🔴 **Blocker for making the dev environment *functional* (a code change, not a config one).** `sender-worker` signs in with the plain `password` grant (`src/supabase.ts:183`), which Auth0 resolves against the tenant's **`default_directory`** — currently `Username-Password-Authentication`. That setting is tenant-wide, so it cannot differ between configs, and the dev client is not enabled on that connection. Consequence: the dev credentials authenticate **nothing** through the current code path (confirmed — dev client + plain `password` refuses even the dev user). Harmless today, because the `*-dev` Workers hold no secrets at all, but before [[CR11]] step 4 pushes secrets to them, `/signin` must switch to `http://auth0.com/oauth/grant-type/password-realm` with the realm supplied by env (e.g. `AUTH0_REALM`, defaulting to the production connection). Until then, treat dev Auth0 as leak-surface reduction only, not a working environment.
- **Row #7 — done 2026-07-29 (detector 7 → 6 that day), 🔴 since regressed — see the reopen note at the end of this bullet.** A fresh `openssl rand -base64 32` was written to `dev SHARED_SECRET` (write confirmed by read-back; `prd` verified byte-identical before and after). Preconditions checked rather than assumed: the two configs held the *same* value beforehand, and `wrangler secret list --name sender-worker-dev` reports **zero** secrets bound, so no deployed Worker consumed the old dev value and no deploy was needed. Production HMAC path re-verified end-to-end afterwards — `/signin` → 200 with an 855-char JWT → HMAC-signed `/send` (`sign_in`) → `{"ok":true}` with real user and organization data, proving the sender still signs and the production receiver still verifies. The only behavioural change is that a local `wrangler dev` sender now signs with a key the production receiver rejects, which is precisely the posture this item wants.

  🔴 **Reopened 2026-07-31 — the two configs hold the same value again.** The detector reports `SHARED WITH PRODUCTION` and a direct fingerprint agrees (len 44, sha `424bb5dee2ba`, identical in `dev` and `prd`). Nothing in this file records a deliberate revert. Note what the 2026-07-29 verification did and did not establish: the write was confirmed by read-back *at the time*, which proves the value was set, not that it stayed set — no detector run is scheduled, so the window between the rotation and this measurement is unattributed. **Diagnose before re-rotating.** The two ways this could have happened are not equivalent: if `dev` was re-copied from `prd`, production is untouched and re-rotating `dev` is safe; if `prd` was overwritten with the new `dev` value, then the production signing key changed and the Worker binding (written separately, and write-only) may now disagree with Doppler. Distinguish them by testing the live `/send` path first — a `200 ok:true` means production still verifies against whatever its binding holds, which rules out the dangerous case. **One cause is already ruled out:** the W05 rotation procedure in `docs/provisioning-environment-setup.md` writes the new value to Doppler `prd` only, so following the runbook does not re-share the secret. The 2026-07-29 rotation logged under [[CR01]] step 3 *did* store it in `prd`+`dev` — re-running that ad-hoc form, rather than the runbook, would reproduce exactly this state, which makes it the first thing to ask about.

  ✅ **Diagnosed 2026-07-31 — `prd` was NOT overwritten, and the severity is different from what the paragraph above assumed (in both directions).** Four measurements:

  1. **Production `/send` works end to end.** `POST /signin` as `test@integritystudio.ai` → 200 with an 855-char JWT → `POST /send` (`sign_in`) → `200 {"ok":true}` with real user and organization data.
  2. **But that result says nothing about `SHARED_SECRET`, which is the trap in the instruction above.** Production `sender-worker` has **both** `ACTIVE_KEY_ID` (`v2`) and `SIGNING_KEYS` bound, and `resolveOutboundSigningKey` (`sender-worker/src/utils.ts`) prefers the rotated key whenever both are present, sending `x-key-id: v2`. So `SHARED_SECRET` is the **fallback**, not the live signing key, and a green `/send` exercises `v2` only. **A successful `/send` is not a test of `SHARED_SECRET`** — anyone re-running this diagnostic should skip straight to point 3.
  3. **The decisive test: the `SHARED_SECRET` fallback is live on the production receiver, and Doppler `prd`'s value is the bound one.** Signing `POST /inbox` directly with `prd`'s `SHARED_SECRET` and **omitting `x-key-id`** returns **`200 {"ok":true}`**. Run with both controls so a 401 could not be mistaken for a bad signature implementation: positive control (`v2` key + `x-key-id: v2`) → 200; negative control (garbage secret, no `x-key-id`) → `401 invalid signature`. **Conclusion: `prd` was not overwritten with `dev`'s value — `dev` was re-copied from `prd`. Re-rotating `dev`'s copy is safe and cannot affect production.**
  4. **`dev` holds `SHARED_SECRET` and nothing else that production accepts.** `SIGNING_KEYS` and `ACTIVE_KEY_ID` are **absent from `dev`** (present only in `prd`), so the `v2` key is genuinely `prd`-only.

  🔴 **The finding that matters is not the shared value — it is that `SIGNING_KEYS` rotation buys nothing.** Rotating production to `v2` gave `prd` a key `dev` does not have, which is a real improvement, and the legacy fallback nullifies it: **omitting `x-key-id` selects `SHARED_SECRET`, which the production receiver still accepts.** `resolveSigningKey` closes the obvious hole — `x-key-id: ""` is treated as an explicit miss rather than a fallback — but an *absent* header is still a silent downgrade to the legacy key. So the `dev` config can forge provisioning events the production receiver accepts, and re-rotating `dev`'s `SHARED_SECRET` only papers over that until the next config copy.

  **So the fix is not the one this row has been assuming.** Re-rotating `dev` treats the symptom; the durable fix is to **stop the production receiver accepting `SHARED_SECRET` at all** — require `x-key-id` and resolve solely through `SIGNING_KEYS`, then unbind `SHARED_SECRET` there. That closes the downgrade path permanently instead of once per copy. ⚠️ **Written in code 2026-08-02 ([[CR29]] step 2) and not deployed** — so every sentence above is still true of *production*. This row does not improve until the receiver ships.

  📌 **Filed as [[CR29]], and the fix plan lives there, not here.** The reason it needed its own item: the defect is not the shared value, so it does not go away when this row is fixed. Even with `dev` fully isolated, removing a key from `SIGNING_KEYS` cannot revoke a credential that is not resolved through it — `SHARED_SECRET` has no key id and therefore no rotation handle. CR29 carries the ordered scope (caller audit → sender fail-closed → receiver requires the header → unbind), the sender-side mirror hazard, and the cross-repo caveats. **This row's own remaining action is unchanged and still worth doing:** re-rotate `dev`'s `SHARED_SECRET` to un-share it, now known safe — but as isolation hygiene, not as a fix for the downgrade path.

  ⚠️ **Method note, because it cost a full round of probes:** the first attempt used Python `urllib` and got `403 Cloudflare 1010` on **all three** probes, including the positive control, making them look identical and the result inconclusive. That is the exact `workers.dev`-blocks-`Python-urllib` trap [[CR14]] records. Probe `workers.dev` with `curl`, and always include a positive control — without one, the blanket 403 is indistinguishable from a signature failure.
- **Supabase — a free-tier slot was freed on 2026-07-29, so this may no longer be a spend decision.** Org `Porter` (`khkebomlarrkcywpaduh`) is on the **free** plan and held two projects: `IntegrityStudio` (`ACTIVE_HEALTHY`) and `atx_movement` (`INACTIVE` since creation on 2025-10-26, unrelated to this repo, referenced by no code and no Doppler slot, and holding **no backups** — `backups: []`, `pitr_enabled: false`). `atx_movement` was **deleted at the owner's explicit direction** via `supabase projects delete kvbcgfttukwciiwieezp` (the CLI does support this; `supabase projects` exposes `list`, `create`, `api-keys`, `delete`). The org now holds **1 project**, so a dev project should fit within the free plan. Verified immediately after the deletion: the surviving project answers PostgREST `200`, `api-gateway` reports `{"database":"healthy","durableObjects":"healthy"}`, all 10 migrations are still listed, and all four Workers are healthy. There is still no dry-run for `POST /v1/projects`, so the quota question is settled only by attempting it. After creation: `supabase link --project-ref <new>` then `supabase db push` replays the 10 migrations, then the `dev` slots take the new URL and keys. Clears #1 and #2: **→ 4** (or, given rows #4–#7 are already done, **3 → 1**).

**Corrected runbook for the dev Supabase project (audited 2026-07-29).** An external plan proposed "second free project + `db pull` + `db push` + `.env.test`". The *architecture* is right and matches what this detector demands — a second project is the only thing that can make `SUPABASE_URL` and the per-project keys differ. Three of its concrete steps are wrong for this repo, and four repo-specific blockers were missing:

1. ❌ **Do not run `supabase db pull`.** The 10 files in `supabase/migrations/` are already the source of truth and `migration list` reports zero out of sync. `db pull` would synthesise an 11th migration containing the whole current schema, polluting a ledger that was only just repaired under [[CR17]] — where `migration repair --status applied` had recorded migrations that never executed. Correct sequence is `supabase link --project-ref <new>` then `supabase db push` of the existing 10.
2. ❌ **`SUPABASE_PUBLISHABLE_KEY` / `SUPABASE_SECRET_KEY` do not exist in this codebase** (zero references). The Workers read `SUPABASE_URL` (16 uses), `SUPABASE_SERVICE_ROLE_KEY` (16), `SUPABASE_JWT_SECRET` (3), `SUPABASE_JWT_ISSUER` (3).
3. ❌ **No `.env.test` layer.** Zero references in the repo; config flows Doppler → `wrangler secret put` for Workers and `--dart-define` for Flutter. A dotenv file would be a second, unsynchronised source of truth — and the `dev` Doppler config is exactly what `check:env-isolation` reads. Put the new values there.
4. 🔴 **The custom access-token hook is Auth *config*, not schema — `db push` will silently not enable it.** Migration `20260326000000` creates `public.custom_access_token_hook(jsonb)` and grants execute to Supabase Auth, but what makes it *fire* is project config: `hook_custom_access_token_enabled: true` and `hook_custom_access_token_uri: "pg-functions://postgres/public/custom_access_token_hook"` (both confirmed set on production). On a fresh project the function will exist and never run, so dev JWTs would lack the custom claims while looking healthy — the worst kind of drift. Fix with `PATCH /v1/projects/{ref}/config/auth` after the push.
5. ✅ **RESOLVED IN CODE 2026-07-29 — the verifier now supports JWKS/ES256.** The problem was real: production's signing keys are HS256 `previously_used` + **ES256 `in_use`**, so the project already issues asymmetric tokens, while `verifyJwt` only did HS256 against a shared secret — meaning a new dev project (ES256 by default, no legacy secret) could not have exercised JWT verification at all, and production HS256 verification is on borrowed time. **`workers/lib/auth.ts` now verifies ES256 and RS256 against the project's published key set**, keeping HS256 as a fallback so tokens minted before the migration still verify until they expire. Details worth knowing:
   - **No new secret or config.** The JWKS URL is derived from `SUPABASE_URL` (`supabaseJwtKey()` → `<url>/auth/v1/.well-known/jwks.json`), which every route's options object already carried. Each environment therefore verifies against its own project automatically — a dev project needs nothing bound beyond the URL it already has.
   - **Algorithm confusion is closed by construction.** The header's `alg` selects which *path* runs but never which key material is used, so an `HS256` token can only ever be checked against a configured HMAC secret — a JWKS public key can never be replayed as a shared secret. `alg: none` and any algorithm outside the `{ES256, RS256, HS256}` allowlist are rejected before verification.
   - **Key rotation and failure modes.** Key sets are cached for 10 minutes, with an unrecognised `kid` triggering at most one refetch per 30-second cooldown, so rotation is picked up promptly without letting forged kids drive unbounded upstream fetches. Fetch failures fail closed, but a still-valid cached key is preserved rather than discarded, so a transient blip does not 401 every request.
   - **Verified:** 17 new unit tests (locally generated P-256 key pair — no network), plus a live check that the real project's published key (`kid b91503ee-…`, ES256) imports under exactly these WebCrypto parameters and **rejects a token forged with a different key**. Full sweep at the time: **1,059 worker tests passing**, zero TypeScript errors. (The suite is **1,063** as of 2026-07-30; the figure here is the count observed when this work landed, not a contradiction.)
   - ✅ **The JWT secret is now optional throughout (2026-07-29).** `BaseRouteOptionsSchema.jwtSecret` and `EnvSchema.SUPABASE_JWT_SECRET` are `.optional()`, and the same field was loosened in the `Env` interfaces of `api-gateway` and `bootstrap-worker` plus the five route option types and `PreVerifyTokenOptions` — without that chain, TypeScript would still have demanded the field at every call site and nothing would actually have been loosened. **`supabaseUrl` / `SUPABASE_URL` is now the field verification depends on**, since the JWKS URL derives from it; the schema tests were inverted to assert exactly that (missing secret parses, missing URL does not). An ES256-only project therefore needs *no* JWT secret bound at all.
   - ✅ **Deployed on `api-gateway` (2026-07-30), still pending on `bootstrap-worker`.** The `api-gateway` `deploy:prd` shipped this along with four months of other changes; the deployed bundle contains `jwks.json`, `ES256`, and `RS256`, and `/v1/me` answers `401 Invalid JWT format` to a malformed bearer. `bootstrap-worker` has **no production deployment at all**, so there is nothing there to update — the verifier reaches it only if that Worker is ever stood up ([[CR14]] records the same fact from the preview-URL angle).
6. 🔴 **Free projects pause after ~7 days of inactivity** — precisely why `atx_movement` was `INACTIVE`. A dev project used by CI will pause between runs and fail them intermittently. Budget a keep-alive or accept unpause latency.
7. ⚠️ **Re-verify RLS on the new project with the catalog query, not a status code** — PostgREST exposes every `public` table, and RLS denial returns `200 []`, not an error. The query is at the top of `CLAUDE.md`.
8. ⚠️ **This gets the detector to 1, not 0**, and does not make dev a real environment on its own: `/signup` creates the **Auth0** user before the Supabase rows, and `AUTH0_DOMAIN` remains shared. Seeding is also on you — a fresh project has zero orgs and users, so `scripts/full-reconciliation.ts` and any data-dependent test needs seeds.
9. The plan's third tier, local Supabase, is probably unnecessary scope: it needs Docker, while this repo's fast tests are vitest with mocked outbound calls and `test:e2e` runs workerd with mocks.

**Two unrelated oddities surfaced while auditing production's Auth config.** The first is fixed:

- ✅ **`site_url` pointed at another product and is now corrected (2026-07-29).** It read **`https://aleph-analytics.app/`**, so any Supabase-Auth confirmation or recovery link would have sent the recipient to a different product's site. Now `https://integritystudio.dev/` (verified live — 200, served from GitHub Pages). **`uri_allow_list` had the same stale domain** (`http://localhost:3000/**,https://aleph-analytics.app/**`) and was updated in the same call to `http://localhost:3000/**,https://integritystudio.dev/**,https://www.integritystudio.dev/**` — changing `site_url` alone would have left every explicit `redirect_to` rejected, since Supabase validates redirects against that list. No `aleph-analytics` reference remains in the auth config. Verified afterwards: PostgREST 200, JWKS still publishes its key, `api-gateway` healthy, `/signin` 200 + JWT, `/send` `ok:true`. Two leftovers worth a decision: `localhost:3000` is this other product's dev port — this repo serves Flutter on **8080** — and the apex/`www` split assumes both stay on GitHub Pages while the main site runs on `integritystudio.**ai**` behind Cloudflare, so confirm which host should own auth redirects.
- ⚠️ **`disable_signup` is `false`**, so Supabase Auth self-signup is open on the production project even though provisioning goes through Auth0.

**Sequenced target:** ~~#7 gets 7→6~~ and ~~the Auth0 dev connection + dev clients get 6→3~~ — both done 2026-07-29, reaching 3 of 13 that day. ⚠️ **Superseded — the detector PASSES as of 2026-08-03, so this sequencing is closed.** *(Interim state, 2026-07-31: 5 of 13 — #7 had regressed and the `SUPABASE_SERVICE_ROLE_KEY` row was a phantom failure against a deleted slot.)* The Auth0 half of this held throughout. What remains: a dev Supabase project takes 3→1 (~~spend/quota decision~~ **free — corrected 2026-08-02, see *Blockers and cost*; the only unknown left is that `POST /v1/projects` has no dry-run, so the quota is confirmed by attempting it**), and the final row is ~~one Dashboard visit to create a second Auth0 tenant~~ ~~one Dashboard visit to mint an M2M credential for the second tenant that already exists~~ ✅ **done 2026-08-03 — `AUTH0_DOMAIN` is distinct and the dev-tenant build-out is complete (see scope step 2)** (`dev-njjmghdzm23uy0p7`, live — corrected 2026-08-02; this line had contradicted the 2026-07-29 update above since the day that update was written) — after which the connection/client work above should be redone inside it, and the `dev-users` connection in the production tenant retired. Neither remaining row is gated on money.

**Not applicable to this item: Auth0 Cross App Access (XAA).** Reviewed 2026-07-29 (`/docs/ai-agents-mcp/cross-app-access/*`). XAA lets a *Requesting App* exchange an enterprise IdP's identity assertion (ID-JAG, via `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer`) for an access token to a *Resource App*'s API — an agent-to-SaaS authorization feature, Early Access, gated to Enterprise/B2B Pro/B2B Essential plans or a Free-tenant trial. **It creates no tenants, so it cannot clear `AUTH0_DOMAIN`, and it is unrelated to the ROPC path `/signin` uses.** Tenant facts checked against its setup steps:

- **Step 1 is already satisfied** — the custom API `https://api.integritystudio.dev` exists (`69c4e28bf801eab9e683c85a`, RS256) but carries only **3 scopes**, which is worth knowing for [[CR12]]'s API-key work independently of XAA.
- **The blocker is the IdP side: there are no enterprise connections.** The tenant has 2 database connections plus one `google-oauth2`, and Google is a *social* connection, not an enterprise one. XAA is documented as a feature of Enterprise Connections, so there is nothing for it to attach to without first federating with an enterprise IdP (e.g. an Okta test tenant).
- **Worth keeping from those docs regardless:** *API Access Policies for Applications* is the right mechanism for controlling which applications may request which scopes on our own API — the per-client scoping that Management API `client_grant`s cannot express, which is exactly why the dev M2M above was given no grant at all.

XAA becomes interesting only as a **product** decision — if enterprise customers' AI agents should call `api-gateway` on their behalf — not as infrastructure for dev/prod isolation.

**Also not applicable: the My Account API** (`https://{domain}/me/`, reviewed 2026-07-29). It is **user-scoped and cannot be reached by Client Credentials at all**, and it manages no tenants, connections, or applications — so it cannot clear `AUTH0_DOMAIN` either. It also cannot narrow the over-privileged `AUTH0_MANAGER` M2M, because the single thing `sender-worker` uses the Management API for is `POST /api/v2/users` during `/signup` (`src/types.ts:107`), i.e. creating a user who does not exist yet and therefore has no token to present. The API **is already enabled in this tenant** (`69c974a13a59f8cdb089c0b9`, 8 scopes, all `me:connected_accounts` / `me:authentication_methods` / `me:factors`), and it is the right tool if the dashboard ever offers self-service passkey, MFA, or linked-account management — its value then is that the frontend needs *no* Management API power to do it. It does not reduce today's surface.

**The structural conclusion, to stop re-litigating this:** no Auth0 API creates tenants. `create:tenants` is not a grantable scope, `GET /api/v2/tenants` is not a resource, and `/api/v2/tenants/settings` only ever addresses the tenant you are already authenticated against. A second tenant is a Dashboard action, and it is the **only** way `AUTH0_DOMAIN` goes green.

**Update 2026-07-29 — a second tenant already exists, so the blocker is a credential, not a creation.** `dev-njjmghdzm23uy0p7.us.auth0.com` is **live**: unauthenticated OIDC discovery and JWKS both return 200, and its issuer resolves. It surfaced as the issuer of the expired token that had been sitting in `AUTHO_ACCESS_TOKEN_API_KEY` (see [[CR01]] step 3). **Nothing in this project references it** — both Doppler configs set `AUTH0_DOMAIN=dev-68gg87ow4mg4kzyo.us.auth0.com`, which is the tenant named "Integrity Studio" holding all 95 users and every application the live Workers use.

So `AUTH0_DOMAIN` no longer needs a tenant *created* — it needs one **M2M credential** for the existing second tenant. With a client_id/secret authorized for that tenant's Management API (scopes `create:clients`, `create:connections`, `create:users`, plus the matching `read:`/`update:` and `update:tenant_settings`), the rest is scriptable exactly as rows #4–#6 were: create a database connection, a ROPC app, and a test user there, then repoint Doppler `dev`. That takes the detector to **2 of 13** and lets the `dev-users` connection be retired from the production tenant.

**It would also delete the code-change blocker above, at no cost.** `default_directory` is a *per-tenant* setting. In a dedicated dev tenant it can simply be set to that tenant's own database connection, so `sender-worker`'s plain `password` grant resolves correctly with **no `realm` parameter and no code change** — the conflict only exists because dev and production currently share one tenant whose `default_directory` must serve production. That makes the separate-tenant route strictly better than adding `AUTH0_REALM`, not merely equivalent.

⚠️ **Two cautions.** The tenant's **environment tag is not exposed through the Management API** — `GET /api/v2/tenants/settings` returns only `friendly_name`, `default_directory`, `flags`, `sandbox_version`, and locale/support fields — so a Development→Production change cannot be verified from here, only in the Dashboard. And if the goal was to promote the tenant that actually serves production traffic, that is **`dev-68gg87ow4mg4kzyo`**, not `dev-njjmghdzm23uy0p7`; re-tagging the unused tenant changes nothing about any live path (re-verified: `/signin` 200 + JWT, `/send` `ok:true`, four Workers healthy, detector unchanged at 3, production connection still exactly 7 clients).

**Independent hardening found while probing (not isolation, but real):** the M2M app `AUTH0_MANAGER` — which holds Management API power — also carries the `password`, `password-realm`, and `authorization_code` grants, so it can authenticate end users, not just act as a machine client. The ROPC app `My App` additionally carries `implicit` and `client_credentials`. Both are wider than their roles require and are tightenable with `PATCH /api/v2/clients/{id}` without touching any secret.

**🔴 Update 2026-08-03 — step 1 was executed and is BLOCKED on a defect this runbook did not know about. Filed as [[CR30]].** The dev Supabase project now exists (`tumhmtshahktumhqqamk`, `integritystudio-dev`, `us-east-1`, `ACTIVE_HEALTHY`, org `khkebomlarrkcywpaduh`), created at the free default instance size — org project count 1 → **2**, which is the documented free allowance, and no plan-upgrade prompt appeared. **`supabase db push` then failed**: `relation "public.users" does not exist`, at statement 18 of the first migration. The migrations create 13 tables but reference `public.users` and `public.api_keys` via foreign keys and **create neither** — so the ledger cannot rebuild the schema on a fresh project. Nothing was recorded as applied (`migration list` shows `remote: ""` for all 14 files), so the new project is **empty, not half-migrated**, and needs no cleanup. Runbook item 1 below ("`link` + `db push` the existing migrations") is therefore **wrong as written** and stays blocked until CR30 supplies a baseline. ⚠️ ~~The new project is idle, so it will **pause in ~7 days**~~ — ✅ covered by the keep-alive workflow (2026-08-03, see *Blockers and cost*), once this branch lands on `main`; until then today's replay activity holds the ~7-day clock. Doppler `dev` was deliberately **not** repointed; the new project's DB password is parked in the empty `stg` config.

---

<a id="cr30"></a>

### CR30: the migration ledger cannot rebuild the schema — `public.users` and `public.api_keys` are created by nothing

**Priority:** P1 | **Source:** executing [[CR11]] step 1, 2026-08-03 — found by running `db push` against a genuinely fresh project for the first time
**Estimated:** unknown until production's DDL for the two tables is read

**What was measured.** `supabase db push --db-url <fresh project>` fails at statement 18 of `20260320000000_phase1_consolidated.sql` with `relation "public.users" does not exist`. Extracting every table the ledger creates versus every table it references by foreign key:

- **Creates (13):** `audit_log`, `auth_user_links`, `billing_event_log`, `entitlements`, `organization_memberships`, `organizations`, `plans`, `provisioning_jobs`, `subscriptions`, `usage_buckets_daily`, `usage_events`, `webhook_dead_letters`, `webhook_events_log`
- **References but never creates:** **`public.users`**, **`public.api_keys`** (`auth.users` is Supabase's built-in and is fine)

**Why this went unseen for months, and why "zero out of sync" was not the reassurance it looked like.** [[CR17]] repaired the ledger and CI now guards drift with `scripts/check-migration-drift.sh` — but both compare the ledger against the **production** database, which already contains `users` and `api_keys` from before the ledger existed. `migration list` reporting zero out of sync is therefore consistent with a ledger that cannot build the schema at all. The filename `20260320010001_phase1_integrate_existing_schema.sql` is the tell: it was written to *adapt to* a database that already existed. **A migration set is only proven by replaying it onto an empty database, and until 2026-08-03 that had never been done.**

**Why it is P1 rather than a CR11 sub-item.** It is not an isolation defect and it does not go away when CR11 is fixed. Two independent consequences: the dev environment cannot be built (blocking [[CR11]] step 1 and everything behind it — [[CR02]] item 5, the toolkit e2e suite), and **the repo cannot reconstruct its own database from source.** The second is a disaster-recovery gap that exists today, in production, regardless of whether anyone ever wants a dev environment.

**Scope:**
1. Read production's actual DDL for `public.users` and `public.api_keys` — columns, constraints, indexes, RLS policies, triggers, grants. Not reconstructible from the repo; it must come off the live database.
2. Add a **baseline** migration that creates both, ordered before `20260320000000`. Use `create table if not exists` so it is a no-op against production and correct on a fresh project. ⚠️ Renumbering ahead of an applied migration needs care against the ledger CR17 just repaired — confirm the approach against `schema_migrations` before writing it.
3. Re-run `db push` against `tumhmtshahktumhqqamk` until it completes, then `PATCH /v1/projects/{ref}/config/auth` for the access-token hook (runbook item 4 — `db push` does not enable it) and re-verify RLS with the catalog query, **not** a status code.
4. ~~**Add a CI guard that replays the full ledger onto an empty database**~~ ✅ **Written 2026-08-03** — `.github/workflows/migration-replay-check.yml` → `scripts/check-migration-replay.sh`: boots the Supabase local stack (full stack, not `db start` — the auth service is what guarantees `auth.users`/`auth.uid()`, which the baseline FKs into), `supabase db reset` for a deterministic empty→replay, then **asserts the rebuilt schema** (17 named objects incl. the `user_details` view via `to_regclass`, ≥3 public enums, both `organizations.domain`/`.type` columns) so a replay that "succeeds" without producing the schema still fails. No secrets, path-filtered on `supabase/**`, PR-safe including forks. `config.toml` `major_version` bumped 15 → **17** in the same change — production is 17.6, so the guard would otherwise have tested a different major than production runs. ⚠️ **Written and statically verified, not yet executed**: Docker is absent on this machine, so the stack cannot boot locally. Verified instead: `bash -n`, YAML parse, and the assertion SQL run against the rebuilt dev project — passes on the good schema, **and a mutation test confirms it reports an injected missing object**. The first CI run on a push touching `supabase/**` is the real proof; treat this item fully closed only after that run is green.

**Status:** ✅ **Resolved 2026-08-03 — the ledger now rebuilds production's schema from an empty database, verified by replay.** Final parity against production: **24/24 tables+views, 255/255 columns, 3/3 enums, zero missing, zero extra.** The CI guard (scope step 4) is written and statically verified 2026-08-03 — `migration-replay-check.yml` + `check-migration-replay.sh`; its first real execution happens on the next push touching `supabase/**`, since Docker is absent on this machine. No production change was made — every query against production was read-only, and all five new migrations are idempotent no-ops there.

---

**✅ Baseline written 2026-08-03 and proven by replay — and the gap was 5× larger than this entry first said.** Generated from production's live catalogs, not hand-written: `supabase/migrations/20260319000000_baseline_pre_ledger_schema.sql` (432 lines) + `20260803000000_baseline_deferred_constraints.sql`. Applied to the empty dev project, it creates exactly the 10 missing tables and `db push` now gets *past* the original failure. **The full gap, measured:**

| Missing from the ledger | Detail |
|---|---|
| **10 tables** | `analytics_projects`, `api_keys`, `provider_oauth_tokens`, `roles`, `stripe_events`, `user_activity`, `user_profiles`, `user_roles`, `user_sessions`, `users` — 13 of 23 production tables were versioned, so **43% of the schema was outside version control** |
| **3 enum types** | `api_key_status`, `api_key_tier`, `organization_type` — no migration contains a single `create type` |
| **2 columns on a *ledger-managed* table** | `organizations.domain` and `organizations.type`. The ledger declares 10 of production's 13 columns; `parent_organization_id` arrived via `20260731010000`, the other two out of band. **So the gap is not only whole tables** — a replayed `organizations` is structurally wrong, which no table-level check would catch |

Also carried: 37 constraints, 44 indexes, 28 RLS policies, 8 triggers. All ten tables have RLS enabled.

**Three structural constraints found by reading the schema, each of which would have broken a hand-written baseline:**
1. **FK cycle across the boundary.** `users` and `api_keys` → `organizations` (ledger), while the ledger's `organization_memberships` → `users` (baseline). No single file can hold both, hence part 2.
2. **Trigger functions post-date the baseline.** All 8 triggers call `update_timestamp` (`20260320010002`) or `assign_default_role` (`20260717000000`), so triggers are deferred too.
3. **`create policy if not exists` is not valid PostgreSQL**, and policy names here contain spaces (`"Anyone can view roles"`) — unquoted they are a syntax error. Drop-then-create, always quoted.

Both files are idempotent (`create table/index if not exists`, `enable row level security`, guarded `do $$` blocks for types and FKs), so they are a **no-op against production**.

✅ **Two further defects in the EXISTING ledger, both found only by replaying, both now fixed.** The prediction that each replay would surface one more held exactly:

1. **The ledger depended on its own future.** `20260320000000` created five RLS policies reading `public.auth_user_links` — a table created by `20260320005000`, which sorts *after* it. Moved to **`20260803010000`**, sorted last because those policies also touch `entitlements` and `subscriptions`.
2. **`20260731010000` read `organizations.type` before anything created it.** The `domain`/`type` columns were initially put in the deferred file and failed with `column "type" does not exist`; they now live in **`20260320000001`**, immediately after the table is created and well before the reader.
3. **A view, which no table-level check would ever have caught.** `public.user_details` (23 columns) and `entitlements.created_at` were still missing at 23/23 *table* parity. **Table parity is not schema parity** — added as `20260803020000`.

**The five files, in ledger order:** `20260319000000` (10 tables, 3 enums, 37 constraints, 44 indexes, 27 policies, RLS on all ten) → `20260320000001` (`organizations.domain`/`.type`) → `20260803000000` (deferred FKs into `organizations`, 8 triggers, 1 policy) → `20260803010000` (the 5 relocated policies) → `20260803020000` (the view + residual column).

⚠️ **Editing `20260320000000` was authorised explicitly.** It is already applied in production and never re-runs, so production is unaffected, but the file no longer matches what historically ran — [[CR17]] territory. The removal is recorded in a comment at the foot of that file pointing to where the statements went.

🔴 **One near-miss worth keeping, because the same shape will recur.** The first attempt moved statements by *string match* on `auth_user_links`, which swept **`drop table if exists public.entitlements cascade;`** into the new migration — that statement sits under a header comment mentioning `auth_user_links`, and it belongs at the top of `20260320000000` as pre-create cleanup. Relocated after the table exists, it would have dropped `entitlements` **with CASCADE**. Caught by the replay failing, reverted with `git checkout`, and redone by explicit line range with assertions that refuse to move any `drop table` / `truncate` / `delete from`. **Never relocate SQL by grepping for an identifier** — comments and unrelated statements share the chunk.

**Replay state on `tumhmtshahktumhqqamk`:** all 19 migrations applied, `Finished supabase db push`, full parity with production. Production untouched throughout — every query against it was read-only.

**Tooling note that unblocks more than this item:** CLAUDE.md recorded the Management API query endpoint as unusable and concluded "the only route for DDL is the Dashboard SQL editor". That is wrong, and it is why this item looked harder than it was. The endpoint rejects `sb_secret_` keys because those are data-plane credentials — it wants an `sbp_` personal access token, and **the Supabase CLI already holds a working one in the macOS keychain**: `security find-generic-password -s "Supabase CLI" -w`, strip the `go-keyring-base64:` prefix, `base64 -d`. Every schema read in this entry used it. It needs no Docker and no `SUPABASE_DB_PASSWORD` — both of which are separately broken on this machine (`db dump` shells out to Docker, which is not installed; the stored DB passwords do not authenticate).

---

<a id="cr12"></a>

### CR12: Production `api-gateway` and `stripe-webhook` have zero secrets bound and are degraded

> **✅ Largely resolved 2026-07-27 evening — `api-gateway` is healthy.** `GET /health` returns `200 {"database":"healthy","durableObjects":"healthy"}`, up from `503 {"database":"degraded"}`, and `/v1/me` correctly answers `401` to an anonymous caller. Three secrets were bound: `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_JWT_SECRET`. **This is what makes [[V02]]'s dashboard real** — its endpoints can return data for the first time since 2026-03-31.
>
> **Step 1 answered by evidence: pre-launch, not a regression.** No Stripe webhook endpoint has ever been registered on either account (verified against both the v1 `webhook_endpoints` and v2 `event_destinations` APIs, both returning zero), so `stripe-webhook` was never receiving traffic to lose. Nothing was dropped; nothing was ever sent.
>
> **The premise was also incomplete.** Missing secrets were not the only reason `stripe-webhook` could not work — **its two tables did not exist** ([[CR17]]). Binding secrets alone would have left every event failing on a 404 from PostgREST. Both are now fixed.
>
> **Corrected:** this entry says both Supabase projects are `INACTIVE`. The project that matters, `cfrbahzzklwrnmbtqojl` ("IntegrityStudio"), is **`ACTIVE_HEALTHY`**. The `INACTIVE` one is `kvbcgfttukwciiwieezp` ("atx_movement"), an unrelated project. No resume step is needed.
>
> **What remains:** three secrets that do not exist anywhere to bind — see Status below.

**Priority:** P1 | **Source:** session 2026-07-27, auditing worker secrets while investigating CR11
**Estimated:** 30 minutes to restore, longer to explain

**Context:** Querying the Workers API for the secrets bound to each deployed worker returns **zero** for both `api-gateway` and `stripe-webhook`:

| Worker | Secrets bound | Last deployed |
|---|---|---|
| `sender-worker` | 13 | 2026-07-26 |
| `integrity-studio-contact` | 2 (`CSRF_SECRET`, `RESEND_API_KEY`) | 2026-03-31 |
| **`api-gateway`** | **0** | 2026-03-31 |
| **`stripe-webhook`** | **0** | 2026-03-31 |

`api-gateway`'s own `wrangler.toml` documents five required secrets (`SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_JWT_SECRET`, `API_KEY_HMAC_SECRET`, `STRIPE_SECRET_KEY`). None are set. Its health endpoint confirms the consequence:

```
GET https://api-gateway.alyshia-b38.workers.dev/health
503 {"database":"degraded","durableObjects":"healthy",...}
```

Verified by two independent sources: the Workers REST API, and `wrangler secret list --name api-gateway` returning `[]` (control: `sender-worker` returns 13 by the same method).

So every authenticated route that touches Supabase — usage, entitlements, orgs, me, api-keys — cannot work, and `stripe-webhook` cannot verify a signature or reach the database, meaning subscription events are dropped rather than dead-lettered. **Correction (2026-07-27):** an earlier version of this entry cited `api.integritystudio.ai/v1/me` returning `401 Missing or invalid Bearer token` as proof the production route was attached and working. That response came from `api-gateway-dev`, not `api-gateway` — see CR13. Production `api-gateway` has **no zone route at all**; the only routes on `integritystudio.ai` are `api.integritystudio.ai/*` → `obtool-api` and `ingest.integritystudio.ai/*` → `obtool-ingest`. It is reachable solely at its `workers.dev` hostname, which is what the Flutter app calls.

**`https://api-gateway.alyshia-b38.workers.dev` is the production gateway**, not a dev URL — and it is the URL the shipped app actually calls. It is the compile-time default for `API_GATEWAY_URL` in both `lib/services/dashboard_service.dart:16` and `lib/services/provisioning_service.dart:22`, and `ci.yml` builds with no `--dart-define`. The dev worker is the separate script `api-gateway-dev`. So the 503 is on the live user path, not a back channel.

*(Correction: an earlier revision argued the two were distinct because `api-gateway-dev`'s `workers.dev` subdomain "is not even enabled — returns Cloudflare 1042". That was propagation lag moments after creation. The subdomain is enabled and now answers 503 with the same body as production. The workers are still demonstrably distinct — separate scripts, and separate Durable Object namespaces: `14813730…` bound to `api-gateway`, `30f146ce…` to `api-gateway-dev` — so the conclusion holds and the DO-isolation claim in the changelog is confirmed. Only that piece of evidence was wrong.)*

`degraded` rather than `unhealthy` is consistent with unset secrets: `checkDatabase` gets `undefined` for `supabaseUrl`, the shared client catches the resulting invalid-URL throw and returns `{ok: false}`, which maps to `degraded`. It does not distinguish this from a reachable-but-failing database. ~~Both causes are present, because both Supabase projects are `INACTIVE` (free-tier pause).~~ **Wrong — corrected 2026-07-27 evening.** Only one cause was present. `cfrbahzzklwrnmbtqojl` is `ACTIVE_HEALTHY`; binding the three secrets alone flipped `/health` to `200 {"database":"healthy"}` with no resume step. The `INACTIVE` project is `kvbcgfttukwciiwieezp` ("atx_movement"), unrelated to this repo.

**Monitoring trap:** `https://api.integritystudio.ai/health` returns **200**, so any uptime check pointed there is permanently green regardless of gateway state. Point step 3 at `https://api-gateway.alyshia-b38.workers.dev/health` instead.

**Corrected 2026-07-27:** this previously attributed that 200 to "the marketing site, nothing to do with the gateway", and said the custom domain "only routes `/v1/*`". Both are wrong. The zone route is `api.integritystudio.ai/*` → `obtool-api` (a wildcard, not `/v1/*`), and the 200 is `obtool-api`'s own health endpoint — the body is `{"status":"ok","d1":"connected"}`, and `obtool-api` is the only worker in the account binding D1. The conclusion stands; the stated cause does not, which matters if someone tries to fix this by looking at the marketing site.

**Scope:**
1. Determine whether this is expected — i.e. whether the platform is pre-launch and these two workers were never configured, or whether secrets were lost in a redeploy. The 2026-03-31 timestamp on both suggests they have been in this state for ~4 months.
2. If live traffic is expected: set the documented secrets (`wrangler secret put --name api-gateway`), resume the Supabase project, and re-check `/health`.
3. Add `/health` to an uptime check so a degraded gateway is not discovered incidentally during a code review four months later.
4. Reconcile with the many changelog entries describing api-gateway quota, usage, and entitlements work — that code has been shipped against a gateway that cannot reach its database.

**Status:** ⚠️ Partial (2026-07-27 evening). Bound and verified:

| Worker | Bound | Health |
|---|---|---|
| `api-gateway` | `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_JWT_SECRET` | `200 {"database":"healthy"}` |
| `stripe-webhook` | `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` | tables exist; cron can now drain |

**Two of the three cleared on 2026-07-28 when [[CR18]] unblocked; one remains:**

1. 🔴 **`API_KEY_HMAC_SECRET`** (`api-gateway`) — still empty in Doppler. Deliberately **not** generated: API keys are minted by `api-provisioning-receiver` in the `observability-toolkit` repo, which hashes them with its own copy. Inventing a value here would silently fail to verify every existing key. The canonical value must come from that Worker's owner. Until then, API-key-authenticated routes (`/v1/ingest/*`) stay broken while JWT routes work.
2. ✅ **`STRIPE_SECRET_KEY`** (`api-gateway`, and `sender-worker`) — bound 2026-07-28 with the `rk_live_` restricted key. `sender-worker` verified reading it. The billing portal is separately unblocked now that a live Customer Portal configuration exists (`bpc_1Ty2XDAwEfePbhfk9PndBNgW`); a real session was created against it to prove the call works.
3. ✅ **`STRIPE_WEBHOOK_SECRET`** (`stripe-webhook`) — bound 2026-07-28 from live endpoint `we_1Ty29dAwEfePbhfkky1OeqQu`, verified with a wrong-secret control (200 vs 401).

**Updated worker state (2026-07-28):**

| Worker | Bound | Health |
|---|---|---|
| `api-gateway` | `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_JWT_SECRET`, `STRIPE_SECRET_KEY` | `/health` 200 |
| `stripe-webhook` | `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `STRIPE_WEBHOOK_SECRET` | signed probe → `processed:true`; replay → `already_processed` |
| `sender-worker` | 13 existing + `STRIPE_SECRET_KEY` | `/health` 200 |

**A caveat that only surfaced when the secret finally worked.** Binding `STRIPE_WEBHOOK_SECRET` let a signed request reach the handler for the first time, and it returned `"Failed to log processed event"` — a string absent from current source. Production `stripe-webhook` had been running 2026-03-31 code that could not write `webhook_events_log`. Supabase was not at fault; the prd key inserts and deletes against that table cleanly. Redeploying fixed it. ~~**The same check has not been done for `api-gateway`, whose deployed code is also from 2026-03-31 and cannot be redeployed until [[CR13]] step 1.** Assume its behaviour does not match this repo.~~ **Resolved 2026-07-30** — `api-gateway` was redeployed from current source (version `9c4e7c61`) and answers `200 {"database":"healthy","durableObjects":"healthy"}`, so its behaviour now does match this repo. Four months of fixes shipped in that one deploy, including the bearer-token-before-quota security fix and CR05/CR06's 5xx-on-DB-error.

One side effect worth watching: `stripe-webhook`'s `*/15` dead-letter cron now has database access, a table to read, and current code — and since 2026-07-30 the Worker also has **observability deployed**, so a cron run is finally readable. Nothing has confirmed a successful run yet; that check is [[CR20]] step 4 and is now actually possible.

**Re-verified 2026-07-30 (dashboard CORS/auth session, see [[CR26]]).** `wrangler secret list` against production `api-gateway` returns exactly four: `STRIPE_SECRET_KEY`, `SUPABASE_JWT_SECRET`, `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_URL`. Two corrections to the state above:

- **Item 1 still stands unchanged** — `API_KEY_HMAC_SECRET` is not bound, so `/v1/ingest/*` and the API-key management routes remain dead. The reasoning for *not* generating one locally is unchanged and still the blocker: the canonical value lives with `api-provisioning-receiver` in `observability-toolkit`, and inventing one here would silently fail to verify every key that Worker has already minted.

  ~~**Note the type declaration disagrees with reality**~~ — ✅ **fixed 2026-07-31.** `Env.API_KEY_HMAC_SECRET` is now `string | undefined`, so the type no longer asserts a binding production does not have. Making it optional surfaced **four** consumers, not the one the note implied — `preVerifyToken` (helpers), `resolveAuth` in both `ingest.ts` and `usage.ts`, and key minting in `api-keys.ts` — each of which would have passed `undefined` into `hmacVerify`. All now route through a shared `requireHmacSecret` guard that returns **503, not 401**: absence is a server-configuration fault, and answering 401 would tell a caller their key is bad when the server simply cannot check it (the same distinction [[CR23]] settled for 401-vs-403).

  Three properties are pinned by tests, all mutation-verified against the unguarded code: API-key requests get 503 with **zero database calls** (the guard runs before any query), key *minting* refuses rather than storing a hash keyed on nothing — which would have produced a token that could never authenticate — and, the one that matters most, **a JWT still succeeds with the secret absent**, so the missing credential cannot regress user auth. 192 api-gateway tests pass; 1,109 across all workers.
- ~~**`SUPABASE_JWT_SECRET` is now dead weight on this Worker.**~~ **✅ Unbound 2026-07-30.** Once `api-gateway` moved to Auth0 JWKS nothing read it, leaving a credential with no reader. Removed from the `Env` interface, from the `wrangler.toml` secret list, and deleted from the Worker (`wrangler secret delete`, non-interactive confirmation). Production now binds **three** secrets — `STRIPE_SECRET_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_URL` — and every route was re-verified *after* the deletion, not just after the deploy: `/health` reports `database: healthy, durableObjects: healthy`, all six authenticated routes plus `POST /bootstrap` return 200 on a real login token, and a forged token still 401s. The shared `supabaseJwtKey`/`jwksUrlFor` helpers are now `@deprecated` — no production caller remains, and pointing them at a token Supabase did not issue is what produced the original `401 Invalid JWT signature`. `EnvSchema` in `workers/lib/types/handler-options.ts` still described `SUPABASE_JWT_SECRET` *and* `SUPABASE_JWT_ISSUER` long after both went dead; it has no importers, so the drift was silent. Updated to the real shape with a note to delete it rather than let it mislead again.

---

<a id="cr13"></a>

### CR13: Decide what should serve `api.integritystudio.ai/v1/*` (cross-repo ownership)

**Priority:** P2 — **argues for P1; see the deployment-backlog note below** | **Source:** session 2026-07-27, after a dev deploy inadvertently claimed the route
**Estimated:** 30 minutes, once the ownership question is answered

> **This trap is now blocking real fixes, not just sitting there (added 2026-07-28).** Production `api-gateway`'s last **code** deploy was **2026-03-31** — the three 2026-07-28 02:36 entries in its deployment history are Supabase secret bindings, and the 04:18 one is a `STRIPE_SECRET_KEY` binding; none of them shipped code. Every `api-gateway` fix since March is therefore undeployed, and it cannot be deployed until step 1 removes the `routes` key. That backlog includes **`d9ba71a` — "verify bearer token before quota enforcement", a security fix** — plus `d11cf38` (return 5xx on DB errors rather than masking them as empty data, CR05/CR06). Defusing the trap is no longer housekeeping; it is the precondition for shipping a security fix.
>
> `sender-worker` is in better shape but not current either: last code deploy **2026-07-26 04:08**, and `69fbb1b` is not on `origin/main`. It self-corrects on merge, since CI deploys it — `api-gateway` has no such path.

**Context:** `workers/api-gateway/wrangler.toml` declares `routes = [api.integritystudio.ai/v1/*]` at the top level, so a `npm run deploy:prd` from this repo **will claim that hostname path** for `api-gateway`. But the zone's routes are currently:

| Pattern | Worker | Owned by |
|---|---|---|
| `api.integritystudio.ai/*` | `obtool-api` | observability-toolkit |
| `ingest.integritystudio.ai/*` | `obtool-ingest` | observability-toolkit |

`obtool-api` holds the wildcard, and there is no `/v1/*` route, so `/v1/*` requests currently fall through to `obtool-api`. The more specific pattern wins whenever this repo deploys to production.

**Corrected 2026-07-27 — this entry was mis-specified.** It described a contest over the same paths. Reading both deployed scripts (`GET /accounts/:id/workers/scripts/:name`) shows **zero overlap**:

| `obtool-api` serves | `api-gateway` serves |
|---|---|
| `/v1/traces`, `/v1/traces/:id`, `/v1/traces/:id/raw`, `/v1/sessions`, `/v1/sessions/:id`, `/v1/metrics`, `/v1/metrics/histograms`, `/v1/logs`, `/v1/cost`, `/v1/datasets`, `/v1/datasets/:id` | `/v1/me`, `/v1/orgs`, `/v1/orgs/:id/{dashboard,billing-status,usage/summary,entitlements,quota/status,billing-portal,api-keys}`, `/v1/ingest/events`, `/v1/ingest/otel` |

These are complementary halves of one product API — a telemetry data plane and an account/billing control plane. Nobody is claiming anybody's path. The real problem is the **wildcard**: `obtool-api` holds `/*` and auth-gates before routing, so it answers `401` for the gateway's paths rather than passing them on. (That auth-before-routing behaviour is also why external probing proves nothing — `/v1/nonexistent-xyz` returns `401` too.) So the question is not *who wins the hostname* but *how one hostname is split across two complementary workers*, which has a different and larger answer set — see Scope.

**How this surfaced:** a `wrangler deploy --env dev` from this repo created `api.integritystudio.ai/v1/* -> api-gateway-dev` (route inheritance — see CR12's note and the comment in `api-gateway/wrangler.toml`). For roughly 14 hours on 2026-07-27, that path was served by a secret-less dev Worker. The route was deleted and the prior fall-through restored; the config now carries an explicit `routes = []` and a test enforces it.

**Scope — defusing and deciding are separable, and step 1 should not wait:**

1. **Defuse now, independent of the architecture.** Delete the `routes` key from `workers/api-gateway/wrangler.toml`. The shipped app calls `workers.dev` directly, so this costs nothing and permanently removes the landmine. Every option below is easier to reach from a safe state.
2. ~~**Do not route anything to the gateway until [[CR12]] is fixed.** It has zero secrets and answers `{"database":"degraded"}`.~~ **Largely satisfied 2026-07-27 evening** — the gateway now answers `200 {"database":"healthy"}`. Two caveats before reading this as "safe to route": `API_KEY_HMAC_SECRET` is still unbound, so API-key-authenticated paths (`/v1/ingest/*`) would 401; and the danger in step 1 was never the gateway's health, it is that `/v1/*` is **more specific than `obtool-api`'s `/*`** and would capture that Worker's telemetry paths. A healthy gateway makes the trap *more* tempting, not less dangerous.
3. **Then choose a topology:**

| | Approach | Trade-off |
|---|---|---|
| **A** | Concede — gateway stays on `workers.dev` | Zero risk, one-line diff. **Viable only as a temporary defusal, not an end state** — see below |
| **B** | Path-split: `/v1/me`, `/v1/orgs*`, `/v1/ingest/*` as separate routes | Keeps one hostname, but the route list becomes a hand-maintained mirror of a dispatch table in another repo. **Never `/v1/*` here** — that is the trap as currently armed and would swallow all of `obtool-api` |
| **C** | Give the gateway its own branded hostname | Matches the existing per-service convention; one hostname per repo, no cross-repo route coordination. Costs a DNS record, a Flutter default, and doc updates |
| **D** | Single front door — `obtool-api` service-binds unmatched `/v1` paths to `api-gateway` | Best external DX. Requires changes in a repo this one does not own, and couples the two auth models |

4. **`api-gateway` is the customer-facing API** ([[CR16]]), so it needs a real hostname eventually — customers cannot be handed `api-gateway.alyshia-b38.workers.dev` as an integration target, and `docs/api-usage-ingestion.md` already publishes `api.integritystudio.ai` as theirs. That rules **A out as a destination**, though not as today's safe parking spot. It also raises a question this entry cannot answer from the repo: `obtool-ingest` is internal, but **is `obtool-api` internal too?** If both `obtool-*` workers are internal, then the most customer-looking hostname in the account is serving internal telemetry while the actual customer API has none — and the right answer may be to *give `api.integritystudio.ai` to the gateway* and move the obtool stack to an internal name, rather than routing around it.
5. Either way, stop relying on the `workers.dev` hostname as the app's production default (`dashboard_service.dart:16`, `provisioning_service.dart:22`).

**Suggested:** step 1 (delete the `routes` key) immediately and unconditionally — it is safe, reversible, and independent of everything else. Defer the destination until `obtool-api`'s audience is settled, because that answer decides between "gateway takes `api.integritystudio.ai`" and options C/D.

**Status:** ⚠️ Partial — step 1 done (2026-07-29) and **proven in practice (2026-07-30)**. The `routes` key is gone from `workers/api-gateway/wrangler.toml`, and rather than trusting that, a real `npm run deploy:prd` was run and the zone's route list re-read immediately after: still exactly `api.integritystudio.ai/*` → `obtool-api` and `ingest.integritystudio.ai/*` → `obtool-ingest`, with nothing pointing at `api-gateway`. The trap is defused in fact, not just in config, and [[CR22]]'s fix has shipped. Hostname-topology decision (steps 2–5: which approach to give the gateway a branded endpoint) still needed.

> ✅ **Update 2026-08-03 — the measurement steps 3–5 were missing now exists as [[CR31]] and [`docs/api-routing.md`](api-routing.md).** Both API surfaces were inventoried from source and the zone routes re-read live. Three things it settles, so they need not be re-derived here:
> - **Option B is the recommendation, and it is four patterns, not three.** `/v1/me`, `/v1/orgs*`, `/v1/ingest/*`, `/bootstrap` — the last is new since this entry was written, and the api-keys routes turned out to be nested under `/v1/orgs/:id/`, so `/v1/orgs*` already covers them. No code change on either worker.
> - **Option "give `api.integritystudio.ai` to the gateway" (step 4's speculation) is ruled out on evidence, not on audience.** The two route tables are **disjoint apart from `/health`**, so repointing the wildcard would `404` all thirteen `obtool-api` routes — including `/v1/traces`, which `docs_api_page.dart:250` publishes and which currently works. Repointing is a regression regardless of who `obtool-api` serves; the audience question only decides whether it should *eventually* move to an internal name.
> - **Step 5 has become urgent for a reason this entry did not anticipate.** The published docs already advertise three endpoints that resolve to nothing — a 401 quickstart, a `POST /v1/alerts` that exists on neither worker, and an NXDOMAIN sandbox host. That is customer-visible now and needs no topology decision, so it is tracked under CR31 rather than gated behind this one.
>
> ⚠️ **The auth-before-routing caveat at the top of this entry is more general than stated.** It says external probing proves nothing because `/v1/nonexistent-xyz` returns `401` too — true, and CR31 hit the same wall plus a second one: **`curl` defaults to GET**, so probing `api-gateway`'s POST-only routes (`/v1/ingest/*`, `/bootstrap`) returns `404` and reads as "route missing". Both traps understate what exists. Read the dispatch table from source; probe only to confirm what is live.

~~**One live footgun remains in that file, and it is not step 1's.** `[env.staging]` still declares `routes = [staging-api.integritystudio.ai/v1/*]`.~~ **✅ Closed 2026-07-31 — the block is deleted.** It was inert (nothing passed `--env staging`, and `deploy:prd` deliberately passes no `--env` at all), but it was the same shape of latent route claim in the same file, and it repeated neither `durable_objects` nor `observability`, so a staging deploy would have produced a Worker with no DO namespace and no telemetry. Confirmed before deleting that it was the only `[env.staging]` in the repo and that no script or workflow invokes `--env staging`. Both remaining configs re-validated with `wrangler deploy --dry-run`: prd resolves `QUOTA_DO`, `RATE_LIMIT_KV` (`766332ec…`), `AUTH0_DOMAIN`, `AUTH0_AUDIENCE`; dev the same shape with KV `46a717cd…`.

**A test now holds the line**, because deleting dead config does not stop the next one being added: `deploy-environments.test.ts` asserts every Worker declares `[env.dev]` and nothing else, so a new named environment fails the suite until someone gives it a deploy path *and* repeats the full `NON_INHERITABLE` set. Mutation-verified — re-adding the `[env.staging]` block fails exactly 1 test; suite went 50 → 55 passing.

> ✅ **Resolved 2026-07-29 — step 1 done.** The `routes` key has been removed from `workers/api-gateway/wrangler.toml` (52 deploy-environment tests passing). A `deploy:prd` will no longer declare `api.integritystudio.ai/v1/*` and cannot displace `obtool-api`. The topology question (steps 3–5 — how to give the gateway a real branded hostname) remains open and is deferred until `obtool-api`'s audience is settled.

---

<a id="cr14"></a>

### CR14: Superseded Worker versions stay publicly callable with live secrets

**Priority:** P1 | **Source:** session 2026-07-27, auditing `api-gateway-dev` settings via the Cloudflare API
**Estimated:** 15 minutes to mitigate; the audit of what old versions expose is longer

**Context:** Every Worker in the account has `previews_enabled: true`. Cloudflare then publishes each retained version at `https://<version-id-prefix>-<script>.<subdomain>.workers.dev`, **with the script's current secrets bound**. Superseded code therefore stays live.

Verified, not theoretical:

| URL | Version date | Result |
|---|---|---|
| `6a5b6edf-sender-worker.…workers.dev/health` | 2026-07-26 (current *then*; superseded since) | `200` |
| `b2c2b878-sender-worker.…workers.dev/health` | **2026-04-20** | **`200` — live** |
| ~~`15f2bcf0-sender-worker.…workers.dev/health`~~ | ~~2026-04-10~~ | ~~`404` (past retention)~~ — **misread; see the 2026-07-29 enumeration** |

The `b2c2b878` version predates this branch's security work: the per-IP auth rate limit (`38b2878`), the signup compensating rollback (`c75592c`), the CORS origin-reflection fix (`66f1825`), and the JWT-in-URL removal (`c55dcff`). It answers requests today with all 14 production secrets bound. **So merging and deploying this branch does not fully retire the vulnerabilities it fixes** — the un-fixed code remains reachable at a parallel URL.

Workers with both secrets and preview URLs enabled (counts re-read live 2026-07-29):

| Worker | Secrets | Notes |
|---|---|---|
| `sender-worker` | **16** | Auth0 ROPC + M2M, Supabase service-role, HMAC `SHARED_SECRET`, `STRIPE_SECRET_KEY`, `SIGNING_KEYS`, `ACTIVE_KEY_ID` |
| `api-provisioning-receiver` | **10** | **Different repo** (`observability-toolkit`) — needs that owner |
| `integrity-studio-contact` | 2 | `CSRF_SECRET`, `RESEND_API_KEY` |

**Counts re-read 2026-07-30 after the key-rotation provisioning:** `sender-worker` now holds **16** (`SIGNING_KEYS` + `ACTIVE_KEY_ID` added) and `api-provisioning-receiver` **10** (`SIGNING_KEYS` added). The receiver still has previews **on**, so its brand-new signing key is exposed on every retained version the moment it was bound — the clearest illustration yet of why step 3 is the item that matters.

Both counts were understated when this entry was written — `sender-worker` was 13 before `STRIPE_SECRET_KEY` was bound on 2026-07-28 ([[CR18]]), and the receiver held 9, not 7: `AE_SQL_API_TOKEN`, `AUTH0_DOMAIN`, `CF_ACCOUNT_ID`, `KEY_ROTATION_DATES`, `SENTRY_DSN`, `SHARED_SECRET`, `SUPABASE_ANON_KEY`, `SUPABASE_PROVISIONING_KEY`, `SUPABASE_SERVICE_ROLE_KEY`.

**Re-counted live 2026-07-31: the receiver still holds 9, but not the same 9** — `SUPABASE_SERVICE_ROLE_KEY` is **gone** and `SIGNING_KEYS` has been added. That is where the "10" quoted elsewhere came from: `SIGNING_KEYS` was counted as an addition without noticing the deletion. Current set: `AE_SQL_API_TOKEN`, `AUTH0_DOMAIN`, `CF_ACCOUNT_ID`, `KEY_ROTATION_DATES`, `SENTRY_DSN`, `SHARED_SECRET`, `SIGNING_KEYS`, `SUPABASE_ANON_KEY`, `SUPABASE_PROVISIONING_KEY`. The exposure argument is unchanged — the removal swaps one Supabase service credential for another, since `SUPABASE_PROVISIONING_KEY` is the live RLS-bypassing key (see [[CR11]]'s 2026-07-31 update) — but a *stable* count that hides a changed composition is exactly the kind of number this page should not be carrying, so read the list rather than the total.

The 8-hex-character version prefix is not a meaningful secret: `wrangler` prints the full version ID on every deploy, so it lands in terminal scrollback and CI logs. This session printed one.

**Scope:**
1. ~~Set `preview_urls = false`~~ — done 2026-07-27 in `sender-worker` and `contact-form` `wrangler.toml`. It takes effect only on their next deploy, so config alone left production exposed for two more days; **both were closed via step 2 on 2026-07-29 instead of waiting.** The config still matters — it is what keeps them closed after the next deploy, and **that is now confirmed rather than assumed: all four production Workers were deployed on 2026-07-30 and every one still reports `previews_enabled: false` afterwards.** A deploy neither re-opened previews nor undid the API-level fix.
2. **Immediate mitigation without a deploy**, per worker. **`"enabled":true` must be sent alongside** — the two fields are written together, and omitting it switches off the Worker's `workers.dev` hostname, which for `api-gateway` is the hostname the shipped Flutter app calls:
   ```bash
   doppler run --project integrity-studio --config prd -- sh -c \
     'curl -X POST -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
       -H "Content-Type: application/json" -d "{\"enabled\":true,\"previews_enabled\":false}" \
       "https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/workers/scripts/sender-worker/subdomain"'
   ```
   (This is the sanctioned use of `doppler run` — injecting `CLOUDFLARE_API_TOKEN` into a process. The prohibition in [[CR11]] is on *reading a value back* with it.)
3. Ask the `observability-toolkit` owner to do the same for `api-provisioning-receiver` (**10** secrets, not deployable from here). **Now quantified (2026-07-30): 30 of its 30 code-upload versions are reachable, the oldest from 2026-03-20**, and all 30 are superseded — its active version `04b7fb90` was created by a secret binding, so that one has no preview URL. Every one of the 30 serves with the current secret set, including the `SIGNING_KEYS` bound at 01:29 that same morning.
4. ~~Decide whether preview URLs are wanted on the `*-dev` workers.~~ Resolved 2026-07-27 as a *mechanism*, **but only two of five dev Workers have actually picked it up.** `preview_urls` is an inheritable key — verified by deploying `sender-worker-dev` and `integrity-studio-contact-dev` after setting it only at the top level, and confirming both flipped to `previews_enabled: false`, so no `[env.dev]` duplicate is needed. (Contrast with the *non*-inheritable binding keys — the asymmetry is documented in `api-gateway/wrangler.toml`.) **Inheritance still only takes effect on deploy**, and the three dev Workers not redeployed since their configs were pinned — `api-gateway-dev`, `stripe-webhook-dev`, `bootstrap-worker-dev` — all still report `previews_enabled: true` live. Two of those hold no secrets; `stripe-webhook-dev` holds two (sandbox `STRIPE_API_KEY` + `STRIPE_WEBHOOK_SECRET`), so it is a real, if sandbox-only, instance of this exposure today. The earlier "the dev workers are already covered" was a config reading, not a live one.
5. Consider whether any retained version predates a *data-handling* change (schema, consent, retention), not just a security fix. The 2026-07-29 enumeration gives this a concrete scope: **63 superseded `sender-worker` versions back to 2026-03-29 and 8 superseded `integrity-studio-contact` versions back to 2026-01-17**, all currently serving.
6. ✅ **DONE 2026-07-31 — see the closing note at the end of this entry.** *(Original text, kept because it states the reasoning:)* **Add `api-gateway` and `stripe-webhook` to `SECRET_BEARING` in `workers/lib/deploy-environments.test.ts`.** The list is `['sender-worker', 'contact-form', 'bootstrap-worker']` (line 156), so the two Workers where this was closed *live* are the two whose `preview_urls = false` no test defends. Both bind secrets (4 and 3 respectively). Deleting the key from either config would restore previews on the next deploy and the suite would stay green — the same silent-default regression the note below records catching by hand on those two configs, which is exactly the kind of thing a test should be holding.

**Status:** ⚠️ Partial — **every exposure this repo controls is closed live as of 2026-07-29 evening.** `api-gateway`, `stripe-webhook`, `sender-worker`, and `integrity-studio-contact` all report `previews_enabled: false`, and the 71 superseded versions enumerated below now return `404`. Pre-emptive on the undeployed `bootstrap-worker`. **What remains is not ours to fix:** cross-repo `api-provisioning-receiver` (**9** secrets, step 3) and `stripe-webhook-dev` (2 sandbox secrets, closes on its next dev deploy). Step 5's data-handling audit is also open; ~~step 6's test gap~~ closed 2026-07-31.

**Closed live:** `api-gateway` and `stripe-webhook` first, applied via the step 2 API call **before** [[CR12]]'s secrets were bound, so those secrets were never exposed on a retained version. A second gap was found and fixed while doing it: **neither `wrangler.toml` set `preview_urls` at all**, and the key defaults to `true`, so the next `deploy:prd` would have silently re-enabled previews. Both configs now set it explicitly, matching `sender-worker` and `contact-form`.

**Then `sender-worker` and `integrity-studio-contact` (2026-07-29 evening).** Both were still `previews_enabled: true` with 14 and 2 secrets bound; both are now `false`, applied with the step 2 call rather than waiting on a deploy. Verified rather than assumed, in the order that matters:

- **Baseline first**, so "it still works" could mean something: both `enabled: true, previews_enabled: true`; `sender-worker/health` `200`; `contact-form` `GET /` `403` (POST-only and origin-checked).
- **`enabled: true` was sent in the same payload.** This is not optional here — neither Worker declares a zone route, and the shipped Flutter app reaches both *only* at `workers.dev` (`contact_service.dart:15`, `provisioning_service.dart:15`). Omitting the field would have taken the live contact form and the signup/signin path offline.
- **All 71 superseded versions now `404`** — plus the one active `contact-form` version that had also been reachable, so 72 URLs in total across both Workers. Convergence was not instant: the first sweep found 42 of 63 `sender-worker` versions already `404` and 21 still serving, matching the ~seconds propagation noted in [[CR18]]; a second pass returned zero still reachable. **Sampling once would have produced either a false "done" or a false "failed" depending on timing.**
- **Production unaffected, checked past `/health`:** `sender-worker/health` `200` on five consecutive samples and `POST /signin` with an empty body returns its real app-level `400 {"error":"missing email or password","code":"MISSING_FIELDS"}`, proving routes and bindings still serve rather than merely that the hostname resolves. `contact-form` `GET /` still `403` (identical to baseline) and its CORS preflight `OPTIONS /` returns `200`.

**Gap found and closed in config (2026-07-29):** `bootstrap-worker` was missing `preview_urls = false` despite declaring `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, and `SUPABASE_JWT_SECRET` in its `Env` type. Added to `wrangler.toml` and to the `SECRET_BEARING` assertion in `deploy-environments.test.ts` (commit 85e1a11). **Verified same day: this closes no live exposure, because no production `bootstrap-worker` exists** — `wrangler secret list --name bootstrap-worker` returns "Worker not found"; only `bootstrap-worker-dev` is deployed, with zero secrets bound. The fix is pre-emptive: the first production deploy will ship with previews disabled instead of defaulting them on.

**Still exposed — these hold secrets and still answer on per-version URLs:**

| Worker | Secrets | Fix |
|---|---|---|
| `api-provisioning-receiver` | **10** | **Cross-repo** — needs the `observability-toolkit` owner (step 3). **30 superseded versions reachable, back to 2026-03-20** |
| `stripe-webhook-dev` | 2 (sandbox) | Config already correct; closes on its next dev deploy, or the step 2 API call |

The step 2 command applies to either by name. `sender-worker` and `integrity-studio-contact` were on this list until 2026-07-29 evening and are now closed live.

The receiver is the one that matters. It binds both credentials [[CR01]] rotated on 2026-07-29 — `SHARED_SECRET` and the new `sb_secret_` service key — so its retained versions expose the current production values, not stale ones, and no amount of rotating on this side changes that.

---

**Re-audit 2026-07-29 evening — the config is unchanged, and three of this entry's factual claims were wrong. Nothing has been deployed, so nothing is newly closed; the exposure is larger and older than described.**

No commit has touched a `wrangler.toml` since `606c3e1`/`85e1a11`, and all five deployed Workers' configs still carry `preview_urls = false` (`deploy-environments.test.ts`, 53 tests, green). Live state, read from `GET /accounts/{id}/workers/scripts/{name}/subdomain` and `/secrets`:

| Worker | `previews_enabled` | Secrets | Verdict |
|---|---|---|---|
| `api-gateway` | `false` | 4 | ✅ closed live |
| `stripe-webhook` | `false` | 3 | ✅ closed live |
| `sender-worker` | ~~`true`~~ → **`false`** | **14** | ✅ **closed live later the same evening** |
| `integrity-studio-contact` | ~~`true`~~ → **`false`** | 2 | ✅ **closed live later the same evening** |
| `sender-worker-dev` | `false` | 0 | ✅ config inherited on redeploy |
| `integrity-studio-contact-dev` | `false` | 0 | ✅ same |
| `api-provisioning-receiver` | **`true`** | **9** | 🔴 exposed, cross-repo |
| `stripe-webhook-dev` | **`true`** | 2 (sandbox) | 🔴 exposed, sandbox blast radius |
| `api-gateway-dev` | **`true`** | 0 | ⚠️ no secrets to leak |
| `bootstrap-worker-dev` | **`true`** | 0 | ⚠️ same |
| `bootstrap-worker` | — | — | does not exist (confirms the pre-emptive note above) |

The two rows struck through above were read `true` during this audit and closed within the hour — the numbers in the enumeration below describe the exposure **as found**, which is what makes the count meaningful.

**1. "Past retention" was a misreading, and it mattered.** `15f2bcf0`'s `404` was attributed to Cloudflare having aged the version out, which implied the exposure shrinks on its own. It does not. The real discriminator is **how the version was created**: versions created by `wrangler secret put` never get a preview URL, versions created by a code upload always do. Enumerating every retained version and probing each one:

| Worker | Retained | By code upload | By secret binding | Code versions reachable | Of those, superseded | Oldest reachable |
|---|---|---|---|---|---|---|
| `sender-worker` | 100 | 63 | 37 | **63 of 63** (`200` on `/health`) | **63** | **2026-03-29** |
| `integrity-studio-contact` | 12 | 9 | 3 | **9 of 9** | **8** | **2026-01-17** |

All 37 + 3 binding-only versions return `404`, which is where `15f2bcf0` (a `wrangler secret` version) came from. So the mitigation window is not closing with time — **four months of `sender-worker` and six months of `contact-form` are simultaneously live**, and every future `deploy:prd` adds one more rather than retiring the old ones.

The superseded column is not the same as the reachable one, and the difference is instructive. `sender-worker`'s **active** version is `693d865d`, created 2026-07-29 21:20 by a `wrangler secret put` — so it has no preview URL of its own, and **all 63 reachable versions there are old code**. `contact-form`'s active version is `6c3455cf` (2026-03-31), which does answer on its preview URL, so 8 of its 9 are superseded. **71 superseded versions are reachable across the two.**

**2. This partly undoes [[CR01]]'s rotation work, which is the strongest argument for doing it now.** Preview URLs bind the script's **current** secrets, not the secrets that were current when that version shipped. Every credential rotated on 2026-07-29 — the HMAC `SHARED_SECRET`, both Auth0 secrets, the new `sb_secret_` service key, `STRIPE_SECRET_KEY` — is therefore live on all 63 old `sender-worker` versions. The same applies to `api-provisioning-receiver`, which has previews on and binds both the rotated `SHARED_SECRET` and the new `sb_secret_` service key. **Enumerated on 2026-07-30 rather than left as an inference: 30 of its 30 code-upload versions answer `200` on `/health`, the oldest dating to 2026-03-20, and all 30 are superseded.** Its `SIGNING_KEYS` was bound at 01:29 that morning and was therefore published across all 30 the moment it existed — a rotation that was exposed before it was ever used. Rotation does not reduce this exposure at all; it only changes which values are exposed. A pre-rate-limit build from March is a usable oracle for the *current* production credential set.

**What a closed preview URL looks like**, so this is checkable later without re-deriving it: `HTTP/2 404` with the body `error code: 1042`. An *open* preview URL on a retained code version returns the Worker's own response; a version created by `wrangler secret put` returns a plain `404` with no 1042 body, because it never had a preview URL to disable. Confirmed on all four Workers after the 2026-07-30 deploys, including the four brand-new versions — `preview_urls = false` means a deploy adds no new reachable surface.

**3. Three verification traps, all of which understated the exposure.** Recording them because a security item that fails in the reassuring direction is the dangerous kind. Probing these URLs with Python `urllib` returns a blanket **`403` for every version, including ones `curl` reports as `200`** — workers.dev rejects the default `Python-urllib` user agent, so an all-403 sweep reads as "nothing is reachable" when everything is. And counting only `200` undercounts: `contact-form`'s old versions answer `403`/`405`/`500` on `/` rather than `200`, since it is a POST-only, origin-checked endpoint — but every one of those means **the Worker ran**. Reachability is "anything but `404`", not "`200`". The third: a fast `curl` loop over dozens of these hostnames intermittently reports `%{http_code}` as **`000`**, which looks like "host does not exist" but is a client-side artefact — the same URL fetched singly returns a clean `HTTP/2 404`. Re-probe anything reading `000` one at a time before drawing a conclusion from it.

**Remaining work, in order of value.** ~~Step 2's API call on `sender-worker` and `integrity-studio-contact`~~ — **done 2026-07-29 evening; see the Status block.** ~~step 6's two-string test fix~~ — ✅ **done 2026-07-31.** `SECRET_BEARING` in `workers/lib/deploy-environments.test.ts` went from `['sender-worker', 'contact-form']` to all four secret-bearing Workers, adding `api-gateway` and `stripe-webhook`, which were pinned in config but guarded by no test — so a future edit could have re-opened them silently, which is precisely the regression this step exists to prevent. A second assertion covers `[env.dev]`: `preview_urls` *is* inherited by a named environment, so dev needs no repeat, but it must not override the parent back to `true`. Both mutation-verified — flipping the two configs fails 2 tests, adding `preview_urls = true` under `[env.dev]` fails 1, and all three passed before the change. `receiver-worker` is excluded deliberately: local stub, no production deployment.

What is left: step 3's cross-repo request to the `observability-toolkit` owner, which is now the only exposure carrying live production credentials and the only one nobody here can close; `stripe-webhook-dev`, sandbox-only and closing on its next dev deploy; and step 5's data-handling audit, still not done but now bounded to the 71 superseded versions above.

**One thing this exercise settled about sequencing.** The [[CR01]] rotation was carried out while these preview URLs were still open, which means the rotated values were published on 63 old `sender-worker` versions from the moment they were bound. That is the wrong order — **previews should have been closed first, then the credentials rotated** — and it is worth carrying into any future rotation: close every parallel surface that binds the secret before minting the replacement, or the new value inherits the old one's exposure. The receiver still sits in exactly this state today.

---

<a id="cr15"></a>

### CR15: Production `sender-worker` config drift found in the settings audit

**Priority:** P3 | **Source:** session 2026-07-27, auditing `sender-worker-dev` against production
**Estimated:** 20 minutes

Two items, both on the production worker, both surfaced by diffing it against its new dev counterpart.

**1. Workers Logs are not on — config fixed 2026-07-27, reaches production on the next `deploy:prd`.** Production `sender-worker` reports `observability.enabled: false` with `observability.logs.enabled: true`; the dev worker reports `enabled: true` for both. The cause is `wrangler.toml`: the top-level block is

```toml
[observability]
[observability.logs]
enabled = true
```

— `[observability]` declares no `enabled` key, so it deploys as `false`, while `[env.dev.observability]` sets `enabled = true` explicitly and therefore differs. A changelog entry from 2026-04-03 records "Enabled observability logs on sender-worker", which may never have taken effect. This matters beyond tidiness: diagnosing [[CR12]] and confirming [[CR03]]'s rate limiter both depend on being able to read worker logs.

**Confirmed by experiment, not inference.** A scratch deploy of `bootstrap-worker-dev` with `logs.enabled = true` and `traces.enabled = true` but no parent `enabled` reported `observability.enabled: false`; adding `enabled = true` to the parent flipped it to `true`. The child tables alone do nothing. (Experiment reverted and the worker redeployed clean.)

`sender-worker`'s config now sets `enabled = true` on the parent plus `logs` and `traces`, and `sender-worker-dev` verifies as `enabled=True logs=True invocation=True traces=True`. Production still reports `enabled: false` and will until the next `deploy:prd` — which CI runs automatically on merge to `main`.

A second gotcha found the same way: **a named environment's `observability` block replaces the parent's rather than merging.** `[env.dev.observability]` had to repeat `traces` or dev would have silently run without them while production had them. This is a third distinct inheritance behaviour, alongside the non-inheritable bindings and the inheritable `routes`/`triggers`/`preview_urls`.

**2. Four stale secrets remain bound.** Production `sender-worker` has 13 secrets. Diffing all of them against the non-test source (`env.NAME` references across the 7 files in `workers/sender-worker/src/`) shows **four are never read**:

| Secret | Why it is stale |
|---|---|
| `RECEIVER_WORKER_URL` | pre-dates the service-binding migration (`d450ef4`) |
| `PROVISIONING_RECEIVER_WORKER_URL` | same |
| `AUTH0_CLI_AUDIENCE` | not read, and not declared in the `Env` type |
| `SUPABASE_ANON_KEY` | same — the worker uses the service-role key |

**Corrected 2026-07-27:** this item previously said *two*. The count came from grepping only for the names already suspected, rather than diffing the full bound set against source. `AUTH0_CLI_AUDIENCE` and `SUPABASE_ANON_KEY` were missed. All four are inert, but each is another credential inside [[CR01]]'s blast radius, and the two URL secrets imply an HTTP path to the receiver that no longer exists. Remove with:

```bash
npx wrangler secret delete RECEIVER_WORKER_URL --name sender-worker
npx wrangler secret delete PROVISIONING_RECEIVER_WORKER_URL --name sender-worker
npx wrangler secret delete AUTH0_CLI_AUDIENCE --name sender-worker
npx wrangler secret delete SUPABASE_ANON_KEY --name sender-worker
```

**Status:** ✅ Done. **Item 1 live 2026-07-30** — production `sender-worker` reports `observability.enabled=True, logs.enabled=True, invocation_logs=True, traces.enabled=True`, ending roughly four months unmonitored; the same deploy turned observability on for `api-gateway`, `integrity-studio-contact`, and `stripe-webhook`, and the first two had **never** emitted logs or traces.

**Item 2 done 2026-07-31** — all four deleted; production `sender-worker` went **16 → 12** bound secrets. Re-verified against *current* source before deleting rather than trusting the 2026-07-27 audit, since the worker gained a password-reset path (`b22afe1`) in between: all four have zero non-test references, and none is declared in `wrangler.toml`. The only hit anywhere is `index.test.ts:2200`, which asserts `AUTH0_CLI_AUDIENCE` is *absent* — a guard that already expected this.

Verified after: `/health` 200, `/signin` still returns `401 INVALID_CREDENTIALS` on a wrong password (so `AUTH0_DOMAIN`/`AUTH0_CLIENT_ID`/`AUTH0_CLIENT_SECRET` all still resolve), and the non-secret bindings survived the four new versions — `RECEIVER` → `api-provisioning-receiver` and `RATE_LIMIT_KV` → `766332ec…` both intact. **That service binding is also the proof the two URL secrets were safe to remove**: the receiver is reached by binding, not by URL, so the deleted values had no reader by construction.

---

<a id="cr16"></a>

### CR16: Internal and customer-facing OTEL pipelines run separately — convergence is deferred, not pending

> **⚠️ Do not "de-duplicate" these.** An earlier version of this entry read the two pipelines as an accidental fork and instructed removing `handleIngestOtel` from `api-gateway`. That is wrong and would delete the **customer-facing** ingestion path. Corrected 2026-07-27 on owner clarification; see *What this entry got wrong* below.

**Priority:** P3 | **Source:** session 2026-07-27, reading both deployed scripts while analysing [[CR13]]; intent corrected by owner
**Estimated:** no work scheduled — convergence is an eventual goal, explicitly not a current priority

**Context — the split is deliberate.** Two OTEL ingestion pipelines exist because they serve **two different populations**:

| | `obtool-ingest` (observability-toolkit) | `api-gateway` (this repo) |
|---|---|---|
| **Audience** | **Integrity Studio's own internal telemetry** | **customers / end users** |
| Hostname | `ingest.integritystudio.ai/*` — attached | none — no zone route ([[CR13]]) |
| Path | `/v1/:signal` (`traces`, `metrics`, `logs`, `evaluations`), `/v1/ingest/backfill` | `/v1/ingest/otel`, `/v1/ingest/events` |
| Storage | R2 `obtool-telemetry` + D1 `obtool_telemetry_db` | Supabase `usage_events.metadata.spans` (jsonb) |
| Auth | KV `AUTH` | HMAC API key verified against Supabase |
| Dedup | KV `DEDUP` | none |
| Quota | none | per-org via `QUOTA_DO` |
| Wire format | per-signal | `{spans: [...]}`, max 1,000, custom flat `OtelSpanSchema` |

The differing auth, quota, and storage choices follow from the audience split: the customer-facing path needs per-org quota and API-key auth because it is metered and multi-tenant; the internal path does not.

**Eventual direction:** fold `obtool-ingest` into the public-facing `api-gateway`, so one pipeline serves both. This is a stated end-state, **not scheduled work** — it should not be started as cleanup, and the current two-pipeline arrangement is correct until it is.

**What this entry got wrong.** It was originally filed as an accidental duplicate, inferred from the commit trail: `obtool-ingest` and its R2 bucket were created 2026-02-24, and `/v1/ingest/otel` was added a month later on 2026-03-21 by a backlog-implementer session closing an `OTEL-1` item against the payments roadmap's "Telemetry/monitoring setup" checkbox (`1b771e3`, `c40a1c8`). The chronology is accurate; the conclusion drawn from it was not. Later-and-similar is not the same as redundant, and no amount of reading the two repos would have revealed the audience split — that is product intent, and it was not written down anywhere. Recording it here is the fix.

**Note the scope:** `/v1/ingest/events` takes `metric_key` + `quantity` and is usage metering for billing and quota — a third, separate concern from either telemetry pipeline.

**What is actually actionable now** — none of it is the pipeline split:

1. **The documented customer entry point is dead.** `docs/api-usage-ingestion.md` instructs customers to `POST https://api.integritystudio.ai/v1/ingest/events`. No deployed worker serves that path on that hostname — `obtool-api` holds the `/*` wildcard, auth-gates every `/v1/*` path before routing, and does not implement it. Now that this is confirmed customer-facing, it is a **launch blocker rather than a stale doc**: the published integration instructions cannot work.
2. **The customer-facing pipeline has never run in production.** Zero secrets since 2026-03-31 ([[CR12]]) so it cannot reach Supabase, and no zone route ([[CR13]]) so it is unreachable at a branded hostname. Both must resolve before any customer can send a span.
3. **Retention is undefined for customer span volume.** `usage_events.metadata` is `jsonb not null default '{}'`, unpartitioned, with no purge or retention job anywhere in this repo. Internal-only volume would be tolerable; customer volume accumulating indefinitely in a billing ledger table is not. Decide retention before the path is switched on, not after.

**Verified so it is not re-raised:** `rollupDailyBucket` selects only `organization_id, metric_key, quantity, latency_ms` (`aggregation.ts:45`), so stored span payloads are **not** dragged through daily aggregation.

**Status:** Not a defect — design intent, now recorded. No work scheduled on the split itself. Items 1–3 above are real and belong to [[CR12]] and [[CR13]]; this entry exists mainly so the two-pipeline arrangement is not "tidied up" by someone who finds it without the context.

**Update 2026-07-27 evening:** item 2 is half-resolved — `api-gateway` now has database access and answers healthy ([[CR12]]), so the customer-facing pipeline *can* reach Supabase. It still has no zone route ([[CR13]]) and `API_KEY_HMAC_SECRET` is unbound, so `/v1/ingest/otel` cannot authenticate a customer API key. Item 1 (the published entry point returning nothing) and item 3 (undefined retention for customer span volume) are unchanged and still gate launch.

---

<a id="cr17"></a>

### CR17: The Supabase migration ledger recorded migrations that had never run

**Priority:** P2 | **Source:** session 2026-07-27 evening, diffing local migrations against the live schema
**Estimated:** repair done; ~2 hours for the drift detector

**Context:** `supabase_migrations.schema_migrations` listed 8 of 9 local migrations as applied. Only 5 were. The ledger is what `supabase db push` consults, so the missing ones were being **skipped as already-done** on every deploy.

| Migration | Ledger said | Reality |
|---|---|---|
| `20260320010001_phase1_integrate_existing_schema` | applied | **0 of 3 unique objects existed** |
| `20260320010002_add_phase1_update_triggers` | applied | function yes, **4 triggers missing** |
| `20260321000000_add_webhook_dead_letters` | applied | **both tables missing, in every schema** |
| `20260717000000_provisioned_dashboard_viewer_default_role` | absent | partly reflected in data |

**Two root causes, both worth remembering:**

1. **`create policy if not exists` is not valid PostgreSQL.** There is no `IF NOT EXISTS` for `CREATE POLICY`. That statement sits at line 11 of `20260320010001`, so the file aborts there and everything after it silently never ran. The idempotent form is `drop policy if exists` then `create policy`, which is what the file now uses.
2. **Someone ran `supabase migration repair --status applied`.** That command writes the ledger row *including the full `statements` array read from the local file* without executing any of it — which is exactly the fingerprint observed: complete recorded SQL, zero corresponding objects. It is the natural thing to do when a push keeps failing, and it converts a loud failure into a silent one.

**Resolved:** ledger repaired with `migration repair --status reverted`, the invalid syntax fixed, and `db push --include-all` applied all three (the two out-of-order ones need `--include-all` because they sort before the last applied version). `supabase migration list` now reports 10 migrations with zero out of sync.

**Deliberately left divergent:** `20260320010002` still shows applied with 4 objects missing. Its `trigger_update_*_timestamp` triggers duplicate the `update_*_updated_at` triggers `phase1_consolidated` already installed on the same four tables; re-running it would double-fire timestamp maintenance on every row update for no benefit. Recorded here rather than forced into agreement.

**Remaining work:**
1. ✅ **Drift detector shipped.** `scripts/check-migration-drift.sh` parses every migration file for `CREATE TABLE` and `CREATE [OR REPLACE] FUNCTION` statements, queries the live database via the Supabase Management API, and reports any missing objects. Run with `npm run check:migration-drift` (needs `SUPABASE_ACCESS_TOKEN`). A `migration-drift-check` CI job runs it on every push to `main` using `DOPPLER_TOKEN` to supply the credential. Known limits: checks object *presence* only (not column types, constraints, or defaults); cannot verify DML-only migrations; skips triggers because `20260320010002`'s triggers are deliberately absent (see above).
2. **Policy on `migration repair --status applied`**: treat it as a last resort that requires a written reason committed alongside the repair. The command writes a ledger row without executing SQL — it is the correct tool for a migration that has already been applied by other means, and the wrong tool for bypassing a failing push. The two-step safe form is `--status reverted` + fix + `db push`, not `--status applied`. This is documented in `CLAUDE.md` ("Two hard-won rules") but not enforced by any tooling.
3. `20260320010002` — leaving permanently divergent (4 triggers absent, documented above). Deleting the file would remove a record of why the triggers that do exist came from `phase1_consolidated` rather than this file, which is more confusing than the divergence.

**Status:** ✅ Done — schema in sync; drift detector in CI; policy documented.

---

<a id="cr18"></a>

### CR18: Two Stripe accounts, no live secret key, and no way to complete the production webhook

**Priority:** P1 | **Source:** session 2026-07-27 evening, registering a Stripe endpoint
**Estimated:** 15 minutes once the account question is answered

**Context:** the Stripe credentials in Doppler point at **two different accounts**, and neither gives server-side live access.

| Config | `STRIPE_API_KEY` | Kind | Account |
|---|---|---|---|
| `prd` | `pk_live_…` | **publishable** (public by design) | `acct_1SN2e7AwEfePbhfk` |
| `dev` | `sk_test_…` | secret, test mode | `acct_1SN2eDBWbFuvm1I6` |
| `stg` | unset | — | — |

`STRIPE_SECRET_KEY` — the variable the code actually reads (`api-gateway/src/index.ts:21`, `sender-worker/src/types.ts:213`) — is **empty in all three configs**. `STRIPE_API_KEY` is read by no code in this repo at all; it appears only in documentation. So `sender-worker`'s `{"error":"Stripe not configured"}` on checkout is not a missing binding, it is a credential that has never existed.

Different account IDs mean these are not the test and live halves of one account — most likely one is a Stripe Sandbox, which gets its own `acct_` id. ~~That is unconfirmed.~~ **Confirmed 2026-07-28:** `acct_1SN2eDBWbFuvm1I6` reports its display name as **"Integrity Studio sandbox"**, so it is a sandbox of the same business rather than an unrelated account. Its `whsec_` belongs to `we_1Ty14zBWbFuvm1I6rvLOD5OW` (`livemode=false` → `stripe-webhook-dev`), so the dev trio is internally consistent.

**Why this blocks [[CR12]]:** a webhook signing secret is only issued when an endpoint is created, and creating a **live-mode** endpoint requires a live secret key. No live secret key exists, so production `stripe-webhook` cannot be completed. **Stripe has no API for creating secret API keys** — not via the MCP, not via curl, not via the CLI. It is a Dashboard-only action, so this needs a human once.

**Scope:**
1. **Decide which account is production.** If `acct_1SN2eDBWbFuvm1I6` is a Sandbox of `acct_1SN2e7AwEfePbhfk`, the live key comes from the same Dashboard. If they are unrelated accounts, decide which one the product bills through before minting anything.
2. Create an `sk_live_…` (or a restricted key with the needed permissions) in the Dashboard and put it in Doppler `prd` as **`STRIPE_SECRET_KEY`**, the name the code reads.
3. Register a **live-mode** endpoint at production `stripe-webhook`'s URL and bind the returned `secret` as `STRIPE_WEBHOOK_SECRET`. Use `POST /v1/webhook_endpoints` with `api_version` pinned; see [[CR20]] for what to check first.
4. **Rename `prd`'s `STRIPE_API_KEY` to `STRIPE_PUBLISHABLE_KEY`.** The generic name is what caused four documents — and a prior session — to describe it as the key in use.
5. Add the Stripe credentials to `SECRETS` in `scripts/check-env-isolation.sh` so [[CR11]]'s detector actually covers them.

**Already done (test mode only):** endpoint `we_1Ty14zBWbFuvm1I6rvLOD5OW` is registered on the sandbox account against `stripe-webhook-dev`, `api_version` pinned to `2025-09-30.clover`, subscribed to the five events the handlers implement. Its signing secret is bound to that Worker and stored in Doppler `dev`. Signature verification is proven end to end by `workers/stripe-webhook/src/webhook-signature.live.test.ts` (`npm run test:live`).

**Status:** ⚠️ Mostly resolved (2026-07-28) — the blocker cleared when a live key was minted in the Dashboard.

**Resolved:**
- **Production account is `acct_1SN2e7AwEfePbhfk`** ("Integrity Studio", US, `charges_enabled`, `payouts_enabled`). Question in scope item 1 is answered.
- `prd`'s `STRIPE_API_KEY` is now an **`rk_live_` restricted key** on that account — no longer the publishable key the table above describes. Verified against `GET /v1/account` → `200`.
- **`STRIPE_SECRET_KEY` (`prd`) now holds that same restricted key.** Chosen over the full-access `sk_live_` for least privilege; the `sk_live_` remains in Doppler secret history. Write scopes verified without creating objects (probe reaches parameter validation, which is past the permission gate): `checkout/sessions`, `billing_portal/sessions`, `webhook_endpoints`, `customers` — everything this repo exercises.
- **Live-mode endpoint registered:** `we_1Ty29dAwEfePbhfkky1OeqQu` → `https://stripe-webhook.alyshia-b38.workers.dev/webhook`, `api_version=2025-09-30.clover`, the five implemented events, `livemode=true`.
- **`STRIPE_WEBHOOK_SECRET` stored in Doppler `prd` and bound to production `stripe-webhook`.** Proven end to end with a control: correct secret → `200`, wrong secret → `401 Invalid Stripe signature`.

**Still open:**
1. ✅ **Done 2026-07-28** — `dev`'s `STRIPE_SECRET_KEY` had held a **`pk_live_` publishable key belonging to the production account** (a publishable key under a secret-key name, so every server-side call with it failed `Permission denied`). It now holds the sandbox `sk_test_` from `acct_1SN2eDBWbFuvm1I6`. **No value in Doppler `dev` references the production Stripe account any more** — verified by scanning all three `STRIPE_*` values for the production account token. Note this was a *set*, not a revert: that secret had never held the sandbox value (it went empty → `pk_live_`), and Doppler's `configs logs` rollback operates on the whole config, so it would have reverted unrelated secrets too.
2. **`STRIPE_API_KEY` and `STRIPE_SECRET_KEY` in `prd` now hold the identical value.** Scope item 4's rename is superseded: decide whether `STRIPE_API_KEY` should be dropped or repointed at the publishable key, and note that rotating one will not rotate the other.
3. ✅ **Done 2026-07-28** — `scripts/check-env-isolation.sh` now covers `STRIPE_SECRET_KEY`, `STRIPE_API_KEY`, and `STRIPE_WEBHOOK_SECRET` (13 credentials, up from 10).

   It also gained a **second, stronger assertion**, because distinctness alone would not have caught this morning's bug. `dev`'s `STRIPE_SECRET_KEY` was a `pk_live_` key on the *production* account: it differed from prd's value, so the hash table reported `ok (distinct)` while the credential pointed at production. The new section asserts key **mode** from the prefix — dev must be `_test_`, prd must be `_live_`. Mutation-checked against the real historical state (`dev=pk_live_, prd=rk_live_` → `HOLDS A LIVE KEY`), not merely written. `STRIPE_WEBHOOK_SECRET` is excluded from the mode check because `whsec_` carries no mode marker; its isolation rests on the two endpoints living on different accounts.

   The script still fails 10/13 — every Supabase and Auth0 credential plus `SHARED_SECRET` remains shared ([[CR11]]). Stripe is now the only family that passes. *(Historical: as of 2026-07-29 it fails **3 of 13** — see the CR11 updates.)*
4. ✅ **Done 2026-07-28** — `STRIPE_SECRET_KEY` is bound to both `api-gateway` and `sender-worker`. Bound with `wrangler secret put --name` from the repo root, which updates the binding without deploying code or reading `wrangler.toml`, so [[CR13]]'s route trap was not tripped (routes confirmed unchanged, both Workers `200` on `/health`). `sender-worker` verified to actually read it: `POST /create-checkout-session` moved from `{"error":"Stripe not configured"}` to `{"error":"invalid email"}`. **Note:** the binding propagates over ~seconds, and a stale instance answered `Stripe not configured` once during rollout — sample more than one request when verifying. `api-gateway`'s billing portal needs a JWT and remains unverified end to end, and is blocked behind item 5 regardless.
5. ✅ **Done 2026-07-28** — the live Customer Portal now has a configuration, `bpc_1Ty2XDAwEfePbhfk9PndBNgW` (livemode, default, active; `customer_update`, `invoice_history`, `subscription_cancel`, `subscription_update` all enabled). `GET /v1/billing_portal/configurations` returned **0** earlier the same day, which is why the call would have failed. Verified by actually creating a session — `bps_1Ty2eIAwEfePbhfk3X9kdpGu`, `livemode=true`, bound to that configuration — not by inferring it from the config's existence.

   **Do not wire the portal *login link* into `api-gateway`.** A `https://billing.stripe.com/p/login/…` URL is static and account-wide: the customer types an email and Stripe mails a magic link. `api-gateway` (`src/index.ts:161-168`) instead creates a per-customer session (`/p/session/…`, ~1h expiry) via `handleBillingPortal`, which is correct — the caller is already authenticated by JWT, so a login link would force an identity round-trip the app has already done. The login link is only useful as a standalone customer-facing entry point.

   Still unexercised: the `/v1/orgs/:id/billing-portal` route itself needs a real JWT. The Stripe half is confirmed; the auth half is not.

---

<a id="cr19"></a>

### CR19: `stripe-webhook` silently swallows out-of-order events

**Priority:** P2 | **Source:** session 2026-07-27 evening, reading the handlers against Stripe's webhook documentation
**Estimated:** 1–2 hours

**Context:** Stripe explicitly does not guarantee ordering, and documents the exact sequence you hit — `customer.subscription.created`, `invoice.created`, `invoice.paid` can arrive in any order.

Every handler resolves the org from `stripe_customer_id` and, when the lookup is empty, logs a warning and returns `{ok: true}` — `subscription.ts:32-34` and `:89-91`, `invoice.ts:17-19`, and the metadata equivalent at `checkout.ts:25-27`. Because `claimEvent` runs *before* the handler, the event is already recorded as processed. The Worker then returns 200, so Stripe never retries.

**The failure:** a `customer.subscription.updated` that overtakes the `checkout.session.completed` which would have created the org link is **permanently lost** — no dead-letter row, no retry, no error, and a log line nobody is reading ([[CR15]]). This is a silent revenue-state bug, not a cosmetic one.

**Scope:**
1. Treat "org not found" as a retryable failure so it reaches `webhook_dead_letters` instead of being claimed as done.
2. Alternatively, follow Stripe's own advice and fetch the missing object from the API rather than giving up.
3. Only release the claim on paths that genuinely did nothing — the existing `unclaimEvent` path is the right model.
4. Add a test asserting an unmatched customer does **not** leave a satisfied claim behind.

**Status:** ✅ Done (2026-07-27, commits eaaa199, 9741594) — `subscription.ts` and `invoice.ts` now return `{ ok: false }` when org-not-found, routing the event through the existing `unclaimEvent` + `addDeadLetter` path in `index.ts`. The cron retries up to 5 times, then abandons the row. The **real** retry window is set by the `*/15` cron, not by the backoff: `failDeadLetter` writes delays of 1, 2, 4, and 8 minutes (`2^retry_count`, and the 16-minute interval is never written because `newCount >= maxRetries` abandons first), every one of which is shorter than the cron gap. So the five attempts land on five consecutive ticks — roughly **60–75 minutes** of wall-clock, not the ~16 minutes of nominal backoff. Beyond that the event is `abandoned` and only a manual replay recovers it. `checkout.ts` is unchanged — missing `org_id` in metadata means the checkout is not from this system, so `{ ok: true }` (no-op) remains correct. Four handler tests updated; one integration test added in `index.test.ts` asserting `unclaimEvent` and `addDeadLetter` are called on org-not-found. 151 tests passing.

**Two consequences of the fix, neither blocking:**
- A Stripe customer that legitimately maps to no org — a subscription created by hand in the Dashboard, say — now produces a dead-letter row that retries five times and is then `abandoned`, where it used to be a silent no-op. That is the correct trade (visible beats silent), but it means `webhook_dead_letters` will accumulate rows that no amount of retrying can fix.
- **This fix makes [[CR20]] more load-bearing, not less.** The Worker still returns 200 on the dead-letter path (`index.ts:129`), so recovery depends entirely on the `*/15` cron — which is still unmonitored. Out-of-order events are no longer *lost*, but nothing yet alerts when one is `abandoned`. Option 2 in the scope above (fetch the missing object from the Stripe API instead of deferring to the cron) would remove that dependency and is worth revisiting once [[CR18]] gives the Worker a usable secret key.

---

<a id="cr20"></a>

### CR20: `stripe-webhook` discards Stripe's 3-day retry in favour of a cron

**Priority:** P2 | **Source:** session 2026-07-27 evening, reading the handlers against Stripe's webhook documentation
**Estimated:** 2–3 hours, mostly deciding

**Context:** on handler failure the Worker writes a dead-letter row and returns **200**, with the comment "Return 200 to suppress Stripe's built-in retry (we own the retry schedule)". Stripe would otherwise retry for **three days with exponential backoff** in live mode. That is a real guarantee being traded away for a `*/15` cron.

The trade is only sound if the replacement works, and for four months it did not: the Worker had zero secrets ([[CR12]]) and its dead-letter table did not exist ([[CR17]]). Had an endpoint been registered, a failing event would have been claimed, unclaimed, failed its dead-letter insert, returned 200, and vanished — with Stripe explicitly instructed not to retry.

Both underlying faults are now fixed, so the cron can function. The design question stands.

> **⚠️ Update 2026-07-29 — [[CR21]]'s implementation (commit 8de2122) forecloses scope item 1.** `handleWebhook` now returns 200 *before* the handler runs (`ctx.waitUntil`), so returning 5xx on handler failure is structurally impossible without reverting CR21. The decision has effectively been made by implementation: the cron is the only retry path, which converts item 2 (alerting, [[W04]]) from an option into the sole remaining mitigation.
>
> The same commit also removed the last 5xx anywhere in the failure chain. Previously, if the **dead-letter insert itself** failed after a handler failure, the Worker returned 500 and Stripe retried for three days — the last-resort safety net, and free alerting via Stripe's failing-endpoint emails. Now that path logs `CRITICAL … Manual replay required` and nothing else. This exact failure mode has a precedent: [[CR17]]'s missing `webhook_dead_letters` table made every dead-letter insert fail for four months. A recurrence now loses events behind 200s, observable only in Worker logs. A **full** Supabase outage is still protected — the synchronous `claimEvent` fails first and returns 500 before the 200 is sent. The narrowed window is *partial* DB failure: claim succeeds, handler fails, dead-letter insert fails.

**Scope:**
1. ~~Decide whether owning the retry schedule is worth it. Returning 5xx and letting Stripe retry for three days is simpler, needs no cron, and no table.~~ Foreclosed by [[CR21]] — see update above.
2. Alert on dead-letter depth and on cron failure ([[W04]] step 2 already lists this). **Now mandatory, not optional** — it is the only recovery signal left.
3. Note sandbox retries are only 3 attempts over a few hours, so testing there understates live behaviour.
4. ✅ **Done 2026-07-31 — the cron runs, succeeds, and has now been proven on real dead letters.** It reached that state the hard way on the same day, and the intermediate finding is the one worth keeping: for four months it reported success while doing nothing at all. "It is invoked", "its query succeeds", and "recovery works" are three different claims, and only the first two held until [[CR27]] forced the third.

   **It runs.** `GET /workers/scripts/stripe-webhook/schedules` reports `*/15 * * * *`, created 2026-03-31. Workers Logs shows invocations at exact quarter-hour offsets (`:00:58`, `:15:58`, `:30:58`, `:45:58`) — 20 of 20 events sampled over six hours were cron fires, with no `/webhook` traffic at all, consistent with Stripe having sent nothing yet. GraphQL `workersInvocationsAdaptive` reports `status: success`, `errors: 0` for every day sampled, and a filtered log query returns **0 error and 0 warn events across three days**. That last one is load-bearing rather than decorative: `fetchPendingDeadLetters` logs `console.error` on a DB failure and `runReconciliation` logs on every other failure path, so silence is positive evidence, not absence of instrumentation.

   **The `subrequests` column dates the fix precisely.** Before 2026-07-28 the Worker ran ~96×/day with **zero subrequests** — it never reached Supabase, because `createSupabaseAdmin(undefined, undefined)` threw inside the client and `fetchPendingDeadLetters` swallowed it into `[]`. From 2026-07-28 the ratio climbs to 1.00 subrequest per invocation, which is the dead-letter query actually executing.

   | Date | Invocations | Errors | Subrequests | Ratio |
   |---|---|---|---|---|
   | 2026-07-20 → 07-27 | 91–102/day | 0 | **0** | 0.00 |
   | 2026-07-28 | 101 | 0 | 86 | 0.85 |
   | 2026-07-29 | 97 | 0 | 90 | 0.93 |
   | 2026-07-30 | 99 | 0 | 94 | 0.95 |

   **⚠️ It reported `status: success` throughout the broken period.** ~96 invocations a day for four months, every one recorded successful while making zero outbound calls. **An error-rate alert would never have fired**, which is the single most important input to [[W04]] step 2: the signal that would have caught this is *subrequest count* or *dead-letter queue depth*, not error rate. Do not build the alert on errors alone.

   **What was still unproven when measured — and was answered hours later by [[CR27]].** At the time of this check `webhook_dead_letters` held **0 rows** and `webhook_events_log` held **1** (the synthetic 2026-07-28 probe), so the cron had only ever executed its empty-queue path: fetch, find nothing, exit. The conclusion drawn here was that "the cron works" meant "the query succeeds", not "recovery works".

   **That gap closed the same day, and in the worst possible way — which is the vindication of this entry.** The first real Stripe subscription traffic this account has ever seen arrived on 2026-07-31 and **all three events dead-lettered** on two independent handler defects ([[CR27]]). So the retry path went from never-exercised to load-bearing within hours. It then worked: after the fixes, the abandoned rows were reset and the `*/15` cron drained both `invoice.paid` events at 05:00:59 and 05:01:00, taking `webhook_events_log` from 1 → 3. Recovery is therefore now proven on real payloads rather than inferred.

   The sequence is the lesson. An empty queue read as "healthy" when it actually meant "untested", and the very first production event exposed two four-month-old defects that no unit test, deploy check, or `status: success` had caught.

**Status:** ⚠️ Partial — step 4 done 2026-07-31 (above). No longer a design decision: [[CR21]] committed to the cron and that commitment is live. Remaining work is monitoring ([[W04]] steps 2–4), now with a concrete requirement — alert on **queue depth and subrequest count**, because four months of silent no-ops proved error rate alone is blind to this failure.

---

<a id="cr21"></a>

### CR21: `stripe-webhook` processes synchronously before responding

**Priority:** P3 | **Source:** session 2026-07-27 evening, reading the handlers against Stripe's webhook documentation
**Estimated:** 1 hour

**Context:** Stripe's guidance is to return `2xx` **before** any complex logic, and it warns specifically about spikes when subscriptions renew at the start of a month. `handleWebhook` was doing the full Supabase round trip — claim, handler, and possibly a dead-letter write — before responding.

Severity is limited by the atomic claim: a timeout followed by a Stripe retry hits `already_processed` and returns 200, so it degrades to noise and failed-delivery records rather than double-processing. `ctx.waitUntil()` is the Workers-native fix, and the pattern is already used elsewhere in this codebase (M40's audit-log write).

**Status:** ✅ Done (2026-07-29, commit 8de2122) — handler logic extracted into `processEvent`; `handleWebhook` now atomically claims the event, returns `200 { ok: true, queued: true }` immediately, then runs `ctx.waitUntil(processEvent(...))`. The dead-letter CRITICAL path no longer returns 500 (the response is already sent by then; manual Stripe replay is the only recovery). 152 tests passing.

**✅ Actually live since 2026-07-30, and it was not before.** This entry was marked done on 2026-07-29, but production `stripe-webhook` had last shipped code on 2026-07-28 — so the fix sat undeployed for a day while the backlog read as complete. Confirmed after deploying by fetching the live bundle (`GET .../scripts/stripe-webhook/content/v2`) and finding `waitUntil`, `queued`, and `Manual replay required` present, with the stale `Failed to log processed event` string from the 2026-03-31 build absent. **Worth generalising: "commit merged" and "behaviour live" are different claims, and this file has now conflated them twice** (see the audit note at the head of Phase 4).

---

<a id="cr22"></a>

### CR22: The billing-portal API-key 403 — deployed 2026-07-30, but still not exercisable

**Priority:** P3 | **Source:** session 2026-07-27 late, follow-up to the `handleBillingPortal` auth change
**Estimated:** 15 minutes

**Context:** `handleBillingPortal` (`workers/api-gateway/src/routes/orgs.ts`) now rejects `int_live_…` bearer tokens with `403 "Billing portal requires a user session; API keys are not accepted"` instead of letting them fall through to `resolveJwt` and return an opaque `401`. Typecheck is clean and the worker suite passes 147/147, including a new case in `orgs.test.ts`.

Nothing is deployed. `api-gateway` deploys are manual (see [[CR02]]) and there are dev/prod variants, so the fix reaches production only when someone runs the deploy — and doing that here trips the hazard already recorded at the head of this section: **`deploy:prd` in `workers/api-gateway` must wait for [[CR13]] step 1**, or its `routes` key captures all of `/v1/*` from `obtool-api`. So this is blocked on CR13, not merely unscheduled.

Note the user-visible effect is currently nil either way: the portal cannot work at all until `STRIPE_SECRET_KEY` is bound ([[CR18]], [[CR12]]), and API-key routes are dead while `API_KEY_HMAC_SECRET` is unbound — meaning **no caller can reach the new 403 in production today**. This is a correctness improvement waiting behind the same credential work.

**Status:** ⚠️ Deployed but still unexercised (2026-07-30) — the manual `npm run deploy:prd` has been run; `api-gateway` is version `9c4e7c61` and the deployed bundle contains the billing-portal code. **What is still unproven is the 403 itself**, and the reason is worth recording rather than retrying: the 403 fires only for a credential that *authenticates* as an API key and then fails the type check, so it requires a valid HMAC-verified key. API-key auth is unreachable while `API_KEY_HMAC_SECRET` is unbound ([[CR12]]), so the path cannot be reached at all today. A probe with a fabricated key returns `401 {"error":{"message":"Invalid JWT format"}}`, which is [[CR23]]'s deliberate two-tier split working correctly — **do not read that 401 as this fix having failed.**

---

<a id="cr23"></a>

### CR23: Revoked and expired API keys still get a 401 from the billing-portal route

**Priority:** P3 | **Source:** session 2026-07-27 late, reviewing the CR22 change
**Estimated:** 1 hour, mostly a decision

**Context:** The new 403 only fires for API keys that are *valid*. Every `/v1/orgs/:id/*` request first passes through `preVerifyToken` (`workers/api-gateway/src/lib/helpers.ts`), which HMAC-verifies key-shaped tokens against the database and returns `401` for anything revoked, expired, or unknown. A revoked key therefore never reaches `handleBillingPortal`, so the response to a key-shaped token depends on the key's *state*: valid → `403` "API keys are not accepted", revoked → `401`.

That split is arguably correct — the token genuinely is invalid — but it means a client cannot distinguish "my key is bad" from "keys are the wrong credential for this route" without knowing its own key is good. If a uniform answer is wanted for all key-shaped tokens, the check has to move ahead of the HMAC verification in `preVerifyToken` (or be duplicated there per-route), which is a larger change than the one-route guard in [[CR22]] and touches every org route's auth ordering.

**Scope:** decide whether response shape should key off credential *type* before credential *validity*; if yes, hoist the type check into `preVerifyToken` with a per-route allowlist and re-verify the ordering assumptions in `orgs.test.ts`, `usage.test.ts`, and `ingest.test.ts`.

**Status:** ✅ Resolved by design decision (2026-07-29) — the two-tier split is correct per HTTP semantics. `401` signals an authentication failure (the presented credentials are invalid, regardless of what type they are); `403` signals an authorization failure (the credentials are valid but insufficient for this operation). Hoisting the type check before the HMAC verification would require a per-route allowlist inside `preVerifyToken`, touching every org route's auth ordering — a non-trivial refactor with no user-visible benefit while API-key auth routes are broken ([[CR12]]). No code change. Re-evaluate if a client that cannot distinguish the two cases is reported as a real issue in production.

---

<a id="cr25"></a>

### CR25: Auth0 tenant production-readiness (before flipping `dev-68gg87ow4mg4kzyo` to Production)

**Priority:** P2 | **Source:** session 2026-07-29, Management API audit of tenant `dev-68gg87ow4mg4kzyo`
**Estimated:** the two remaining hard blockers are **spend decisions** (breached-password, custom domain); three are **config, minutes by API** (branding, log streams, implicit/ROPC grants); one is an **owner decision** (MFA enforcement).

**Status (audited live 2026-08-03, branding fixed same day):** ⚠️ **Open — 8 of 13 items done, 5 open; no active security finding remains.** Done: item 1 (Google dev-keys disabled), **5 (branding — set from real repo assets 2026-08-03)**, 9 (`Default App` grants stripped), 10 (token 24h→8h), 11 (dev clients OIDC-conformant), 12 (3 stale Doppler slots deleted), and the former 🔴 `integrity-dev-m2m` finding (deleted in CR11's Auth0 cutover — the last credential able to delete production users; confirmed 404). **Open, each re-verified against the tenant today — and two were re-classified by measurement, not left at the label:**
| # | Item | Kind | Live check |
|---|---|---|---|
| 7 | `implicit` grant on the SPA | config, minutes | still on `integritystudio-dashboard`, `My App` |
| 8 | ROPC on SPA + `AUTH0_MANAGER` | config, minutes | still on `AUTH0_MANAGER`, `integritystudio-dashboard`, `My App` |
| 2 | MFA enforcement | owner **decision** | factors available; `GET /guardian/policies` → `[]` (not required) |
| 3 | breached-password detection | 🔴 **spend** (paid plan) | `enabled:false`, PATCH 400 "upgrade your subscription" |
| 4 | custom domain | **owner decision + DNS** (NOT spend) | `POST /custom-domains` → 400 payload-validation, not 403 — plan allows it; needs a hostname choice + DNS + permanence |
| 6 | log streams | **needs a receiver** (NOT config-minutes) | no sink parses Auth0's format; OTLP ingest would reject every batch |

Only items 7 and 8 are the "minutes-by-API" kind now; the rest each need a decision, spend, or build.

Not counted as a CR25 blocker but adjacent: **item 10's real end state (1h token) is blocked on client refresh-token work**, which is application code, not Auth0 config.

The Dashboard's production-checks page (`manage.auth0.com/dashboard/us/dev-68gg87ow4mg4kzyo/production-checks`) **cannot be read programmatically** — it is behind an interactive login and `WebFetch` gets redirected to `auth0.auth0.com/authorize`. Everything below was therefore checked against the Management API directly, which is the authoritative source anyway.

**🔴 Blockers**

1. ✅ **FIXED 2026-07-29 — the Google connection ran on Auth0 development keys.** `con_ObPVzoOXoF6DWEtA` (`google-oauth2`) had no `options.client_id` or `options.client_secret`, so it used Auth0's shared, Auth0-owned Google application: heavily rate-limited, with a consent screen showing Auth0's name rather than Integrity Studio's. It was **enabled on 6 applications** while **no one used it** — all 96 identities in the tenant are database (`auth0`) identities, zero `google-oauth2`. **Fix applied:** disabled for every application via `PATCH /api/v2/connections/{id}/clients` with `status:false` (→ 204), verified `0` clients enabled, so Google cannot appear on any login page. The connection object was **deliberately kept, not deleted**, so it is one PATCH to restore once real Google Cloud OAuth credentials exist — at which point set `options.client_id`/`client_secret` *before* re-enabling.
2. ⚠️ **PARTIALLY FIXED 2026-07-29 — MFA factors are now available, enforcement is still an open decision.** Every factor had been disabled (`GET /api/v2/guardian/factors`) even though both database connections have `options.mfa.active: true`, so no second factor could be enrolled by anyone — on a system that mints customer API keys. **Fix applied:** enabled `otp` (authenticator app) and `recovery-code`. **`GET /api/v2/guardian/policies` was deliberately left `[]`**, which means MFA is now *available for enrolment* but is not *required* of anyone. Turning on enforcement would force all 96 existing users to enrol at their next login — a user-visible change that needs an explicit decision, and the remaining work on this row. Consider requiring it for administrators only rather than tenant-wide.
3. 🔴 **NOT FIXABLE ON THIS PLAN — breached-password detection is gated behind a paid subscription.** *Correcting this item's original wording, which called it "a single PATCH" and free: it is neither.* `PATCH /api/v2/attack-protection/breached-password-detection` returns **HTTP 400 `"Please upgrade your subscription to enforce breached password detection"`**, and `GET` confirms it stayed `enabled: false`. It therefore joins the custom domain as a **spend decision**, not a configuration one. The two attack-protection features that *are* included remain on and were re-verified: brute-force protection (`block`, `user_notification`) and suspicious-IP throttling (`admin_notification`, `block`).

**Verified after applying the above:** production database login is unaffected — `/signin` 200 with an 855-char JWT and `/send` `ok:true` with real user and org data — the dev-tenant isolation still holds (dev client authenticates the dev user), and all four Workers are healthy.

**Correction to the [[CR11]] auto-enable note:** that entry attributed the surprise client-enablement to `is_domain_connection: true`. That explanation is wrong. The Google connection has `is_domain_connection: false` and **both** `integrity-dev-ropc` and `integrity-dev-m2m` had been auto-enabled on it as well. So Auth0 enables newly created clients on existing connections **regardless** of the domain-connection flag. The operational rule is broader than first written: **after creating any client, audit every connection's client list, not just the domain ones.**

**⚠️ Should fix — user-visible or hygiene**

4. **No custom domain — and NOT plan-gated, corrected 2026-08-03.** `GET /api/v2/custom-domains` is empty; every login happens on `dev-68gg87ow4mg4kzyo.us.auth0.com` (users see a "dev-" hostname). ~~Custom domains are a paid-plan feature, so this is a spend decision.~~ **Measured, not assumed:** `POST /api/v2/custom-domains` returns **400 payload-validation** (missing `type`/`domain`), not the 403 a plan-gated endpoint returns — so this tenant CAN create one. But it is still not something to toggle unilaterally: it needs (a) an **owner decision** on the hostname (e.g. `auth.integritystudio.ai`), (b) DNS records added + verification, and (c) it makes the tenant **permanent** (moving later invalidates sessions and bookmarks). So: owner decision + DNS, not spend and not a blind config toggle. DNS is settable from here (porkbun/Cloudflare MCP), so once the hostname is chosen this is completable.
5. ✅ **FIXED 2026-08-03 — Universal Login branded from real repo assets.** Was `{logo_url: ""}`, no colors. `PATCH /api/v2/branding` set `logo_url` = `https://integritystudio.ai/images/logo.png` and `favicon_url` = `.../icons/favicon-32x32.png` (both live, HTTP 200 on the `.ai` apex — the `.dev` host 404s, so the apex is deliberate), and colors `primary #3B82F6` (theme `blue500`) + `page_background #111827` (theme `gray900`, the app's dark background). Verified by read-back. Reversible: `PATCH` the fields back to `""`/absent.
6. **No log streams — blocked on a receiver, NOT config-minutes (corrected 2026-08-03).** Auth logs are exported nowhere and retention is plan-limited. ~~Worth pairing with [[W04]] — the repo already runs an OTEL pipeline that could ingest them.~~ **That pairing does not work as written:** an Auth0 `http` log stream POSTs **Auth0 log-event JSON**, and the OTLP ingest worker only accepts OTLP on `/v1/:signal` (plus backfill/evaluations) — it would reject every batch, so the stream would just accumulate delivery failures and auto-disable. There are also no Datadog/Splunk credentials in Doppler. So this needs a **purpose-built receiver first** (an endpoint that accepts Auth0's format and forwards to the pipeline) or a sink credential — real work, not a toggle. Do not create a stream pointing at the OTLP endpoint.
7. **`implicit` grant is enabled on 4 applications, including the `integritystudio-dashboard` SPA.** Implicit returns tokens in the URL fragment, which is the same mechanism [[CR04]] already tracks. The SPA should be `authorization_code` + PKCE only. (Refresh-token rotation *is* correctly enabled on that SPA.)
8. **ROPC (`password`) grant on 4 applications** — including the SPA, where ROPC on a public client is at its worst, and `AUTH0_MANAGER`, the Management API M2M, which can therefore authenticate end users as well as act as a machine client.
9. ✅ **FIXED 2026-07-31 — `Default App`'s grants stripped.** It was an unused privileged leftover: `authorization_code` + `implicit` + `client_credentials`, `is_first_party: true`, and refresh tokens configured `non-rotating` + `non-expiring` with `infinite_token_lifetime`. Confirmed orphaned before touching it — zero matches across **170 `prd` slots, 227 `dev` slots, and the whole repo** — and it had no callback URLs, so only `client_credentials` was actually reachable. **Grants set to `[]`** (Auth0 accepts an empty array) and verified by trying to use it: `client_credentials` with its own valid secret now returns `unauthorized_client — Grant type 'client_credentials' not allowed for the client`. **Stripped rather than deleted, deliberately** — same security outcome, but reversible; deleting an Auth0 client is not. To restore, PATCH `grant_types` back to `["authorization_code","implicit","refresh_token","client_credentials"]`.
10. ✅ **FIXED 2026-07-31 — token lifetime 24h → 8h**, on resource server `69c4e28bf801eab9e683c85a` (`https://api.integritystudio.dev`). Verified on a freshly minted token: `exp - iat = 28800`. `token_lifetime_for_web` left at 7200, already tighter.

    **Why 8 hours and not 1.** The obvious fix is 3600, and it would have been wrong here. **The Flutter app has no refresh mechanism at all** — `lib/` contains zero references to `refresh_token`, `refreshToken`, `expires_in`, or `expiresIn`; `auth_storage_web.dart` puts the raw JWT in `localStorage` and reads it back until it expires. A 1-hour token would therefore log users out hourly with no automatic recovery, trading a real usability regression for the last increment of exposure. 8h cuts the window by a third of a day while still spanning a working session. **1h is the right end state, but it needs a refresh-token flow in the client first** — that is application work, not a config change, and is the real prerequisite hiding behind this row.

**🧹 Cleanup created by this session's own work (see [[CR11]])**

11. ✅ **FIXED 2026-07-31.** Both dev clients now report `oidc_conformant: true` and `jwt_configuration.alg: RS256` (were `false` / `None`, which enables legacy behaviours), and the `dev-users` connection is `disable_signup: true`.

    Verified against a **baseline taken before the change**, since making a ROPC client OIDC-conformant alters how `/oauth/token` behaves: the dev `password-realm` grant returned `invalid_grant — Wrong email or password` both before and after, i.e. it still reaches the credential check rather than failing at client auth or grant negotiation. A deliberately wrong password was used, so nothing was authenticated. Dev M2M `client_credentials` still issues a token; production `/signin` still returns `401 INVALID_CREDENTIALS`.

**🧹 Stale Doppler slots found while auditing**

12. ✅ **FIXED 2026-07-31 — all three deleted, from `dev` as well as `prd`** (the audit had only noted `prd`; all three existed in both). Each was proved dead before deletion rather than assumed:

    | Slot | Evidence it was dead |
    |---|---|
    | `AUTH0_API_ID` (`692aa7e8…`) | `GET /resource-servers/{id}` → **404** |
    | `AUTH0_API_GRANT_DI` (`cgr_sbgg64d2NeNQDpwi`) | `GET /client-grants/{id}` → **404**, and absent from all **15** live grants |
    | `VITE_AUTH0_CLIENT_SECRET` | Neither copy matches the live SPA secret (`prd` sha `46bcfda1c065`, `dev` sha `85a195b76b0b`, live `f72ddb2d6406`) — and the client is `token_endpoint_auth_method: none`, so a secret is meaningless there regardless |

    The third check was the one worth doing. Clearing a slot that holds a *live* credential destroys the last readable copy while leaving the credential valid — the trap recorded under [[CR01]]'s `AUTH0_CLI_SECRET` mishap ("a Doppler slot plus a write-only binding is *one* copy, not two"). Comparing against the live value first is what made deletion safe rather than lucky. Zero repo references for all three; Auth0 `client_credentials` and all four Workers verified healthy afterwards.

**✅ RESOLVED 2026-08-03 — the credential was deleted.** `integrity-dev-m2m` (`Yd9s7…`) is gone from the production tenant (confirmed 404), removed as part of CR11's Auth0 dev-tenant cutover: `dev`'s `AUTH0_CLI_*` now map to an M2M in the **separate** dev tenant `dev-njjmghdzm23uy0p7`, so no `dev` credential holds a grant against the production tenant's 95 users. ~~**🔴 New finding 2026-07-31 — Doppler `dev` holds a credential that can delete production users.** Found while re-verifying item 11.~~ `dev AUTH0_CLI_ID`/`AUTH0_CLI_SECRET` map to `integrity-dev-m2m`, which now has a live Management API grant (`cgr_xT15sUo6UEAWZeul` → `/api/v2/`) carrying **`read:users` and `delete:users`** on tenant `dev-68gg87ow4mg4kzyo` — the tenant holding all 96 real users. Confirmed by use, not by reading the grant list: the token lists users at `GET /api/v2/users` → **200**.

This **contradicts [[CR01]]'s verification note**, which recorded "`dev` credential still `access_denied`". That was true when written; a grant has been added since. Two things follow. It is probably *intentional* — `sender-worker`'s `test:live` suite deletes the user at `AUTH0_TEST_EMAIL`, which needs exactly `delete:users` — so this is likely test-cleanup tooling rather than an accident, and it was left in place rather than revoked unilaterally. But it is a direct counterexample to [[CR11]]'s framing: the `dev` config is not merely *non-isolated* from production, it holds a credential that can destroy production identity data. Decide whether the live-test cleanup justifies `delete:users` on the production tenant, or whether that suite should move to the second tenant that already exists.

**Observation, not a finding:** two applications present earlier in this same session — `My App (Web)` and `My App (SPA)` — no longer exist in the tenant (the total is still 8 because two dev clients were added). No Doppler client ID referenced either, so nothing broke; `VITE_AUTH0_CLIENT_ID` maps to the surviving `integritystudio-dashboard` SPA and `prd AUTH0_CLIENT_ID` to `My App`.

**Already production-appropriate:** the email provider is **Resend and enabled** (not Auth0's test provider — this is the item that most often blocks a production switch, and it is done); `support_email` and `support_url` are set; the single Action runs on **node22** with zero deprecated Rules; both database connections use password policy `good` with brute-force protection on; the custom API enforces RBAC.

---

<a id="cr26"></a>

### CR26: The signup `bootstrap` call has no server-side route — `bootstrap-worker` was never deployed

**Priority:** P1 | **Source:** session 2026-07-30, found while fixing the dashboard CORS/auth failure
**Estimated:** 30 minutes for the route mount; the topology choice is the real work

**Context:** `ProvisioningService.bootstrap` (`lib/services/provisioning_service.dart:461`) posts to **`$_apiGatewayUrl/bootstrap`** — that is, to `api-gateway`, the same host as every `/v1/*` call. `api-gateway` has no `/bootstrap` route, so the request falls through to the terminal `notFound` handler. Verified against production with a real login token:

```
POST https://api-gateway.alyshia-b38.workers.dev/bootstrap  ->  404 {"error":{"message":"Not found"}}
```

The implementation exists, but in a **different Worker that has never been deployed**: `wrangler secret list` for `bootstrap-worker` returns `Worker "bootstrap-worker" not found`, and `bootstrap-worker.alyshia-b38.workers.dev/health` answers 404 (no Worker on that hostname). So `provision_page.dart`'s org-context card — the screen a user lands on immediately after signing up — cannot ever have loaded. This is pre-launch breakage, not a regression; nothing was lost.

**Two defects were fixed in `bootstrap-worker`'s source in the same session, so whenever it does deploy it is correct:**

1. It verified tokens with `supabaseJwtKey(...)` while the client sends an **Auth0** RS256 token — the identical mismatch fixed in `api-gateway` (see below). Now uses `auth0JwtKey` + `auth0IssuerFor`, and validates `iss`/`aud`, which it did not do at all before (it passed no options to `verifyJwt`).
2. It passed the JWT `sub` straight into `loadOrgContext`, which filters `organization_memberships.user_id` — a uuid column. Now resolves through `users.auth0_id` first via a new `resolveUserId`.

`AUTH0_DOMAIN`/`AUTH0_AUDIENCE` were added to its `wrangler.toml` as plain `vars` (both appear in every JWT, so neither is confidential), repeated under `[env.dev.vars]` because `vars` is not inherited by a named environment.

**The decision, not just the fix.** There are two ways to close this and they are not equivalent:

- **Mount the handler in `api-gateway` at `/bootstrap`** — matches the contract the shipped Flutter app already assumes, needs no client release, and adds no Worker to operate. Costs: `api-gateway` grows a non-`/v1` route, and `bootstrap-worker` becomes dead code to delete.
- **Deploy `bootstrap-worker` and repoint the client** — keeps the separation, but requires a Flutter release plus a new hostname to configure, and the shipped app in users' browsers keeps calling the gateway until they reload.

The first is almost certainly right, but it is a production topology change adjacent to [[CR13]]'s unresolved question about what serves `api.integritystudio.ai/v1/*`, so it was deliberately **not** done unilaterally.

**Scope:**
1. Pick one of the two options above.
2. If mounting: move `loadOrgContext`/`buildBootstrapResponse`/`resolveUserId` into `api-gateway`, add `POST /bootstrap` ahead of the terminal 404, and delete `bootstrap-worker`. Its 10 tests should move with it.
3. Either way, confirm the signup → provision flow end to end with a real Auth0 token, which nothing has ever done.

**Related dashboard fix, deployed 2026-07-30 (context for the above).** The login → dashboard path was broken by three stacked defects in `api-gateway`, all now fixed and live (version `524274de`):

| # | Defect | Symptom |
|---|---|---|
| 1 | No CORS handling whatsoever — no `OPTIONS` branch, no `Access-Control-Allow-Origin` on any response | Browser blocked every `/v1/*` call from `integritystudio.ai`; preflight 404'd |
| 2 | Verified **Supabase** JWKS against an **Auth0** RS256 token | `401 Invalid JWT signature` |
| 3 | `auth.sub` (an Auth0 subject) passed into `organization_memberships.user_id` (uuid) filters | PostgREST 400, swallowed by `loadUserMemberships` into `[]` → an **empty dashboard**, not an error |

Defect 3 is the one worth remembering: fixing 2 without it would have looked like success and shipped a blank dashboard. `users.auth0_id` and `users.id` are two different keys and the codebase used `sub` for both — `me.ts`/`api-keys.ts` correctly filtered `auth0_id`, while `orgs.ts`/`usage.ts`/`ingest.ts` filtered `user_id`. All now resolve through `resolveUserId`, and `AuthResult`'s jwt branch carries both `sub` and `userId` so the two cannot be confused again. CORS is applied at a single outer boundary in `fetch` so a route added later cannot ship without it. Verified: all seven dashboard endpoints return 200 with a real login token; a forged token 401s; 926 tests pass across all six Workers with clean typechecks.

*Two operational notes from that session.* Each deploy produced ~60s of mixed old/new responses (a stale preflight 404, then intermittent 401s) before settling — **deploy propagation, not a bug**; confirmed by 20/20 clean probes afterwards with nothing in `wrangler tail`. And the route tests previously minted HS256 tokens against a shared secret, which Auth0 verification cannot accept; they now use `workers/lib/test-helpers/auth0-jwt-stub.ts`, which generates a throwaway RSA keypair and serves the matching JWKS through the fetch stub, so the suite drives the real path (kid lookup → JWKS fetch → RS256 verify → `iss`/`aud`) instead of mocking past it.

**Status:** ✅ Done and **live** (2026-07-30, version `846f8c21`) — `POST /bootstrap` mounted in `api-gateway`; `bootstrap-worker` deleted. Verified against production with a real login token: 200 with the caller's orgs, `user.id`/`user.email` matching `GET /v1/me` exactly, and a foreign `x-org-id` ignored rather than honoured.

**Five follow-ups found while reviewing the ported handler, all fixed:**

1. **`user.email` was permanently blank.** It was read from the JWT, but an Auth0 *access* token for a custom audience carries no `email` claim even with `email` in scope — decoding a live token gives `aud, azp, exp, gty, iat, iss, permissions, scope, sub`. The covering test signed a token *containing* an email claim, so it passed against a token Auth0 never issues. Both `id` and `email` now come from the users row `resolveUserId` already reads (no extra query).
2. **`user.id` was the Auth0 sub while `/v1/me` returns `users.id`** — two endpoints describing one user disagreeing about what `id` means, which is the same conflation that caused the empty-dashboard bug. Now consistent.
3. **`x-org-id` had no access-control test.** The header is caller-controlled; it is only honoured when it names an org the caller belongs to. That held already, but nothing pinned it, so a refactor trusting the header would have passed the suite. Now asserted that a foreign id is neither active nor listed, never reaches the database as a filter value, and does not scope the entitlements or usage queries.
4. **Month-to-date used a local-time date constructor.** `new Date(y, m, 1).toISOString()` reads its arguments as local time, so in any zone *ahead* of UTC it renders as the previous month's last day and sweeps that day's buckets into the total. Workers run in UTC so production was unaffected; any developer machine east of UTC saw inflated usage. **Note the direction — an earlier draft of this said "west of UTC", which is wrong**, and the first test written for it used `America/Los_Angeles` and therefore passed against the unfixed code. It now runs under `Asia/Tokyo`, where the old form yields `gte.2026-06-30` against the expected `gte.2026-07-01`; confirmed by reverting the fix and watching it fail.
5. **A failed usage aggregate was indistinguishable from genuine zero.** The snapshot now carries `unavailable: true` on that path. The request still returns 200 — usage is decoration on the post-signup screen and failing the whole bootstrap over it would be worse. Additive field; the Dart client sets no `disallowUnrecognizedKeys`.

**The quota asymmetry, and a correction.** This entry originally noted that `/bootstrap` runs several database queries with no quota enforcement "unlike the `/v1/orgs/*` routes it sits beside". That framing was wrong twice over: `enforceOrgQuota` only guards `/v1/orgs/:id/*`, so `/bootstrap`'s actual peers — `/v1/me` and `/v1/orgs` — were **equally** unmetered; and quota is the wrong instrument regardless. It is org-scoped billing metering, `/bootstrap` is the call that *tells* the client which orgs exist, and metering it against an org would let a billing state block sign-in and onboarding.

The real gap was that no identity-scoped route had any abuse protection. Closed with a **per-identity throttle** (`api-gateway/src/lib/rate-limit.ts`), applied uniformly to `/v1/me`, `/v1/orgs` and `/bootstrap` so protecting one does not just relocate the asymmetry. It mirrors `sender-worker`'s two-tier limiter (in-memory + KV) with two differences: keyed on the **verified** JWT subject rather than client IP — precise for authenticated callers, where IP would over-count a shared NAT and under-count one account across addresses, and limiting on an *unverified* claim would let a caller mint a fresh subject per request to walk past it — and it runs before the handler's database work, so a throttled caller costs one cached signature check and nothing else (asserted: zero database calls once throttled). A KV outage is **not** fail-open; the in-memory tier has already counted the request. `RATE_LIMIT_KV` is now bound (shared namespace with `sender-worker`, keys prefixed `gw_id_rl:`).

**6. ✅ `current_minute_remaining` removed from both sides (2026-07-30, version `9f483435`).** The Dart model declared it as a non-nullable `int` defaulting to `0` while the server always sent `null`, and the generated decoder was literally `(json['current_minute_remaining'] as num?)?.toInt() ?? 0` — so "unknown" decoded to "none remaining". *Correcting the earlier note on this item, which said the client "renders 0":* it was never rendered at all. `provision_page` displays only `monthToDateUnits`, so nothing was visibly wrong; the defect was a type that lied about the contract, waiting for the first caller to read it.

Rather than make it nullable — a permanently-null field nobody reads — it was removed from the model, `BootstrapResponse`, the Zod mirror in `workers/lib/types/schemas.ts`, and the handler. The authoritative source already exists and the client already consumes it: `GET /v1/orgs/:id/quota/status` → `QuotaStatusData`, verified live returning `minuteLimit: 6000, minuteUsed: 1, minuteWindowExpiresIn: 59590`. So no Flutter release is needed to *recover* the data, contrary to the earlier note — the data was already available on the page that shows it.

The Dart model gained `unavailable` in its place, mirroring item 5, and the client's fallback for a wholly absent `usage_snapshot` now sets `unavailable: true` instead of reporting zero usage. Four Dart tests pin it, including a regression guard that a server still sending the legacy key is ignored rather than silently decoded back into a zero that reads as real data. Verified live: `usage_snapshot` is now exactly `{"month_to_date_units": 0}`.

---

<a id="cr24"></a>

### CR24: Legacy Supabase `anon` + `service_role` JWT keys are still enabled

**Priority:** P2 | **Source:** session 2026-07-28, enumerating `GET /v1/projects/{ref}/api-keys`
**Estimated:** 5 minutes, plus one cross-repo check

**Context:** project `cfrbahzzklwrnmbtqojl` still has the original JWT-format keys active alongside the `sb_*` keys that replaced them. `GET /v1/projects/{ref}/api-keys/legacy` returns `enabled: true`.

Two properties make this worth closing rather than leaving:

1. **The legacy `service_role` JWT bypasses RLS**, exactly like the `sb_secret_` key in use. It is a second, older credential with full read/write on every table — including the three whose RLS was only enabled on 2026-07-27.
2. **It is disclosed in plaintext by the Management API.** `GET /v1/projects/{ref}/api-keys` masks `sb_secret_` values (`sb_secret_OBc1n···`) but returns legacy keys as complete JWTs. Anything that can read that endpoint — any holder of the `sbp_` access token, which includes Doppler `prd` and therefore anyone with the unrotated token from [[CR01]] — can retrieve them in full. **This happened during the session that filed this item: a routine enumeration printed both JWTs into a transcript.**

**Evidence they are unused (checked, not assumed):**
- All four Doppler Supabase values, in both `dev` and `prd`, are the new format (`sb_secret_` / `sb_publishable_`) — none begins `eyJ`.
- No non-test code in this repo reads `SUPABASE_ANON_KEY`; the workers read `SUPABASE_SERVICE_ROLE_KEY`, which holds `sb_secret_OBc1n…`.

**Scope:**
1. Confirm `api-provisioning-receiver` (in `observability-toolkit`) does not use a legacy key. **This repo cannot answer that** — it is the one unchecked consumer.
2. Disable via `PUT /v1/projects/{ref}/api-keys/legacy` with `{"enabled": false}`. Reversible through the same endpoint, so the blast radius of getting step 1 wrong is one API call.
3. Treat the two JWTs as disclosed and rotate if anything turns out to depend on them — disabling is not rotation, and re-enabling would restore the same key material.

**Status:** ✅ Done (2026-07-29) — legacy keys disabled at the project. Verified by probe: the legacy `service_role` JWT authenticated with full RLS bypass at 08:15 UTC and returned `401 Invalid API key` at 08:40; the legacy anon JWT 401s likewise. The step-1 cross-repo check was skipped, mitigated by reversibility (step 2's endpoint re-enables) — `api-provisioning-receiver`'s `/health` returns 200 post-disable, and `api-gateway` reports database healthy on its `sb_secret_` key. Step 3 stands: the two JWTs remain disclosed material; never re-enable them.

---

<a id="cr27"></a>

### CR27: `stripe-webhook` dead-lettered every real event — two independent defects, both latent for four months

**Priority:** P1 | **Source:** session 2026-07-31, found by inspecting `webhook_dead_letters` while auditing an unrelated organization
**Estimated:** done

**Context:** the first genuine Stripe subscription traffic this account has ever seen (a `$0/mo` starter subscription created 2026-07-31) produced **three events, all three dead-lettered**. Neither defect was a regression — `webhook_events_log` held exactly one row before this, a synthetic `evt_prod_postdeploy_probe_001` from 2026-07-28, so no real event had ever exercised these paths. This is the same class of gap recorded at the head of Phase 4: the code was merged, unit-tested and deployed, and still could not process a single real event.

**1. `invoice.paid` — read a field Stripe had removed.** `handleInvoicePaid` guarded on `invoice.subscription`. Stripe API **2025-04-30** deleted that top-level field and moved the reference to `parent.subscription_details.subscription`; the endpoint delivers on `2025-09-30.clover`, so the guard read `undefined` on every subscription invoice and returned `Invoice missing subscription`. `InvoiceSchema` now accepts both shapes and `getInvoiceSubscriptionId()` prefers the current location with a legacy fallback — both can legitimately be in flight across a version bump, event replays, and older dead-letter retries.

**2. `customer.subscription.updated` — an `ON CONFLICT` target no index covered.** `upsertSubscription` used `ON CONFLICT (organization_id, stripe_subscription_id)`. Postgres requires a unique index matching the target **exactly**, and only `stripe_subscription_id` was UNIQUE, so every event failed with `42P10` and dead-lettered. Fixed by adding `subscriptions_organization_id_key UNIQUE (organization_id)` (migration `20260731000000`) and pointing the upsert at it.

> **⚠️ A misdiagnosis is recorded here deliberately, because the wrong fix shipped first.** Defect 2's conflict target was inferred by probing `organization_id` and `stripe_subscription_id` *separately* through PostgREST and finding the former unconstrained — rather than by reading `upsertSubscription`, which names the pair. The constraint was applied to production on that reasoning, the event was reset to retry, and **it failed again and re-abandoned**, because a unique index on `(a)` does not satisfy `ON CONFLICT (a, b)`. Only then was the source read. The constraint is now load-bearing, so it stands — but it was applied for a reason that was not true, and it commits the schema to **one subscription row per organization** permanently: replacing a subscription overwrites the prior record rather than retaining history. Reverting that would mean dropping the constraint and conflicting on `stripe_subscription_id` instead. **Generalisable: probing a symptom column-by-column is not equivalent to reading the statement that produced it.**

**Scope, all complete:**
1. ~~`invoice.paid` reads the current field location~~ — commit `205f53e`, deployed `87225064`.
2. ~~Conflict target matches an index that exists~~ — commit `0398fa9`, deployed `247ce90e`, migration `20260731000000` applied to production.
3. ~~Replay the dead letters~~ — abandoned rows reset (`status='pending'`, `retry_count=0`); both `invoice.paid` events resolved at 05:00:59 and 05:01:00 on the `*/15` cron, and `webhook_events_log` went 1 → 3.

**Verified rather than assumed:** both fixes were replayed against the **real** dead-lettered payloads pulled from `webhook_dead_letters`, not hand-written fixtures — the `invoice.paid` pair returns `{ ok: true }`, and the `ON CONFLICT` probe was re-run through PostgREST inside a transaction that was rolled back. A test in `supabase.test.ts` had pinned the old conflict target and was updated *with the reason inline*, since a bare edit would read as a test bent to fit the code.

**Related, and now closed as a side effect:** `plans` had no `stripe_price_id` column, so the catalogue mapped Stripe → plan key (via the `metadata.plan_key` tags on each product and price) but never the reverse. Migration `20260731020000` adds it, backfilled for `starter` and `growth`; `enterprise` stays NULL — no Stripe product, custom pricing.

**Status:** ✅ Done (2026-07-31) — 155 tests passing, `tsc` clean, both Workers deployed and verified against live production data. Note this entry closes the *handling* bug only; [[CR20]] item 2 (alerting on dead-letter depth) is unaffected and remains the reason this went unnoticed for four months — **nothing alerted, and nothing would have.**

---

<a id="cr28"></a>

### CR28: `billing_status` collapsed Stripe's lifecycle — a trialing customer recorded as never having subscribed

**Priority:** P3 | **Source:** session 2026-07-31, found in the final state left by [[CR27]]'s replay
**Estimated:** done

**Context:** `resolveBillingStatus` recognised exactly two Stripe statuses and collapsed the rest:

```ts
if (stripeStatus === 'active') return 'active';
if (stripeStatus === 'past_due') return 'past_due';
return 'inactive';
```

Stripe's lifecycle has **eight** statuses, and it treats `trialing` and `active` as its two good-standing states — a trial is a *granted* entitlement, which is the entire purpose of `trial_period_days`. So a customer inside a trial was recorded as though no subscription existed. `unpaid`, `canceled` and `paused` were likewise indistinguishable from never having subscribed, even though they are operationally different (dunning, churned, deliberately suspended). Found because [[CR27]]'s replay left a real `trialing` subscription sitting at `billing_status='inactive'`.

> **⚠️ The severity was overstated first, and the correction is the point.** This was initially reported as trial customers being "denied service for the whole trial", and that claim reached a commit message before it was checked. It is false: **nothing gates on `billing_status`.** It is written by `stripe-webhook`, `SELECT`ed by `api-gateway`, and displayed — there is not one comparison against it anywhere in TypeScript or Dart, and the quota and entitlement paths never read it. The observable effect was a wrong value on the billing page. The error came from reasoning about the mapping without checking its consumers, which is the same shape as [[CR27]]'s misdiagnosis: **inferring behaviour from one end of a data path instead of reading both.**

**The fix removes the mapping rather than extending it.** `BillingStatus` now mirrors Stripe's eight statuses verbatim, so storing one requires no translation — and a lossy translation is what produced the defect. A status Stripe adds later flows through instead of silently becoming `inactive`. `inactive` is kept as our own value for "no Stripe subscription exists", which Stripe cannot express because a status presupposes a subscription object; it covers 31 of 32 organizations today, so a pure mirror was never possible.

Because nothing gates on it *yet*, the real hazard is forward-looking: the first consumer to write `=== 'active'` as an entitlement check silently excludes trial users. `isEntitled` (`workers/lib/billing.ts`) gives that rule one home so it is not re-derived per call site.

**The test suite documented the defect rather than catching it.** `it('maps any non-active/past_due status to inactive')` asserted `trialing` → `'inactive'` as intended behaviour, and passed for four months — only because no real subscription had ever reached the Worker to contradict it. Replaced with an exhaustive table over every Stripe status, plus a sync test pinning the union, the Zod enum and the pass-through list together, since drift between those three declarations of one fact is otherwise silent.

**Status:** ✅ Done (2026-07-31, deployed `cdf60c9f`) — 163 stripe-webhook + 510 `workers/lib` tests passing, all six workers typecheck clean. **Verified on live production data rather than by inspection:** a harmless metadata touch on the real subscription emitted `customer.subscription.updated`, and the deployed Worker wrote `billing_status='trialing'` within 3 seconds, bumping `quota_version` and leaving no new dead letters. The stale row from [[CR27]] was corrected by that same event — deliberately, rather than by hand-writing the value, so the fix was proven end to end instead of the symptom being patched.

---

<a id="cr29"></a>

### CR29: the HMAC key rotation is a no-op — omitting `x-key-id` downgrades to the legacy `SHARED_SECRET`, which the production receiver still accepts

**Priority:** P1 | **Source:** session 2026-07-31, found while diagnosing [[CR11]] row #7
**Estimated:** S in code on both sides; the work is the rollout order and a cross-repo caller audit, not the diff

**Context.** The multi-key signing mechanism (`SIGNING_KEYS` + `ACTIVE_KEY_ID` + an `x-key-id` header) was provisioned in production on 2026-07-30 and works: `sender-worker` signs with key `v2`, the receiver verifies against its matching `SIGNING_KEYS`, and a live `/send` round-trip returns `200 {"ok":true}`. But the single-key *path* that predates it was left in place on both sides for backward compatibility, and it is **selected by the absence of a header**:

```ts
// receiver — resolveSigningKey()
if (keyId === undefined) return env.SHARED_SECRET;   // ← no header ⇒ legacy key
if (keyId.trim() === '') return null;                // ← "" correctly rejected
```

So the production receiver accepts **two distinct credentials**: `v2` (sha `64a3cb3fef31`, key-id'd, rotatable) and `SHARED_SECRET` (sha `424bb5dee2ba`, no key id, outside the rotation set). **To be precise about blast radius:** the value in that slot is the *post*-2026-07-29 one — [[CR01]]'s rotation did overwrite the older secret, so the pre-rotation value is genuinely dead. What is still live is the legacy *mechanism*, and the credential currently reachable through it. That is why this is a design defect rather than a missed cleanup: the next rotation will leave its own predecessor live in exactly the same way. Measured directly against `POST /inbox`, with controls so a 401 could not be mistaken for a bad signature implementation:

| Probe | `x-key-id` | Result |
|---|---|---|
| positive control — `v2` key | `v2` | **200** |
| **subject** — `SHARED_SECRET` | *(omitted)* | **200** |
| negative control — garbage secret | *(omitted)* | **401** `invalid signature` |

**Why this is its own item and not part of [[CR11]].** CR11 is about `dev`/`prd` isolation, and the shared `SHARED_SECRET` value is what surfaced this. But the defect is independent of sharing: even with `dev` fully isolated, **rotating `SIGNING_KEYS` would still retire nothing**, because removing a key from `SIGNING_KEYS` cannot revoke a credential that is not resolved through it. `SHARED_SECRET` has no key id, so it has no rotation handle — it is retired only by unbinding it. That is a defect in the rotation design, not in the environment split, and it survives every fix CR11 contemplates.

Two consequences, in order of how much they matter:

1. **[[CR01]]'s HMAC rotation is incomplete.** The 2026-07-29 rotation and the 2026-07-30 `v2` provisioning both did what they claimed, and neither retired the older path. A future rotation will read as successful for the same reason.
2. **Anything holding `SHARED_SECRET` can forge production provisioning events** by omitting one header. Today that includes the Doppler `dev` config (byte-identical value — CR11 row #7), which is why re-rotating `dev` is the *wrong* fix: it papers this over until the next config copy.

**The existing key-age alert makes this worse rather than catching it.** The receiver binds `KEY_ROTATION_DATES` and a scheduled cron alerts via Sentry when any tracked key exceeds 90 days (`docs/provisioning-environment-setup.md`, rotation step 4). The tracked entry is `SHARED_SECRET` **by name** — and step 4 of the rotation procedure refreshes that date. So the operator rotates, updates the date, Sentry goes green, and the previous credential is still valid: **the alert reports the age of a string in a JSON blob, not the liveness of a key.** Two further gaps in the same variable: the runbook only said to add per-key-id entries "if `SIGNING_KEYS` is later provisioned", so whether a `v2` entry was added on 2026-07-30 is unverified (secret values are write-only — read it from the receiver side), and a missing entry means the *active* key is the one exempt from the alert. Corrected in the runbook 2026-07-31; the underlying design still needs CR29.

**The sender had the mirror-image hazard** — ✅ closed by steps 1 and 2 (2026-08-02), described here as it was found. `resolveOutboundSigningKey` (`workers/sender-worker/src/utils.ts`) fell back to `SHARED_SECRET` with no key id on **four** conditions — `ACTIVE_KEY_ID` unset, `SIGNING_KEYS` unset, `SIGNING_KEYS` malformed JSON, or `ACTIVE_KEY_ID` naming a key that is not in the map. Only a `console.warn`/`console.error` marked the last two. So a typo in `ACTIVE_KEY_ID` silently dropped production back to the legacy key and kept working, which is precisely the failure a rotation mechanism exists to make loud. All four are now named misses that return `secret: null`, and every one of them is a 500.

**Scope, in an order that cannot cause an outage.** The two halves close different things — step 2 is the only one that closes the forgery path; step 1 only makes a downgrade attributable — and step 3 is irreversible-ish, so the evidence step comes first:

0. ✅ **Done 2026-07-31 — and it found a blocker.** The audit ran against `observability-toolkit` at `~/.claude/mcp-servers/observability-toolkit`. Both halves are answered below; **step 2 cannot ship until the e2e finding is resolved**, so this step's outcome is a hard prerequisite, not a clearance.

   **a. The caller set — one legitimate automated caller signs without a key id, and it hits production.** No *deployed* service in `observability-toolkit` calls `/inbox` at all (no `[[services]]` binding, no fetch outside scripts and tests), so the production caller set is `sender-worker` (fine — signs `v2`) plus **the CI e2e job**. `.github/workflows/publish.yml:87` runs `doppler run --project integrity-studio --config dev -- npm test` after every `publish`, which enables `services/e2e/receiver-security.e2e.ts` — its gate is `PROVISIONING_RECEIVER_WORKER_URL !== "" && SHARED_SECRET !== ""` and **both are set in Doppler `dev`**. That suite signs with `SHARED_SECRET` and sends **no `x-key-id`**, against `https://api-provisioning-receiver.alyshia-b38.workers.dev` — *the production receiver* (Doppler `dev` and `prd` hold the same host; `dev` is the one with a scheme). What step 2 does to it:
   - **Test 4 breaks outright.** It expects `500 PROVISION_ERROR`, which requires passing signature verification to reach the Auth0 `/userinfo` check. Under step 2 it becomes `401 INVALID_SIGNATURE`.
   - **Tests 2 and 3 silently degrade.** Both assert `401 INVALID_SIGNATURE`, which is *also* what a missing `x-key-id` returns — so they keep passing while no longer exercising signature forgery or body tampering at all. This is the worse outcome of the two, because it is green.
   - **Test 1 is unaffected** — `validateTimestamp` runs at `index.ts:85`, before the key is read at `:95`, so `INVALID_TIMESTAMP` still wins.

   **The suite cannot simply add the header: `ACTIVE_KEY_ID` and `SIGNING_KEYS` are both UNSET in Doppler `dev`** (verified by fingerprint; `prd` has both). And because the dev config points at the *production* receiver, provisioning them in `dev` would mean copying a production signing key into `dev` — re-creating exactly the [[CR11]] sharing problem this work is meant to end. Alternatives, in preference order: stand up a dev receiver and point `dev` at it; or move this suite to `--config prd` on the same reasoning as `sender-worker`'s `test:live`; or remove the job for now.

   ✅ **Resolved 2026-07-31 by the last option — the `e2e` job is removed, so step 2 is no longer blocked on a caller.** The whole `e2e:` job is gone from `observability-toolkit`'s `.github/workflows/publish.yml` (it was a standalone job; nothing declared `needs: [e2e]`, and it ran `services/e2e`'s own package, so no unit coverage moved). Verified afterwards that **no** workflow in that repo still invokes the suite: the only other `doppler` user, `api-provisioning-receiver-test.yml`, runs the receiver's local suite and probes `/health`, and never signs `/inbox`. So `sender-worker` — which signs `v2` — is now the sole automated caller, and the receiver-side change can ship without breaking anything.
   - **`receiver-security.e2e.ts` was deliberately left as-is, not rewritten.** Its tests-2-and-3 degradation is a real defect that survives the job removal, so the analysis above is recorded in a comment at the top of the file: restoring the job without fixing them brings back two assertions that pass while testing nothing. Both need a positive control (same request, correctly signed, must **not** 401) before a 401 proves forgery detection rather than a rejected key id.
   - **What the removal costs:** the other seven specs in that package no longer run anywhere in CI — `provision-key`, `sender-receiver`, `api-key-auth`, `ingest-evaluations`, `dashboard-auth{,-errors,-logout}`. Only `receiver-security` was implicated in CR29; the rest are collateral, and they are the reason to restore the job rather than leave it deleted. Recorded in the workflow comment with its restore conditions so the loss does not become permanent by default. Of the seven, `provision-key` also reaches the receiver but does so **through the sender** (`PROVISION_WORKER_URL` → `/send`), so its HMAC is the sender's keyed `v2` signature and it is unaffected by requiring `x-key-id`.
   - **A dev receiver ([[CR02]] item 5) is therefore no longer a prerequisite for step 2** — it drops back to being what it was: isolation hygiene, plus the precondition for *restoring* the e2e job. That is the one change to this item's critical path.
   - ⚠️ **The receiver auto-deploys, which now matters for step 2's sequencing.** `api-provisioning-receiver-test.yml` deploys the production receiver on every push to `main` touching `services/api-provisioning-receiver/**`, using `prd`'s `CLOUDFLARE_WORKER_TOKEN`. So merging the step-2 change **ships it immediately** — there is no separate deploy gate to stage behind. Land the sender fail-closed (step 1) first, and confirm `SIGNING_KEYS` holds every key id in use *before* the receiver merge, not after.

   **b. The receiver did not log the resolved key id, so the "watch a full traffic cycle" evidence was not obtainable.** `services/api-provisioning-receiver/src/index.ts` read `keyId`, passed it to `resolveSigningKey`, and **never recorded it**. There was no auth event on the success path at all, and `captureAuditEvent({ event: "auth.invalid_signature" })` fired for *both* "no secret resolved" and "signature mismatch" with no discriminator — so even failures could not be attributed to a missing header.

   ✅ **Done 2026-08-01 — `observability-toolkit` `8fcae0b`, committed not pushed.** `resolveSigningKey` now returns a discriminated `SigningKeyResolution` (the secret **plus** which credential answered, or a named `miss`), and the `/inbox` call site emits four events:

   | Event | Level | Meaning |
   |---|---|---|
   | `auth.verified` + `keyId` | info | Verified against a `SIGNING_KEYS` entry |
   | `auth.verified_legacy_key` | **warning** | Verified against `SHARED_SECRET` — this item's defect, now countable |
   | `auth.key_unresolved` + `miss` + `keyId` | warning | No key resolved, so no HMAC check ran |
   | `auth.invalid_signature` + `keySource` + `keyId` | warning | A key *was* resolved and the signature did not match |

   - **`auth.verified_legacy_key` is the gate on step 3.** Search Sentry for `event_type:auth.verified_legacy_key` over a full traffic cycle; when it stops appearing, the keyless fallback has no callers. It is deliberately `warning`, not `info` — a success on a path that cannot be rotated should be visible without opening the event.
   - **Distinct event *names*, not one event with a `source` field**, because `captureAuditEvent` puts payload in Sentry `extra`, which is not searchable, while the name becomes the queryable `event_type` tag. Same reason `auth.key_unresolved` was split out rather than added as a field.
   - **`auth.verified` fires at verification time**, not folded into `provision.success`/`signin.success`, so replays and requests that later fail payload validation are still attributed — attribution has to be *complete* to support the claim "nothing signs keylessly". Note it does not reuse the field name `keyId` from `provision.success`, where that means the *provisioned API key's* id.
   - **No HTTP behaviour change**, deliberately: both 401 paths stay byte-identical (status, body, headers — asserted) so valid key ids cannot be enumerated by diffing responses. Only telemetry distinguishes them. 283 receiver tests (+20 from the 263 baseline), clean `tsc --noEmit`.
   - **Not deployed.** The instrumentation is worthless until it observes production traffic, but pushing to `main` auto-deploys the receiver (see the ⚠️ above) — so the push is a deliberate, separate decision.
   - Corrected while there: a `SIGNING_KEYS` entry that is present but unusable (`{"v2":123}`, `{"v2":null}`) is now a named malformed miss; the old `keys[keyId] ?? null` collapsed only `null`/`undefined`, so a number reached `verifySignature` typed as a string.

   One smaller finding, now partly stale. `resolveSigningKey` in the real receiver was behaviourally **identical** to this repo's stub, and still is *in behaviour* — but its signature is no longer the same, so the stub must mirror step 2's behaviour change without needing the resolution type. And `src/utils.test.ts:16` asserts *"returns SHARED_SECRET when keyId is undefined"* — both repos' unit tests pin the behaviour step 2 removes, so they change in the same commit. Out of scope, confirmed not affected: `obtool-ingest`'s evaluations endpoint is a **separate** HMAC scheme (`INJECT_HMAC_SECRET`, body-only, `sha256=` prefix) and does not touch `SHARED_SECRET`.
1. ✅ **Done 2026-08-02 — sender fails closed** instead of downgrading. `resolveOutboundSigningKey` now returns a discriminated union mirroring the receiver's `SigningKeyResolution`: `{ secret, keyId }` on success, or `{ secret: null, miss }` where `miss` is `active_key_id_unset` | `signing_keys_unset` | `signing_keys_malformed` | `unknown_active_key_id`. `forwardToReceiver` narrows on `secret === null` and returns **500 `SIGNING_KEY_UNRESOLVED`** without calling the receiver. Four things worth knowing before touching it:
   - ~~**The trigger is `ACTIVE_KEY_ID` *set* and unresolvable, not the absence of rotation vars.** `ACTIVE_KEY_ID` unset stays on the legacy path deliberately — `wrangler.toml` documents it as the way to stage `SIGNING_KEYS` before activating it, and it is still valid configuration until step 3.~~ **Superseded by step 2 the same day**: `ACTIVE_KEY_ID` unset is now the fourth miss (`active_key_id_unset`), because with the receiver rejecting keyless requests there is no longer a legacy path to fall back *to* — leaving it would have meant signing a request the receiver was guaranteed to 401. The staging affordance moved to where it belongs: stage a new key id in the **receiver's** `SIGNING_KEYS` first, which is the receiver-first ordering the runbook already requires, and the sender's `ACTIVE_KEY_ID` flips last. The `wrangler.toml` comment documenting the old affordance is deleted.
   - **The response deliberately carries no key id.** `"Signing key unavailable"` plus the code; which of the three misses fired is `console.error` only. Same reasoning as the receiver's byte-identical 401s — a caller should not learn what the operator meant to bind. Asserted (`expect(body.error).not.toContain('v99')`), as is the resolver not logging a *non-active* key's secret material.
   - **The assertion that matters is `expect(mockReceiverFetch).not.toHaveBeenCalled()`, not the status code.** A downgraded request signed with `SHARED_SECRET` and no `x-key-id` is accepted by the receiver as legacy-signed, so a regression here returns **200** and hides itself completely; a test checking only the status would pass while testing nothing. Mutation-verified: restoring the old fallback fails 6 of the new tests, including that one.
   - ~~**Adjacent fix, needed for step 3.** `handleSend`'s pre-flight was `!env.SHARED_SECRET` → 500, which would have rejected a perfectly signable `v2` request the moment step 3 unbinds `SHARED_SECRET` — turning the unbinding into a `/send` outage, the exact failure this item's ordering exists to avoid. Now `!env.SHARED_SECRET && !env.ACTIVE_KEY_ID`, i.e. "no signing credential at all".~~ **Also superseded by step 2, which deleted the pre-flight entirely rather than rewriting it again.** The constraint it protected is satisfied more strongly now — nothing reads `SHARED_SECRET`, so its unbinding cannot cause a `/send` outage by construction. And `!env.ACTIVE_KEY_ID` was the wrong question in any case: `ACTIVE_KEY_ID` being *present* says nothing about whether it resolves, so the check could only ever duplicate a subset of `forwardToReceiver`'s job while answering a misleading `SHARED_SECRET not configured`. `forwardToReceiver` is now the single authority, with one 500 whose code names the actual fault. The `!env.RECEIVER` pre-flight is retained — that one tests something the resolver does not.

   200 sender tests (+12 from 188), `test:e2e` 48/48, clean `tsc --noEmit` across all six worker packages. Also corrected the stale comment at `index.ts:201-204`, which described the receiver's pre-`8fcae0b` `resolveSigningKey()` returning `null` in three cases.
2. ✅ **Done 2026-08-02 — the receiver requires `x-key-id`**, resolving solely through `SIGNING_KEYS`; an absent header is now the same explicit miss `""` already was (`if (keyId === undefined) return { secret: null, source: null, miss: "missing_key_id" }`). **Cross-repo, and unpushed on both sides.** This is the step that closes the forgery path — in code. Production still accepts keyless signatures until the receiver deploys. Six things worth knowing:
   - **It changed step 3's gate metric, which is the consequence most likely to be missed.** The gate was "`auth.verified_legacy_key` goes quiet over a full traffic cycle". That event **no longer exists** — it fired on the success path this step deletes, so quiet is now guaranteed by construction rather than observed, and reading it as evidence would be reading the absence of a deleted code path. The live signal is `auth.key_unresolved` with `miss: "missing_key_id"`, and its polarity is inverted: it counts *breakage*, not success. A caller still signing keylessly now shows up as a rejected request rather than an accepted one, so step 3's real precondition is that metric staying at zero once the receiver is deployed.
   - **No HTTP behaviour change beyond the one intended.** The keyless 401 is byte-identical to the forged-signature 401 (status, body, headers — asserted), so this step does not just refuse to leak key ids, it refuses to leak *whether a given deployment has been migrated*. A caller cannot probe for a receiver still on the old build.
   - **The sender fails loudly so the receiver never has to fail confusingly.** A sender that cannot resolve a key returns 500 `SIGNING_KEY_UNRESOLVED` and forwards nothing (step 1), rather than sending a keyless request the receiver would 401. That matters because of the byte-identical 401s above: a misconfigured deploy would otherwise present in the receiver's telemetry as *an apparent attack on production* rather than as the operator error it is.
   - **Both repos' unit tests pinned the retired behaviour** — `src/utils.test.ts:16` asserted *"returns SHARED_SECRET when keyId is undefined"* in the receiver, and this repo's stub had the twin. Removed in the same change, in both places; the stub (`workers/receiver-worker/src/index.ts`) now mirrors the contract without needing the resolution type.
   - **The test-helper trap that caught this: `function f(x = DEFAULT)` called as `f(undefined)` uses DEFAULT.** Every helper meaning "omit this header" therefore takes `null` as its sentinel, not `undefined` — `signedHeaders(ts, body, secret, keyId: string | null)`. A helper defaulting on `undefined` produces a *keyed* request while the test believes it sent a keyless one, which is a test that passes for the wrong reason.
   - **Two paths in the toolkit are checked by neither `tsc` invocation.** The receiver's `tsconfig.json` is `include: ["src/"]`, the root's is `include: ['src/**/*']`, so `services/e2e/` and `services/api-provisioning-receiver/scripts/` are covered only by `eslint.config.cjs` (lines 181–190). Both were edited here — `receiver-security.e2e.ts` and `scripts/load-test.ts` — so run `npx eslint --config eslint.config.cjs <file>` on them; a green `tsc` says nothing about either.
3. **Unbind `SHARED_SECRET`** from both Workers once steps 0–2 hold *in production*. Until then it stays bound, because a binding that is no longer read is harmless and an unbinding done early is an outage.

Doing 2 before 1 also works, but leaves a window where a sender fallback answers a confusing 401 instead of a clear sender-side error.

**One apparent blocker to step 2, retired — and the comment that would have re-created it is deleted.** `workers/sender-worker/wrangler.toml:104` stated that `ACTIVE_KEY_ID` is *"deliberately UNSET in the dev config: `sender-worker-dev` binds `RECEIVER` to the PRODUCTION receiver … so it must keep taking the `SHARED_SECRET` fallback path."* Read at face value that is a legitimate caller signing without a key id, and therefore a reason step 2 cannot ship. It was not, for two independent reasons. **`sender-worker-dev` has no secrets bound at all** (`wrangler secret list --name sender-worker-dev` → `[]`, 2026-07-31), so it could neither sign with `v2` *nor* fall back — the documented dependency was inert. And the configuration that would activate it is one this repo forbids: pushing the `dev` Doppler secrets into the dev Workers "would create a second production-capable worker rather than a dev environment" (CLAUDE.md; [[CR11]]). ✅ **Comment deleted with step 2, as instructed** — left in place it would have been a standing instruction to restore the very path being removed, and the next operator reading it would reasonably have concluded the removal was a mistake. The warnings that survive it are the ones worth keeping: do not give `sender-worker-dev` the `dev` Doppler secrets, and do not give it production's `SIGNING_KEYS`. The real fix for dev is a dev receiver ([[CR02]] item 5), not a shared legacy credential.

**Files to touch:**
- `api-provisioning-receiver` (`observability-toolkit` repo, `services/api-provisioning-receiver/`) — the real change (step 2). ✅ Step 0b's instrumentation already landed here (`8fcae0b`): `src/utils.ts` (the resolution type), `src/audit.ts` (the four events), `src/index.ts` (the call site), plus `docs/api-provisioning.md` — whose audit-event table had documented `auth.invalid_signature` as *"HMAC mismatch or unknown key ID"*, the exact conflation, and whose rotation runbook presented removing a key id from `SIGNING_KEYS` as a revocation
- `workers/receiver-worker/src/index.ts:47` — the local stub carries the identical fallback, commented "backward compat". It is the test double the suite exercises, so it must mirror the receiver or the tests will keep asserting the retired behaviour
- ✅ `workers/sender-worker/src/utils.ts` — `resolveOutboundSigningKey` fail-closed (step 1, done 2026-08-02), with `src/types.ts` (the `SIGNING_KEY_UNRESOLVED` code + description), `src/index.ts` (the call-site guard, the `handleSend` pre-flight, the stale receiver comment), and both test files
- ✅ `workers/sender-worker/wrangler.toml` — the `ACTIVE_KEY_ID` comment asserting dev "must keep taking the `SHARED_SECRET` fallback path" (see the paragraph above); annotated 2026-07-31, **deleted with step 2 2026-08-02**. The block now reads `SIGNING_KEYS` + `ACTIVE_KEY_ID` as REQUIRED and `SHARED_SECRET` as not read, with an explicit "do not restore a fallback to it"
- ✅ `workers/sender-worker/{README.md,.env.example}` + `vitest.e2e.config.mts` — the e2e config bound only `SHARED_SECRET`, so the three `/send` e2e tests would have 500'd on the fail-closed path. It now binds the signing pair and the receiver stub echoes `x-key-id`, which is what proves the header survives a real service-binding subrequest in workerd (the unit tests only see the object handed to a mocked `fetch`). `SHARED_SECRET` is deliberately still bound in every fixture, and deliberately a *different* value from the active key, so "unreachable" is proven with the credential present rather than merely absent
- `docs/provisioning-environment-setup.md` — the rotation procedure ([[W05]] step 3). ✅ **Rewritten 2026-07-31**: the correct `SIGNING_KEYS` wire format, receiver-first ordering, and the fact that the legacy path stays valid through a rotation are all now documented, and the procedure is split into A (key-id'd) and B (legacy). The doc no longer misleads; the design defect is still open

**Status:** Open — **every code step is done (0, 0b, 1, 2); what remains is a deploy and then step 3.** Step 0 (2026-07-31) found one automated caller signing without a key id (the CI e2e job) and that job has been **removed**, so `sender-worker` — signing `v2` — is the sole automated caller and nothing depends on the keyless fallback. Step 0b's instrumentation is committed **unpushed** (2026-08-01, `8fcae0b`); steps 1 and 2 followed on 2026-08-02, also unpushed, in both repos. **Order, with what remains:** ~~0b instrument the receiver~~ ✅ → ~~step 1 sender fail-closed~~ ✅ → ~~step 2 receiver requires the header~~ ✅ → **deploy** ← the whole remaining risk → step 3 unbind.

⚠️ **The deploy is now the only hard step, and it is a two-repo ordering problem with no staging gate on either side.** Pushing `observability-toolkit` `main` auto-deploys the production receiver (`api-provisioning-receiver-test.yml`, on any push touching `services/api-provisioning-receiver/**`); merging this repo to `main` CI-deploys `sender-worker`. Two consequences that decide the order:
- **The receiver must not deploy before a sender that sends a key id.** It already accepts `v2` — production has signed with `v2` since 2026-07-30 — so today's live sender is compatible with the new receiver and the order is *technically* safe either way. But the safe order is still sender-first, because the sender is the side that fails *loudly*: deploy it, watch `/send` stay green, and only then take away the receiver's fallback. Receiver-first means any unknown keyless caller starts getting a 401 that looks exactly like an attack.
- **Confirm the receiver's `SIGNING_KEYS` holds every key id in use before it deploys** — after the deploy, an unlisted key id is a 401 with no fallback behind it. Read it from the receiver side; the values are write-only from here.

⚠️ **Step 3's gate metric changed, and the old one would now read as a false pass.** It was "`auth.verified_legacy_key` observed quiet over a full traffic cycle" — but step 2 deleted the code path that emitted it, so quiet is guaranteed by construction and proves nothing. The live gate is **`auth.key_unresolved` with `miss: "missing_key_id"` staying at zero in deployed traffic**, which is the same question asked in the negative: not "did anything succeed keylessly" but "did anything get rejected for signing keylessly". Only *deployed* code counts, so neither step 1 nor step 2 narrows this gate until both are live — and step 1's own effect on production is invisible until this branch merges. That remains the real schedule: nothing after the deploy can be verified until the instrumentation has observed a full cycle. The dev receiver ([[CR02]] item 5) is **not on this critical path**; it is needed to *restore* the e2e job, not to ship any of this. Related: [[CR11]] row #7 (how it was found, and why provisioning `SIGNING_KEYS` into `dev` is not the fix), [[CR02]] item 5 (the dev receiver, now a prerequisite), [[CR01]] step 3 (the rotation this makes incomplete), [[W05]] (runbook — rewritten 2026-07-31), [[CR14]] (the receiver's retained versions publish whatever it binds, so step 3 also shrinks that exposure).

> ⚠️ **Unrelated defect found during the audit — `prd`'s `PROVISIONING_RECEIVER_WORKER_URL` has no scheme.** `dev` holds `https://api-provisioning-receiver.alyshia-b38.workers.dev` (57 chars); `prd` holds the same host **without `https://`** (49 chars), which `fetch()` cannot use. Nothing reads it today — the slot was deleted from `sender-worker`'s bindings as part of [[CR15]] item 2, and the e2e job runs `--config dev` — so this is latent, not live. Fix the value or delete the slot; do not "fix" it by pointing the e2e suite at `prd`.

> ⚠️ **Method note for anyone re-running the probe.** A green `/send` does **not** test this — production prefers `v2`, so the happy path exercises the rotated key and never touches `SHARED_SECRET`. Sign `/inbox` directly. And probe `workers.dev` with `curl`, not Python `urllib`: the first attempt got `403 Cloudflare 1010` on all three probes including the positive control, making the result look inconclusive rather than negative ([[CR14]] records the same trap). Always include a positive control — without one, that blanket 403 is indistinguishable from a signature failure.

### CR31: the published API docs advertise three endpoints that do not exist, and `api-gateway` has no hostname

**Priority:** P2 — the docs half is customer-visible today and needs no decision; the routing half is [[CR13]]'s decision with the measurement now supplied
**Source:** session 2026-08-03, while answering "should `api.integritystudio.ai/*` point at `api-gateway`?"
**Estimated:** 30 min for the docs fixes; 30 min for the route split once [[CR13]] is answered; ~1h for the sync guard

📄 **The inventory lives in [`docs/api-routing.md`](api-routing.md)** — live zone routes, both workers' complete route tables, the disjointness result, what the docs advertise, and the re-measurement commands. This item exists to fix what that document found and to stop it rotting.

**What was measured (2026-08-03, live + source):**

`api.integritystudio.ai/*` → `obtool-api`. There are exactly three worker routes in the account (`api.integritystudio.ai/*` → `obtool-api`, `ingest.integritystudio.ai/*` → `obtool-ingest`, `api.alephatx.info/*` → `tcad-api`). `api-gateway` has none, and the Flutter client's `API_GATEWAY_URL` defaults to `https://api-gateway.alyshia-b38.workers.dev` (`lib/services/provisioning_service.dart:21`, `lib/services/dashboard_service.dart:15`), which `ci.yml` ships unchanged. So the account/billing/ingest API reaches customers on a workers.dev hostname while the branded one serves the observability read API.

**The four docs defects — customer-visible on the live site, no decision required:**

| Site | Advertised | Reality |
|---|---|---|
| `lib/pages/docs_quickstart_page.dart:515` | `curl https://api.integritystudio.ai/v1/health` | **401.** `obtool-api` serves health at `/health`; its `authMiddleware` is mounted on `/v1/*` and catches `/v1/health` first. The quickstart's first command fails for every reader |
| `lib/pages/docs_alerts_page.dart:217` | `POST .../v1/alerts` | **No such route on either worker.** 401 from the middleware, 404 behind it even with a valid key — a documented endpoint with no server-side implementation |
| `lib/pages/docs_api_page.dart:119` | Sandbox base `https://sandbox-api.integritystudio.ai/v1` | **NXDOMAIN.** No DNS record, no route in either zone; connection fails outright |
| `lib/pages/docs_index_page.dart:498` | "Status" quick-link → `https://status.integritystudio.ai` | **NXDOMAIN.** A dead link in the quick-links row on the docs landing page |

`docs_api_page.dart:117` (production base), `:250` (`GET /v1/traces`) and every `ingest.integritystudio.ai` reference are correct.

⚠️ **The fourth defect was found only by fixing the checker, and that is the strongest available argument for step 5.** The first version of the advertised-URL grep matched the bare substring `api.integritystudio.ai` — which is *contained in* `sandbox-api.integritystudio.ai`, so `grep -o` emitted the same string for both hosts and they collapsed into one row. Re-anchoring on `https?://[a-z0-9.-]*integritystudio\.ai` separated them and surfaced `status.integritystudio.ai`, which nothing had ever checked. **A checker that normalises away the distinction it is checking passes silently on the exact class of defect it exists to catch** — the same shape as the [[CR11]] detector watching a slot name that had moved, and as [[CR29]] step 3's gate metric being guaranteed-quiet by construction. Third instance; treat "the check is green" as a claim needing its own positive control.

**Why the answer to "repoint it?" is no.** The two route tables are **disjoint — `/health` is the only overlap**. Repointing the wildcard to `api-gateway` would 404 all thirteen `obtool-api` routes, including `/v1/traces`, the one documented endpoint that currently works. The fix is four narrower patterns with the wildcard left as fallback (Cloudflare matches most-specific-first), needing no code change on either worker:

```
api.integritystudio.ai/v1/me         -> api-gateway
api.integritystudio.ai/v1/orgs*      -> api-gateway     # covers the nested api-keys routes
api.integritystudio.ai/v1/ingest/*   -> api-gateway
api.integritystudio.ai/bootstrap     -> api-gateway
api.integritystudio.ai/*             -> obtool-api      # unchanged
```

⚠️ **This re-opens [[CR13]]'s trap.** It means putting a `routes` key back into `workers/api-gateway/wrangler.toml`. Top level **only**, with an explicit `routes = []` under `[env.dev]` — `routes` is inherited into named environments, and omitting it there is what handed `api.integritystudio.ai/v1/*` to the secret-less `api-gateway-dev` on 2026-07-27. `workers/lib/deploy-environments.test.ts` asserts the rule; run it before deploying. Prefer creating the routes via Dashboard/API first and codifying them afterwards, so the route exists before any deploy can move it.

**Steps:**

1. 🔴 Fix `docs_quickstart_page.dart:515` — `/v1/health` → `/health`.
2. 🔴 Fix `docs_alerts_page.dart:217` — either remove the block or implement `POST /v1/alerts`. It is currently a promise with nothing behind it.
3. 🔴 Fix `docs_api_page.dart:119` — remove the Sandbox row, or stand up `sandbox-api.integritystudio.ai`. Do not leave an NXDOMAIN in customer docs.
4. 🔴 Fix `docs_index_page.dart:498` — remove the Status quick-link, or point it at a real status page. NXDOMAIN on the docs landing page.
5. 🔴 Answer [[CR13]]'s ownership question, then apply the four-pattern split above. Blocked only on that decision, not on measurement.
6. 🔴 **Build the sync guard** (below). Without it this document is a snapshot that will read as current long after it stops being true.
7. 📋 Optional: repoint `API_GATEWAY_URL`'s default at the branded hostname *after* step 5 lands. Not before — the default is what shipped builds use, so it must follow the route, never lead it.

**The sync guard — what "kept in sync" has to mean here.** Three cheap assertions, runnable in CI without Cloudflare credentials:

- Parse `api-gateway`'s dispatch table out of `workers/api-gateway/src/index.ts` and assert it matches the inventory table in `api-routing.md`. Catches a route added or renamed without a doc update.
- Grep `lib/**/*.dart` for every advertised URL — `https?://[a-z0-9.-]*integritystudio\.ai[a-zA-Z0-9/{}:_.-]*`, **anchored on the scheme, never on a bare host substring** — and assert each path appears in the document's *advertised* table. This is the assertion that catches the docs class; it would have caught three of the four above on its own, and the fourth only once the pattern was anchored, which is the point.
- Resolve every distinct host in that list. Two of the four defects are DNS-level, not routing-level, so a route-table comparison alone misses them.
- Assert `workers/api-gateway/wrangler.toml` either has no `routes` key or has one at top level with `routes = []` under `[env.dev]`. Overlaps `deploy-environments.test.ts` deliberately; this one fires when the doc and the config disagree.

A live route probe needs zone-read credentials, which the dev workers token deliberately lacks (403 — that denial is [[CR13]]'s protection working). Keep the probe manual and in the document, not in CI. DNS resolution needs no credential, so the host check *can* run in CI.

⚠️ **Two probing traps, both of which produced wrong readings while this was being investigated, and both recorded in the document:** `curl` defaults to **GET**, so probing a POST-only route (`/v1/ingest/otel`, `/v1/ingest/events`, `/bootstrap`) returns 404 and reads as "route missing"; and a **401 proves the middleware ran, not that the route exists** — `obtool-api` auth-gates all of `/v1/*`, so every path under it returns 401 whether real or invented. That is the same class as [[CR14]]'s blanket-403 and [[CR29]]'s positive-control note: read the source for a route table, and use probes only for what is live.

Related: [[CR13]] (the ownership decision this measures), [[CR16]] (why folding `obtool-api` into `api-gateway` is explicitly not the answer), [[CR12]] (`API_KEY_HMAC_SECRET` still unbound, so `api-gateway`'s API-key routes 503 regardless of hostname).

---

*Last updated: 2026-03-21 — backlog-implementer + backlog-migrate + auto-error-resolver session: L6/L7/L10/L11/L12/L13 marked done (38c339c); M36 fixed (7d86372); L5 env binding added (5c7a443, 8cdaa09, 306ccfc); 27 items migrated to v1.2; CSP test failure diagnosed and fixed (47b4dc3); L16 + M37 migrated to v1.2 changelog (2 completed items). Test Status: ✅ ALL 2631 TESTS PASSING. Remaining: T25, T28, V02-Remaining, M34, M38, M39 (6 deferred/design-decision items). Score: 9/10.*

*Backlog-implementer continuation (2026-03-21): L16 refactored (AppDecorations.card() 5786939, PASS); M34 fixed with soft-delete + active-only filter (33aa1a2, cf5059c, PASS); M37 verified done (no new commits). Test Status: ✅ 61 stripe-webhook tests passing. Remaining open items: 4 (T25, T28, M38, M39 require design decisions). Items completed: 2 (L16, M34). Score: 9/10.*

*Backlog-implementer session (2026-03-21): H3 DB filter fix (b2d23fe, PASS); H4 stripe_customer_id validation (162983d, PASS); M40 audit log waitUntil (8f999e6, PASS); M41 APP_URL env escalation (826d2f3, PASS); M42 503 retry + test fix (8b6120f, 51f8ad8, PASS); L20 error sanitization (32ee699, PASS); L21 insert call count assertion (32ee699, PASS); L22 billing_admin audit log count (user-applied); L23 sanitize read endpoint errors + fetchOrgList (15da535, c586ee8, 2ece18a, PASS). Test Status: ✅ 35 Dart + 17 TS tests passing. Items completed: 9. Remaining: T25, T28, M18 (design decisions / external deps). Score: 9/10.*

*Backlog-implementer session (2026-03-21): OTEL-1 POST /v1/ingest/otel implemented — OtelSpanSchema, IngestOtelRequestSchema, handleIngestOtel with API-key auth + quota enforcement + attribute size caps (1b771e3, c40a1c8, PASS); 10 new tests. Payments roadmap "Telemetry/monitoring setup" item DONE. Test Status: ✅ 120 api-gateway tests passing. Items completed: 1. Remaining: T28 (design decision). Score: 9/10.*

*Backlog-implementer session (2026-03-21): L23 rate-limit headers forwarded (e743c68, PASS); L25 OTEL_INGEST_ROUTE exported (2aa30eb, PASS); L24 start_time_ms upper bound refine (32658b9, PASS); L22 makeOpts typed as SupabaseClient|undefined (ce4c563, PASS); final review high finding addressed — applyRateLimitHeaders helper + boundary tests (5e5d2c4). Test Status: ✅ 122 api-gateway tests passing. Items completed: 4 (L22-L25). Remaining: T28 (design decision). Score: 10/10.*

*Code-review remediation session (2026-07-26): recovered and consolidated the 8-area review (43 items / 51 findings), fixed the PostgREST `Prefer` header and the `/signup?tier=Team` routing break, then a backlog pass closed 38 more. Added CR01–CR10 for the remainder: the 5 items never fixed, 2 marked-fixed-but-not-closed (inert rate limiter, JWT still in a URL fragment), and 3 found while converting the api-gateway and stripe-webhook tests to drive a real Supabase client over a stubbed transport. Test Status: ✅ 3,001 Flutter + 984 worker tests passing; zero TypeScript errors across all 7 workers.*

*Backlog-implementer session (2026-07-26): CR01 doppler.json removed from git + .gitignore (88ef77a); CR05 usage/entitlements endpoints return 5xx on DB error (d11cf38); CR06 me.ts splits DB error from 404 (d11cf38); CR04 provision_page.dart comment corrected (d632263); CR07 CLAUDE.md status block refreshed (8d4c8e2); CR08 ~18 dead Array.isArray checks removed (2ada4e9); CR09 handler test fixtures use HTTP-format errors (424bbd2); CR10 fetchPendingDeadLetters null phantom filtered (1a8196a). CR02 (dev/prod separation) and CR03 (RATE_LIMIT_KV) deferred — need live wrangler/CF operations. CR01 steps 2–3 (history scrub + rotation) deferred to maintenance window. CR04 full fix deferred — cross-repo. CR05–CR10 migrated to the 1.3 changelog (*Review Backlog Pass*) and removed from this section. Test Status: ✅ 3,001 Flutter + 984 worker tests passing; zero TypeScript errors across all 7 workers.*
