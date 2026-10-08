# Backlog

Open and deferred items only. Completed items are migrated to `docs/changelog/1.0/CHANGELOG.md`, `docs/changelog/1.1/CHANGELOG.md`, `docs/changelog/1.2/CHANGELOG.md`, and `docs/changelog/1.3/CHANGELOG.md`.

**Last Updated:** 2026-09-28 (CR37 step 3 and CR47 confirmed live — toolkit pushed, receiver `3c9b1020` deployed 06:40Z; staleness pass: body status lines reconciled with the CR table for CR01, CR12, CR13, CR18, CR20 and CR29, plus the V02, CR38, UA09, W04 and W09 references. Live-state claims — CR29's merge, CR38's `/health`, `check:env-isolation`, the two previews-on Workers, the Doppler fallback cache — were re-measured that day; the rest were reconciled to their own table rows and the 1.3 changelog). Previous: 2026-09-22 (UA07 implemented `dbe6749f` and verified in production; UA08 filed from what the verification showed), 2026-09-21 (UA07 filed), 2026-09-20 (UA01–UA06 filed; UA01 implemented `8edf955`).

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
> **Two claims in this file were wrong about liveness and are corrected in place.** [[CR21]] was marked ✅ on 2026-07-29 while production was still running 2026-07-28 code, and [[CR22]] read as needing a deploy that is now done but *still* cannot be exercised — its 403 needs a valid API key, which `API_KEY_HMAC_SECRET` being unbound makes unreachable ([[CR12]]). The recurring error is treating "merged" as "live"; see the audit note at the head of Phase 4, which now has three instances rather than one. **Superseded 2026-08-06 — both are now exercisable.** [[CR12]] bound `API_KEY_HMAC_SECRET` to production and verified it with a real key; [[CR22]]'s 403 was then probed live and confirmed correct.
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

**v1 release items — ✅ COMPLETE (2026-07-12):** [V02](changelog/1.3/CHANGELOG.md#v02) moved to changelog 1.3 on 2026-10-04.

## Deferred: OAuth Security (#8-#10) — ✅ COMPLETE

| Issue | Severity | Status |
|-------|----------|--------|
| #8 OAuth State Validation | CRITICAL | ✅ Done — `OAuthService.validateCallback()` with constant-time compare; CSRF rejection tracked in analytics (commit b957544) |
| #9 PKCE Implementation | CRITICAL | ✅ Done — `OAuthService.buildAuthorizationUrl()` with RFC 7636 S256 challenge; sessionStorage scoped; conditional web/stub exports (commit b957544) |

> 🗑️ **REMOVED 2026-08-22 — the code these rows hardened was a dead shell, deleted rather than completed.** `buildAuthorizationUrl` never gained a caller (nothing initiated the authorize redirect), and `OAuthCallbackPage` validated state then stopped — its "backend handles this" token exchange was never built, so `/oauth/callback` could never complete a login. When the homepage Log In was pointed at the dashboard SPA (which runs its own Auth0 Universal Login at `integritystudio.dev/callback` — see the CR04 note below), this repo's half of the flow lost its purpose. Deleted: `OAuthService` (web/stub/conditional export), `OAuthCallbackPage`, the `/oauth/callback` route, and the orphaned `SecurityUtils` OAuth sanitizers + their tests. If a first-party Universal Login flow is ever wanted here, resurrect from git (`b957544` lineage) **and build the token exchange first** — the UI shell without it is what sat here for months reading as working.

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

## Code Review 2026-07-26 → 2026-07-27 (CR01–CR35)

Started as the open remainder of the 8-area codebase review; CR11–CR15 were found afterwards while deploying and auditing the workers, CR16 while reading the deployed `obtool-*` scripts to settle CR13, CR22–CR23 as follow-ups to the billing-portal auth change, CR26 while fixing the reported dashboard CORS failure — which turned out to sit on top of two deeper auth defects — CR29 while diagnosing CR11 row #7, where the shared secret was the symptom and the unrotatable legacy key path was the actual defect, CR30 while executing CR11 step 1 against a genuinely empty project, and CR31 while answering the plain question "should `api.integritystudio.ai/*` point at `api-gateway`?" — where the answer was no and the three broken URLs found on the way there were the larger finding. Fixed work lives in [`changelog/1.3/CHANGELOG.md`](changelog/1.3/CHANGELOG.md); the review's method, provenance, and 3 refuted claims are in [`CODE_REVIEW.md`](../CODE_REVIEW.md).

| ID | P | Status | One line |
|---|---|---|---|
| [CR01](changelog/1.3/CHANGELOG.md#cr01) | P1 | ✅ **DONE 2026-08-17** | History scrubbed + force-pushed. **Every rotatable family rotated 2026-07-29** — Stripe, both Auth0 secrets (`AUTH0_CLI_SECRET` twice, the second to recover a wrong-account overwrite), HMAC `SHARED_SECRET`, `sb_secret_` service keys (old revoked), legacy Supabase JWTs disabled, stray key revoked. ✅ **Local cleanup done** — `doppler.json` deleted, `~/.doppler/fallback/` removed. *(Re-read 2026-09-28: `doppler.json` is still absent; `~/.doppler/fallback/` exists again because the Doppler CLI rewrites it on every `doppler run`, and every file in it is dated 2026-09-11 or later — post-rotation values, not the pre-rotation material this row cleared.)* ✅ **`sbp_` token minted & stored in Doppler `prd`** — migration drift check now runs live, all 23 tables + 10 functions verified. ✅ **Database password reset to distinct value** → `SUPABASE_DB_PASSWORD`. *(Superseded 2026-09-27: that slot was deleted from both configs by [[UA09]] — it overrode the CLI's working login-role path — so no database password is stored anywhere.)* **Remaining (Dashboard-only, not blocking):** 2 Stripe key revocations (already revoked, verification pending) |
| [CR18](changelog/1.3/CHANGELOG.md#cr18) | P1 | ✅ **done 2026-08-06** | Live key minted; prd endpoint + signing secret live and verified. Item 2 (last remainder) resolved: dead `STRIPE_API_KEY` slot (already-revoked, unbound, unread) dropped from Doppler `prd`; `scripts/check-env-isolation.sh` updated in the same pass so the deletion didn't turn a real `PASS` into a manufactured failure |
| [CR11](changelog/1.3/CHANGELOG.md#cr11) | P2 | ✅ **DONE 2026-08-07 — every step this item owns is closed.** **Nothing in this repo remains.** Isolation, runbook, step 8 and [[CR02]] item 5 are all done, and the last gap this row named — "the dev Supabase project has **zero edge functions**" — is closed: the three functions with source were deployed to `tumhmtshahktumhqqamk` and `api-keys-list` was **source-recovered** (it was never lost, only untracked — see [[W10]]), taking the toolkit e2e suite to **34 passed / 0 failed / 12 skipped**. Also 2026-08-07: the dev sender was deployed and armed, and `PROVISION_WORKER_URL` — which had been the **production** sender, so two e2e suites were creating real users and keys in production — now points at `sender-worker-dev`. **The only residual is a one-line CI change in the other repo** (put the `e2e` job back into `observability-toolkit`'s `publish.yml`), tracked there as `E2E-CI-RESTORE`; do not re-open this item for it | ✅ **2026-08-03: `npm run check:env-isolation` PASSES (exit 0)** — 15 credentials distinct, 2 Stripe keys test-mode in dev / live in prd. Doppler `dev` now reaches its own Supabase project (`tumhmtshahktumhqqamk`), its own Auth0 tenant (`dev-njjmghdzm23uy0p7`) and its own Stripe sandbox; the dev key is proven **refused by production (401)**, and the `*-dev` Workers are armed with dev credentials (live `POST /signup` on `sender-worker-dev` → 201, dev DB 0/0 → 1/1, production counts unchanged). **Steps 8–9 were both mis-stated and are re-measured 2026-08-03** — step 9 (dev Stripe sandbox) was already done when it was written, and step 8's premise is false: the two deploys do **not** share a token. **Runbook tail completed 2026-08-03** — dev DB seeded to reference parity, contact-form-dev armed with dev-safe recipients + a fresh sending-scoped Resend key (proven 200), Playwright contact-worker spec repointed to dev (16/16), dev workers armed (live signup proof). ✅ **Step 8 DONE 2026-08-06 — and the re-measurement it asked for showed the token had already been scoped.** `dev`'s `CLOUDFLARE_API_TOKEN` is `dev-workers-token` (`5fc67fe7`, minted 2026-08-03): Workers Scripts + KV + Account Settings Read, and **provably no** Workers Routes / Zone / R2 / D1 / Pages / token-admin, checked against `prd`'s token as a positive control on the same endpoint. Proven end to end by a real `npm run deploy` → `sender-worker-dev` `01c2da65`, healthy, [[CR14]]'s `previews_enabled: false` intact. Revocation (item 9) needs no action — the superseded token is already absent from the account. 🔴 **Two unrelated tokens surfaced, both consumer-less and `last_used_on: never` since 2025-12-01:** `12c7e4bd` — Workers **Routes** Write across `zone.*` plus Scripts/Pages/R2 — ✅ **revoked 2026-08-06**, with in-use credentials and production health re-checked afterwards as positive controls; `feef0f3d` (account-wide read) **retained by owner decision**. **One thing now remains:** restoring the `observability-toolkit` e2e suite. ✅ **The [[CR02]] item 5 hop is CLEARED as of 2026-08-07** — `api-provisioning-receiver-dev` exists, and all three of `dev`'s `PROVISIONING_RECEIVER_WORKER_URL` / `ACTIVE_KEY_ID` (`dev1`) / `SIGNING_KEYS` are set and point at it, with `dev1` freshly generated rather than copied from production's `v2` and proven **401 against the production receiver**. `receiver-security.e2e.ts` ran 5/5 un-gated. ✅ **The hollow-green blocker that replaced it is FIXED 2026-08-07** (toolkit `509a460`): the suite had **exited 0 when rate-limited**, silently degrading to `1 passed / 4 skipped`, so restoring the CI job would have bought a green check that asserts nothing. `assertNotRateLimited` now throws instead of skipping — mutation-proven by three consecutive runs, the third exiting **1**. Two further self-lies were fixed alongside it: `vitest.config.e2e.ts` was collecting **itself** as a test suite (a permanent failure, and the reason the file count read 9 for 8 suites), and `createTestUser` hardcoded a **production** org UUID, so every suite using it died in setup the moment `dev` was repointed. *(Historical, through 2026-08-06: "still blocked one hop on CR02 item 5's dev receiver — `dev`'s `PROVISIONING_RECEIVER_WORKER_URL` still points at the production receiver while `ACTIVE_KEY_ID`/`SIGNING_KEYS` stay unset in `dev`.")* ⚠️ **Everything below this row is historical.** It read "⚠️ partial, **regressed** — Doppler `dev` still shares one Supabase **project** and Auth0 **tenant** with `prd`. 10/13 → 3/13 on 2026-07-29, but **measured 5 of 13 on 2026-07-31**." Two were new then: `SHARED_SECRET` is byte-identical again (row #7's rotation has been undone), and `SUPABASE_SERVICE_ROLE_KEY` reads "UNSET in both" because **the slot no longer exists in either config** — the detector is checking a name that is gone, while the real service-role credential (`SUPABASE_PROVISIONING_KEY`, shared and **live**) is not checked at all. Longstanding 3: `SUPABASE_URL` + `SUPABASE_ANON_KEY` (one project) and `AUTH0_DOMAIN` (**no API can create a tenant**). 💰 **Re-audited 2026-08-02: unblocking this costs $0** — the Supabase dev project is free (org holds 1 of 2 free slots since `atx_movement` was deleted) and an Auth0 dev tenant is free (dev/staging tenants link to the same subscription). The "pay for a third Supabase project" blocker was **phantom**; the only real spend is ~$10/mo *or* a keep-alive to stop a free dev project pausing after 7 days idle under CI. Two free gaps were added as steps 8–9 on that date — "`deploy`/`deploy:prd` share one `CLOUDFLARE_WORKER_TOKEN`" and "dev has no Stripe sandbox" — and **both claims are false; see the current summary at the head of this row.** Detector history: 5/13 (broken) → 7/15 (true baseline) → 0 real |
| [CR12](changelog/1.3/CHANGELOG.md#cr12) | P1 | ✅ **done 2026-08-06** | `api-gateway` **healthy and fully bound** (4 secrets — `SUPABASE_JWT_SECRET` correctly stays unbound). **`API_KEY_HMAC_SECRET`** generated and bound to production, verified end to end with a real key (positive control 200, wrong-secret negative control 401) against `/v1/orgs/:id/usage/summary` — the same `machineRouteOpts` path also gates `/v1/ingest/*`. The earlier premise that the canonical value "must come from `observability-toolkit`'s owner" was wrong: the receiver hashes minted keys with plain SHA-256, not HMAC — the HMAC step is entirely this repo's own verification layer, so there was no existing value to match and a fresh one was generated here. A distinct dev-config secret was also stored in Doppler for later, not bound anywhere (`api-gateway-dev` is unreachable per [[CR14]]) |
| [CR14](changelog/1.3/CHANGELOG.md#cr14) | P1 | ✅ **RESOLVED 2026-08-03 — account-wide, 0 live previews** | **Every exposure this repo controls is closed live (2026-07-29 evening)** — `sender-worker` (14 secrets) and `integrity-studio-contact` joined `api-gateway` + `stripe-webhook`, and the **71 superseded versions** that had been serving (63 `sender-worker` back to 2026-03-29, 8 `contact-form` back to 2026-01-17) now all `404`. The re-audit also killed the "past retention" reading: superseded versions do **not** age out — a `404` means the version came from `wrangler secret put`, which gets no preview URL. ✅ `stripe-webhook-dev` **closed live 2026-08-03** (1 of 6 versions had been serving with 4 secrets after [[CR11]] step 4 armed it; its `wrangler.toml` already inherits `preview_urls = false`). 🔴 **Re-scoped 2026-08-03 and the mechanism was backwards:** a version publishes **the bindings it was uploaded with**, not the script's current ones — so rotation neither leaks backwards nor cleans up forwards, and the receiver has **29 live versions frozen at pre-[[CR01]] credentials while running pre-[[CR29]] code**, i.e. the forgery path is still reachable at a parallel hostname. Also **37 live of 90** retained receiver versions (not "30 of 30"; 36 of 89 at filing — the 90th, the receiver's first green CI auto-deploy, added its own live preview URL six seconds after toolkit `PREVIEW-URLS` was committed), **8** secrets not 9/10, and **five more Workers across three repos** never enumerated (two orphaned, no config on disk). Receiver half now tracked on the owning side as `observability-toolkit` `PREVIEW-URLS`. *Clarified 2026-09-28: "0 live previews" counts reachable preview URLs, not the setting. Two Workers outside this repo still report `previews_enabled: true` on a live API read that day — `tcad-token-refresh` (`tcad-scraper`) and `integrity-studio-cookie-manager-dev` (no config found); see the body's "Five more Workers" table.* |
| [CR02](changelog/1.3/CHANGELOG.md#cr02) | P2 | ✅ **done 2026-08-07 — item 5 closed, all 8 items resolved** | **The dev receiver exists.** `api-provisioning-receiver-dev` deployed from a new `[env.dev]` block (`observability-toolkit` `1c4ed45`) with its own KV namespace, its own AE dataset and `crons = []`; verified against deployed state with production as the paired control, and isolated by capability (dev key → production = 401, with a real positive control) rather than by the values differing. This side repoints `sender-worker-dev`'s `RECEIVER` to it, and a new mutation-verified assertion (suite 55 → 60) forbids any `[env.dev]` binding a service that is not itself a dev Worker — turning item 5's "residual safety is credential absence, not design" hazard into an enforced property. ~~⚠️ **Config-only so far: `sender-worker-dev` is not redeployed**, so the running dev Worker still binds production; it stays fail-closed because it holds no signing keys, and arming it must land with the redeploy.~~ ✅ **Redeployed and armed 2026-08-07 — both halves of that caveat are now false.** Re-measured against deployed state today, not inferred: the live script's bindings show `service RECEIVER -> api-provisioning-receiver-dev`, and `SIGNING_KEYS` + `ACTIVE_KEY_ID` are both bound (latest version `2026-08-07T22:16Z`). The co-deploy this caveat demanded is what happened — arming and repointing landed together, so the dev sender never ran armed against the production receiver. ~~🔴 Separately, the toolkit e2e suite turns out to be only ~once-per-hour repeatable and **exits 0 when rate-limited** — a blocker for restoring its CI job, detailed in item 5.~~ ✅ **Fixed 2026-08-07** (toolkit `509a460`): `assertNotRateLimited` throws instead of skipping, so the suite can no longer report success without running — mutation-proven by three consecutive runs, the third exiting **1**. The IP limiter (20/15 min, counted *before* signature verification, so forged-signature tests spend it too) still caps local runs at roughly two per window; `clear-dev-rate-limits.sh` resets it. See [[CR11]] and toolkit `E2E-CI-RESTORE`. *Historical:* Dev/prod split done and verified live. **2026-08-03:** it now has data isolation behind it — [[CR11]] passes, so the dev receiver (item 5) is **unblocked**; it would write to the dev Supabase project, not production. It remains a *config-layer* split at the credential layer, but not for the reason step 8 gave: `deploy` and `deploy:prd` do **not** share a token (`CLOUDFLARE_API_TOKEN` is distinct in `dev` vs `prd`; the byte-identical `CLOUDFLARE_WORKER_TOKEN` is read by no code in this repo). The real gap was that dev's token was account-wide in scope — blast radius, not a shared credential. ✅ **Step 8 closed 2026-08-06** ([[CR11]] step 8 holds the measurement): `deploy` now provably authenticates as a Workers-only, Routes-less, Zone-less token. **Item 5 (dev receiver) is the only thing left, and it is unblocked but not started.** *Historical, 2026-08-02: "a config-layer split with no credential behind it and no data isolation behind it; item 5 blocked behind CR11 step 1."* |
| [CR04](changelog/1.3/CHANGELOG.md#cr04) | P2 | ✅ **DONE — merged and deployed 2026-08-03** | Fragment handoff **deleted** (`provision_page.dart:86-92`); `_goToDashboard` now opens the dashboard with no token. The item's "requires a coordinated change in the dashboard app" premise was false — the dashboard never read `location.hash` and logs in itself, so this was one line, this repo only. **Ships on merge to `main`** (`ci.yml` → Cloudflare Pages `integritystudio-ai`) |
| [CR13](changelog/1.3/CHANGELOG.md#cr13) | P2 | ✅ **DONE 2026-08-08 — every step, decided and executed same day** | **Option C: the gateway got `api.integritystudio.dev`**, which closes steps 3–5 and **supersedes [[CR31]]'s option-B path-split**; [`api-reference.md`](api-reference.md#hostnames) has been resynced to match (`f36b813`) rather than left disagreeing. The name was already the gateway's Auth0 audience/resource server (`69c4e28bf801eab9e683c85a`) — though an audience is opaque and was never obliged to resolve, so this was naming correctness, not a repair. Executed: `integritystudio.dev` migrated Porkbun → Cloudflare (a **delegation change, not a transfer**; DNSSEC off, no MX/TXT/CAA), zone active in 20 min, Custom Domain `e3f5d910…` live (**200** `/health`, **401** `/v1/me`), `routes = [{ …, custom_domain = true }]` in `wrangler.toml` (`a61e4a6`), Flutter defaults repointed with CORS measured on both hosts (`f36b813`). **No outage** — both nameserver sets served byte-identical answers throughout, verified before delegation moved. 🔴 **Two regressions found and closed by re-probing after cutover rather than trusting the parity check**: a probed DNS inventory missed all four **AAAA** records (would have dropped the dashboard for IPv6 clients only), and Cloudflare imported the vestigial `*` CNAME **proxied**, serving `525` on an HSTS-preloaded TLD. **Record-level parity does not prove behavioural parity when the proxy flag is part of the record.** Step 1 remains **proven by a real deploy 2026-07-30** |
| [CR17](changelog/1.3/CHANGELOG.md#cr17) | P2 | ✅ done | Migration ledger repaired; drift detector in CI (`scripts/check-migration-drift.sh` + `migration-drift-check` job) |
| [CR19](changelog/1.3/CHANGELOG.md#cr19) | P2 | ✅ done | `stripe-webhook` org-not-found now returns `{ ok: false }` → unclaimEvent + dead-letter (commits eaaa199, 9741594) |
| [CR20](changelog/1.3/CHANGELOG.md#cr20) | P2 | ✅ **DONE 2026-08-09 — both halves observed** | **The alert was deliberately FAILED to prove its channel, because a passing run proves nothing about it.** `MIN_SUBREQUEST_RATIO` was temporarily set 0.5 → 99 to force exactly one breach; run `31265198806` exited 1 for the intended reason, GitHub raised a `CheckSuite` notification 24 s later, and **the owner confirmed receipt of the email** ("Failed in 13 seconds"). All four links observed rather than inferred: breach detected → job exits 1 → notification raised → email lands. Both temporary changes reverted in `613fa8f`, verified byte-identical to `982f406`, check exits 0 again. Armed on `main` as `982f406`, schedule `37 8 * * *`, workflow `state=active`. *Historical, before the merge:* **Step 4 answered 2026-07-31 (cron runs and succeeds). Alert implemented 2026-08-08**: daily `worker-signals.yml` workflow covering subrequest-ratio check (SIGNAL 2 — the one error rate cannot make) and dead-letter depth (SIGNAL 5). Verified live: all five signals evaluate and the check exits 0, with `stripe-webhook` at **1.00 subreqs/req** — the number that was 0.00 throughout the four-month outage. 🔴 **But it is inert until this branch reaches `main`**: GitHub runs `schedule` workflows from the **default branch only**, so no alert can fire today, and there is no notification to prove the channel works until then. Marking this ✅ before the merge is the same **merged-≠-live** error this file has now corrected four times ([[CR21]], [[CR22]], CR03/CR15, and this). Merge, then confirm one scheduled run actually appears in Actions. Second-order: GitHub also suspends cron workflows after ~60 days of repo inactivity, so a quiet period silently disarms it — ✅ **now detected**, since [[W11]]'s SIGNAL 6 breaches on `disabled_inactivity` and runs as the first step of this same workflow. The irreducible residual is that nothing running inside GitHub Actions can detect that Actions is not running it. ~~[[W04]] step 3 (dashboard) remains blocked on `obtool-ingest` repair but is not CR20's scope~~ [[W04]], step 3 included, closed 2026-08-09 (1.3 changelog) |
| [CR03](changelog/1.3/CHANGELOG.md#cr03) | P2 | ✅ done | KV namespaces created and bound; **live in production since the 2026-07-30 deploy** — `RATE_LIMIT_KV` → `766332ec…` confirmed in the deploy's binding list |
| [CR15](changelog/1.3/CHANGELOG.md#cr15) | P3 | ✅ done | Item 1 deployed 2026-07-30 (`enabled=True logs=True invocation=True traces=True` after ~4 months unmonitored). **Item 2 done 2026-07-31** — all four stale secrets deleted; production `sender-worker` went 16 → 12 bound, `/signin` still 401s correctly and the `RECEIVER` service binding survived |
| [CR21](changelog/1.3/CHANGELOG.md#cr21) | P3 | ✅ done | `stripe-webhook` uses `ctx.waitUntil(processEvent(...))` — 2xx before DB writes. **Merged 2026-07-29 but only live since 2026-07-30**; verified by grepping the deployed bundle, not inferred |
| [CR16](#cr16) | P3 | 📋 by design | Internal vs customer-facing OTEL pipelines — deliberate; **do not de-duplicate**. Convergence deferred |
| [CR22](changelog/1.3/CHANGELOG.md#cr22) | P3 | ✅ **exercised and confirmed live 2026-08-06** | Billing-portal API-key 403, deployed 2026-07-30, now proven end to end now that [[CR12]] bound `API_KEY_HMAC_SECRET`: a real signed test key against `POST /v1/orgs/:id/billing-portal` returns exactly `403 "Billing portal requires a user session; API keys are not accepted"` |
| [CR23](changelog/1.3/CHANGELOG.md#cr23) | P3 | ✅ resolved | Design decision: 401 for invalid credentials, 403 for valid-but-wrong-type. HTTP-correct; no code change needed |
| [CR24](changelog/1.3/CHANGELOG.md#cr24) | P2 | ✅ done | Legacy `anon` + `service_role` JWT keys disabled 2026-07-29 — **verified by probe**: both now return 401. Reversible via the same endpoint if the receiver turns out to depend on one (its `/health` is 200 post-disable) |
| [CR25](#cr25) | P2 | ⏸️ **deferred 2026-10-06** (owner) — MFA enforcement, the only item left | Auth0 tenant A production-readiness. Restructured 2026-08-03: 8 of 13 done (incl. branding, and the `integrity-dev-m2m` security finding closed via CR11), 4 carved out to [[CR32]]–[[CR35]], **1 left here — MFA enforcement, deferred by the owner 2026-10-06** (factors available, `guardian/policies` `[]`; enabling forces ~96 users to re-enrol, owner decision). No active security finding |
| [CR26](changelog/1.3/CHANGELOG.md#cr26) | P1 | ✅ done | `POST /bootstrap` mounted in `api-gateway` — matches the Flutter app contract with no client release. Handler ported from `bootstrap-worker` (fixed `in` filter on org query; uses shared `resolveUserId`/`buildEntitlementMap`). 14 tests added to `api-gateway/src/routes/bootstrap.test.ts`. `bootstrap-worker` directory deleted; removed from `WORKERS` / `SECRET_BEARING` in deploy-environments test and from root `package.json` scripts. ~~Needs `deploy:prd` on `api-gateway` to go live.~~ **Deployed and verified live** (version `846f8c21`) — see the CR26 body. Re-confirmed 2026-07-31: production `POST /bootstrap` answers **401**, not 404, so the route is mounted and auth-gated. |
| [CR30](changelog/1.3/CHANGELOG.md#cr30) | P1 | ✅ **RESOLVED 2026-08-03 — guard proven green in CI** | **The migration ledger could not rebuild the schema — now it can, proven by replay onto an empty database.** Final parity: 24/24 tables+views, 255/255 columns, 3/3 enums. Five new migrations; three separate ordering defects in the *existing* ledger were only findable by replaying. Gap was 10 tables, 3 enums, 2 columns on a ledger-managed table, 1 view — 43% of the schema was unversioned. Production untouched (read-only queries; all new files idempotent). **CI guard written 2026-08-03** (`migration-replay-check.yml` → `check-migration-replay.sh`: full local stack, `db reset`, schema assertions incl. the view; mutation-tested assertion SQL). ✅ **It has now RUN AND PASSED** — run `30804541500`, `Migration Replay Check`, success in 2m46s on the merge push to `main`, its first real execution. (It could not run before that: Docker is absent locally and the workflow was not yet on the default branch.) It triggers only on `main` (`push`/`pull_request` `branches: [main]`), so **pushing this branch does not run it** — the PR into `main` is the first execution. ⚠️ The summary here read "proven on its first CI run" until 2026-08-03: the body's pending gate ("the first CI run is the real proof") was compressed into a completed one, which is how an unexecuted guard came to read as a verified one. The drift check compares against production and cannot catch this class |
| ~~[CR30](changelog/1.3/CHANGELOG.md#cr30)~~ | P1 | *superseded row* | **The migration ledger cannot rebuild the schema.** `db push` onto a genuinely fresh project fails at `relation "public.users" does not exist`: the 14 migrations create 13 tables but reference `public.users` and `public.api_keys` by foreign key and create neither. `migration list` has always said "zero out of sync" because it compares against **production**, which has both tables from before the ledger existed — so the drift guard cannot catch this class by construction. Two consequences: [[CR11]] step 1 is blocked (and behind it [[CR02]] item 5 and the toolkit e2e suite), and **the repo cannot reconstruct its own database from source** — a disaster-recovery gap that is live today. Needs a baseline migration + a CI job that replays the ledger onto an empty DB |
| [CR29](changelog/1.3/CHANGELOG.md#cr29) | P1 | ✅ **RESOLVED 2026-08-03** | **The HMAC keyless-downgrade forgery path is closed and the legacy credential eliminated.** Steps 1+2 deployed (sender fail-closed, receiver requires `x-key-id`); step 3 done — `SHARED_SECRET` made optional in the receiver `Env`, unbound from both workers, and deleted from **both** Doppler configs (`prd` 2026-08-03, `dev` 2026-09-24) plus `KEY_ROTATION_DATES` in both (`prd` `{v2}`, `dev` `{dev1}`). Verified in prod: keyless `/inbox` → **401** (was 200), `v2` passes signature, `/signin`→`/send` → `ok:true`. ~~⚠️ Sender fix on branch `fix/active-subscription-id` — merge to make step 1 durable~~ ✅ Sender fail-closed commit `4bd0901` is on `origin/main` (re-verified 2026-09-28), so step 1 is durable; the security fix itself is receiver-side, `bca70a3` on toolkit `origin/main` (re-verified the same day) |
| [CR27](changelog/1.3/CHANGELOG.md#cr27) | P1 | ✅ done | `stripe-webhook` dead-lettered **every** real event for four months — two independent defects. `invoice.paid` read `invoice.subscription`, which Stripe deleted in API 2025-04-30 (schema now accepts both shapes); `customer.subscription.updated` used `ON CONFLICT (organization_id, stripe_subscription_id)` with no matching unique index, failing `42P10` (migration `20260731000000`). Both latent because no real event had ever reached these paths. **Read the misdiagnosis note in the body** — the wrong fix shipped first |
| [CR28](changelog/1.3/CHANGELOG.md#cr28) | P3 | ✅ done | `resolveBillingStatus` knew 2 of Stripe's 8 subscription statuses and collapsed the rest to `inactive`, so a **trialing** customer read as never having subscribed. Found in the state [[CR27]]'s replay left behind |
| [CR31](changelog/1.3/CHANGELOG.md#cr31) | P2 | ✅ **DONE 2026-08-08 — all 7 steps** | ✅ **Closed.** 4 docs defects fixed 2026-08-03 (`97ade42`); the sync guard built then and **widened 2026-08-08**; step 5 closed by **supersession** and step 7 done (`f36b813`). ⚠️ **The "4-pattern path-split" recommendation below was SUPERSEDED and never built.** [[CR13]] was decided and executed on 2026-08-08 in favour of option C — `api-gateway` has its own hostname, **`api.integritystudio.dev`**, live and serving. So there is no split to build on `api.integritystudio.ai`, and the hostname step 5's docs fixes need now **exists**, where this row previously recorded it as not yet created. ✅ [`api-reference.md`](api-reference.md#hostnames) was resynced in the same pass (`f36b813`). Everything below is retained as the measurement, which is still accurate about what serves what today. **The published API docs advertise four URLs that resolve to nothing, and the product's own API has no hostname.** Routing inventory captured in [`api-reference.md`](api-reference.md#hostnames) (measured 2026-08-03). `api.integritystudio.ai/*` → `obtool-api` (observability read API); `api-gateway` — account, billing, ingest — is workers.dev-only, and the Flutter client's `API_GATEWAY_URL` default ships that way. Customer-visible right now: `/v1/health` 401s (health is at `/health`; the `/v1/*` middleware catches it first), `POST /v1/alerts` exists on **neither** worker, and both `sandbox-api.integritystudio.ai` and `status.integritystudio.ai` are **NXDOMAIN**. The two route tables are **disjoint** (only `/health` overlaps), so the fix is a 4-pattern path-split, not a repoint — repointing the wildcard would 404 all 13 `obtool-api` routes. Supplies the measurement [[CR13]] was waiting on; the ownership decision stays there. ⚠️ The fourth defect surfaced only after fixing the checker's grep, which had been merging `sandbox-api.…` into `api.…` as a substring — third instance of a green check that had normalised away what it was checking. Needs: fix the 4 docs sites, decide the split, build a sync guard so this document cannot silently rot |
| [CR32](#cr32) | P3 | 📋 **unblocked 2026-10-06** (owner) — can be implemented now | Auth0 **custom domain** (login runs on `dev-…auth0.com`). Hostname decided (**`auth.integritystudio.ai`**), DNS confirmed ready (Cloudflare zone reachable, clean slate). **Corrected 2026-08-06 — it IS gated**, just not by plan tier: a real `POST /custom-domains` with a valid body and correctly-scoped token returns `403 "There must be a verified credit card on file"`. The earlier "NOT plan-gated" reading came from an empty-body probe that never reached the billing check. Owner needs to add a verified card in the Auth0 Dashboard; everything after that is scriptable |
| [CR33](changelog/1.3/CHANGELOG.md#cr33) | P3 | ✅ **DONE 2026-08-18 — receiver built, stream live** | Auth0 **log streams** — receiver is `POST /v1/auth0-logs` on `api-gateway` (`api.integritystudio.dev`), persisting to Supabase `auth0_logs` (RLS, unique `log_id`, JSONB payload); Auth0 HTTP stream configured and events verified flowing 2026-08-18 00:03Z. Rule that outlives it: **do not point an http stream at the OTLP endpoint** — it rejects every batch |
| [CR34](changelog/1.3/CHANGELOG.md#cr34) | P2 | ✅ **RESOLVED 2026-08-03 — implicit 2→0, ROPC 3→1** | Strip Auth0 **`implicit` + ROPC** grants (SPA + `AUTH0_MANAGER`). Carved from CR25 items 7–8. Minutes by API, but must verify `sender-worker`'s `password-realm` `/signin` survives; `My App`'s ROPC likely stays until the client gets a refresh flow |
| [CR35](#cr35) | P3 | ⏸️ **deferred 2026-10-06** (owner) — needs an Auth0 plan upgrade | Auth0 **breached-password detection**. Carved from CR25 item 3. Genuinely plan-gated (PATCH 400 "upgrade your subscription"); re-attempt after any plan change |
| [CR36](changelog/1.3/CHANGELOG.md#cr36) | P2 | ✅ **DONE 2026-09-27 — uniform, not tiered** | The **plan-tiered edge rate limiter** was documented as a live pipeline step but never implemented. Shipped as a uniform 300 req/min per-org limiter in `api-gateway` (`checkOrgRateLimit`, `RATE_LIMIT_KV` prefix `gw_org_rl:`), applied after auth and before the quota DO — the per-minute ceiling that survives a DO outage. Tiering deliberately dropped: the plan is not known before the DO call, and the DO already enforces plan-tiered limits |
| [CR37](changelog/1.3/CHANGELOG.md#cr37) | P1 | ✅ **DONE and live 2026-09-28** — sender + gateway deployed; toolkit receiver deployed 06:40Z (`3c9b1020`) | **`/signup` lets the caller choose the plan.** No path takes a plan from the caller any more (`/signup`, `/send`, receiver first-provision), and both enforcers gate a paid plan on an entitled `billing_status`. Live after: push `main` (sender CI), `deploy:prd` api-gateway, push toolkit `main` (receiver) |
| [CR38](changelog/1.3/CHANGELOG.md#cr38) | P1 | ✅ **DONE 2026-09-28** — 3 prices incl. enterprise bound, migration applied, webhook redeployed (`/health` `priceToPlanEntries: 3`) | **`stripe-webhook` never writes `current_plan` in production** — `/health` now reports `priceToPlanEntries` and subscription events warn when map is empty (`1c10221`). ~~`STRIPE_PRICE_TO_PLAN_JSON` still needs to be bound manually (commands in the detail section below)~~ Bound 2026-09-28 — production `/health` re-read the same day returns `priceToPlanEntries: 3` |
| [CR39](changelog/1.3/CHANGELOG.md#cr39) | P2 | ✅ **DONE 2026-09-27 — by UA08** | `/v1/orgs/:id/*` reserved quota and wrote a `usage_events` row **before** the membership check. Fixed by UA08 (`61a4e71`): `preVerifyToken` now takes `orgId` and 403s a foreign API key or a JWT with no membership row before `enforceOrgQuota`; fails open only on a DB error, where the handler re-checks |
| [CR40](changelog/1.3/CHANGELOG.md#cr40) | P2 | ✅ **DONE and live 2026-09-28** — gate `834d40d1`, poller `dd6f7aa4` | Route requires `AUTH0_LOG_STREAM_TOKEN` (401 verified live). The plan refuses log streams (`409`), so a `*/15` cron polls `GET /api/v2/logs` with a `read:logs`-only M2M client: first run 20:30Z stored all 23 retained entries. Event stream re-enabled 23:47Z, now authenticated with `AUTH0_LOG_STREAM_TOKEN` and its CloudEvents stored — **live** (`3419b312`, first real event stored 2026-09-29 00:39Z). All 36 failed Aug deliveries redelivered and stored (Auth0 failed list 36 → 0). `AUTH0_LOG_STREAM_SECRET` deleted 2026-09-29. Nothing left. **CR33 never stored a real event** — see the entry |
| [CR41](changelog/1.3/CHANGELOG.md#cr41) | P1 | ✅ **DONE 2026-09-27** | `api-gateway-dev` `[env.dev.vars]` pinned `AUTH0_DOMAIN` to the **production** tenant since 2026-07-30 — invisible to `check:env-isolation`, which reads Doppler, never `vars`. Fixed (`d1cdb45`), guarded (`ff8b923`), deployed. Residual: dev has no `API_KEY_HMAC_SECRET` |
| [CR42](changelog/1.3/CHANGELOG.md#cr42) | P3 | ✅ **DONE and live 2026-09-29** — `api-gateway` `51324cf4` | `/v1/ingest/events` now reserves org quota after the membership check (429 + rate-limit headers, like `/v1/ingest/otel`); schema caps `quantity` ≤ 1,000,000 and `metadata` ≤ 50 keys / 8,192 bytes; dead `OTEL_MAX_SPANS` deleted |
| [CR43](changelog/1.3/CHANGELOG.md#cr43) | P2 | ✅ **DONE and live 2026-09-28** — migration `20260927020000` applied, then `api-gateway` `35eb0e18` | `usage_buckets_daily` had **two writers**. The Worker rollup is deleted; the ledger trigger is the only writer, now with a NULL-safe, sample-weighted latency average and UTC bucket days. Guarded by a source scan and a router-level test |
| [CR44](changelog/1.3/CHANGELOG.md#cr44) | P3 | ✅ **DONE and live 2026-09-29** — `api-gateway` `51324cf4` | `in` list members double-quoted (a `,` can no longer split the list); `update`/`deleteRows` return an error for an empty filter instead of writing the whole table; checkout validates `plan` with `ApiKeyTierSchema` before any query |
| [CR45](changelog/1.3/CHANGELOG.md#cr45) | P3 | ✅ **DONE and live 2026-09-29** — `api-gateway` `51324cf4` | Deleted: the quota DO's `POST /flush-usage`, `flushUsage()`, `QuotaFlushResultSchema`. A POST there now 404s and leaves the counter alone (regression test) |
| [CR47](changelog/1.3/CHANGELOG.md#cr47) | P2 | ✅ **DONE and live 2026-09-28** — toolkit `bbdb63ad` pushed and deployed with CR37 step 3 (receiver `3c9b1020`) | Only the call that **creates** a team org makes its caller owner; later joiners are members whatever the plan. Domain grouping requires `email_verified === true`; an unverified corporate address gets a personal org. Production audit: no team org has more than one owner |
| [CR46](changelog/1.3/CHANGELOG.md#cr46) | P3 | ✅ **DONE and live 2026-09-29** — api-gateway `51324cf4`, contact-form `065e8b4a`, sender-worker `e1bba9b8` (CI, `b2f88e6`) | `workers/lib/http/cors.ts` (`buildCors`) is the one CORS helper; api-gateway, contact-form and sender-worker use it, and root `cors-utils.ts` / `http-helpers.ts` are deleted. Live after `deploy:prd` of api-gateway and contact-form and a `main` push (sender CI) |
| [CR48](#cr48) | P2 | ⚠️ **live 2026-09-29; shared session verified by the owner** — a starter sign-up → `/provision` → key ran in production 2026-09-30; a paid-tier sign-up on to checkout has not | integritystudio.ai signs in through **Auth0 Universal Login** (authorization code + PKCE) with the `integritystudio-dashboard` SPA client, so it shares one Auth0 session with integritystudio.dev and the Observability card opens without a second login. The ROPC form is gone. |
| [CR49](changelog/1.4/CHANGELOG.md#cr49) | P2 | ✅ **DONE and live 2026-10-07** — routes gone from production `sender-worker` `04afc2eb` (CI from `91f9a1f8`; 404 sampled twice); "My App" `password` grant removed, so production ROPC is on 0 of 6 clients. The six unread `AUTH0_*` secrets were unbound from both sender Workers the same day (12 → 6 each) | Retire sender `/signin`, `/signup`, `/forgot-password` and the "My App" `password` grant — nothing in the app calls them after CR48. |
| [CR50](changelog/1.3/CHANGELOG.md#cr50) | P3 | ✅ **live 2026-09-29** — migration `20260929010000` (`bdcad7c`) applied by `supabase db push`; post-check: 0 users without a default org, 0 tier mismatches, trigger enabled, ledger row present. First new signup (2026-09-30) got its personal org as default; the receiver never writes the column, so very likely the trigger (the column has no timestamp) | New users get no `users.default_organization_id` (1 of 10 in production: the 2026-09-29 smoke-test account), so `users.tier` never follows their org's plan. |
| [CR51](changelog/1.3/CHANGELOG.md#cr51) | P2 | ✅ **live 2026-09-29, verified 2026-10-01** — Action **v10** (`44f65b19…`) deployed from `03e8941`, deployed code digest equals the repo file's (re-read 2026-10-01); rollback target v9 `ff8dbac8…`. Post-deploy sign-ins ran clean: the normal path (2026-10-01) and the unverified-skip branch on a real re-registered address (2026-09-30). The case it blocks — an old row still holding the address — is unit-tested only | The post-login Action's email fallback re-links an existing `users` row to any new Auth0 identity with that email, without checking `email_verified`. |
| [CR52](changelog/1.3/CHANGELOG.md#cr52) | P3 | ✅ **live 2026-09-29** — Pages deploy from `18dc515` (CI run 36603821038, all jobs green); Usage fetches its own quota, the dead `monthlyUnitsQuota` arg is gone, and the usage-bar row no longer overflows once a quota renders. **Follow-ups 2026-09-29** (best-practice review; see [CR58](changelog/1.3/CHANGELOG.md#cr58), [CR59](#cr59)): the bar reads the enforced `monthlyUsed` (chart and table keep bucket totals), states its level in words with a threshold `Alert`, has a screen-reader name and value, shows the UTC reset date, says "Unlimited plan", and has a limit-reached state | The dashboard hub passes `monthlyUnitsQuota: 0` to Usage, so the quota line never renders. |
| [CR53](changelog/1.3/CHANGELOG.md#cr53) | P3 | ✅ **live 2026-09-29** — `api-gateway` `cf663fae` (`8b4d726`); `/health` healthy after deploy. The 503 path itself is unit-tested, not probed live | `/v1/orgs` answers `200 {organizations: []}` when its Supabase queries fail; since CR48 the callback reads that as a new account. |
| [CR54](changelog/1.4/CHANGELOG.md#cr54) | P3 | ✅ **live 2026-10-07** — `api-gateway` `ad299722` (GET and POST `/v1/me/team` answer 401 unauthenticated, not the router 404; preflight 204) and the dashboard card via the Pages deploy from `91f9a1f8`. An authenticated join has not been run in production | A corporate signup is always unverified at its first provision, so it lands in a personal org — and nothing ever provisions it again to join the team org once verified. |
| [CR55](changelog/1.3/CHANGELOG.md#cr55) | P4 | ✅ done (`8bfe535`, tests only) | `CallbackPage`'s signup analytics (form submission + lead, new accounts only) have no test. |
| [CR56](changelog/1.3/CHANGELOG.md#cr56) | P4 | ✅ **live 2026-10-01** — goes to in-app `/dashboard`; fix `c655e962` first shipped in the Pages deploy from `b4c9c8a1` (07:59Z) | `/provision`'s **Go to Dashboard** opens integritystudio.dev, not the in-app `/dashboard` where billing and usage live. |
| [CR57](changelog/1.3/CHANGELOG.md#cr57) | P4 | ✅ **live 2026-09-29** — `25856d4`, Pages deploy from `18dc515` | `Auth0Service.constantTimeEquals` returns early on a length mismatch (code review, low; no practical leak). |
| [CR58](changelog/1.3/CHANGELOG.md#cr58) | P2 | ✅ **live 2026-09-29** — gateway `a89bc4b8` (`8f08812`), `/health` 200 after deploy; page via the Pages deploy from `18dc515` | Reading usage or quota spent the quota: every `/v1/orgs/:id/*` call, including `/usage/summary` and `/quota/status`, reserved a monthly unit, and the Usage page polled every 30 s, even while hidden. |
| [CR59](changelog/1.4/CHANGELOG.md#cr59) | P4 | ✅ **live 2026-10-06** — `deploy:prd` from `34f80f24`: `api-gateway` `43f5184e`, `contact-form` `85d28a02`; `Access-Control-Expose-Headers` read back on both. The 429 path itself is unit-tested, not probed live. Code `f14f0b8f`; named constants plus tests for the expose lists and the minute reset `2db6eed3` (behaviour-neutral, not redeployed) | The gateway's quota headers are non-standard, undocumented as sent, and unreadable from a browser. |
| [CR60](#cr60) | P4 | 📋 open (measured) | `users.last_login` moves on silent sign-ins that reuse the Auth0 session, which Auth0 does not count as logins; CR48's shared session makes them common. |
| [CR63](changelog/1.3/CHANGELOG.md#cr63) | P2 | ✅ **live 2026-10-06** — `deploy:prd` from `705fa389`, version `25e72a57`; `/health` 200, preflight 204, both admin paths 401 unauthenticated, unrouted sub-path 404. Authenticated staff reads made from the production dashboard at 03:01–03:03Z the same night (audit rows 2–8, one per org); ten-plus admin reads of one org wrote no `usage_events` row | Staff read routes `/v1/admin/orgs*` for the observability dashboard's admin customer view: any org's billing, usage, quota and entitlements without membership, quota, rate limit or a ledger row. |
| [CR62](changelog/1.3/CHANGELOG.md#cr62) | P3 | ✅ **done 2026-10-06** — the deployed dashboard reads its own `users` row from Supabase with the Auth0 ID token; owner confirmed the header badge on production | Auth0 is a Third-Party Auth provider on both projects. Dev proves the path end to end; production has the `auth.uid()`-free read policies and Action v12 with the `role` gate open for the dashboard SPA, and the deployed dashboard reads its own `users` row with the ID token (merged `1c4af99`, deployed 2026-10-06). |
| [CR61](changelog/1.3/CHANGELOG.md#cr61) | P2 | ✅ **done 2026-10-06** — `20261005000000` and `20261006000000` live on production and dev, sign-up off, six test accounts deleted, nothing was planted; `public` now has no client-usable write policy, asserted on every replay. Pushed and CI green 2026-10-06. | Supabase Auth sign-up is open on production, and three RLS policies let a signed-in account plant its own `users` row and forge or rewrite its own `api_keys` rows. Steps to apply `20261005000000_drop_client_write_policies`. |

~~**Two items are now blocked on code** — [[CR20]] and [[CR21]]…~~ **Superseded 2026-07-31.** [[CR21]] is done and live, and [[CR20]] is not blocked on code at all — its remaining work is monitoring ([[W04]]), since [[CR21]] foreclosed the 5xx option. [[CR19]] was fixed 2026-07-27 (commits eaaa199, 9741594). What still needs a decision rather than an implementation: a credential/provisioning call (CR01, CR11, CR12's cross-repo HMAC secret), or an answer about intent (CR13, CR16). **Update 2026-09-28:** CR01, CR11, CR12 and CR13 are closed, and [[W04]] closed 2026-08-09 (1.3 changelog); of this list only CR16 remains, and it is by design.

~~**Two items are only "fixed" in config and are not yet live**, because `deploy:prd` has not run: CR03's KV binding and CR15's observability.~~ **Both went live in the 2026-07-30 deploy** — corrected 2026-07-31; this line outlived its own subject by a day, which is the same "merged ≠ live" error inverted. CR14's `preview_urls` is live on all four secret-bearing Workers and, since 2026-07-31, pinned by tests for all four rather than two. CI deploys `sender-worker` on merge to `main`; the others are manual.

✅ **`workers/api-gateway` is now safe to deploy** — [[CR13]] step 1 done 2026-07-29: the `routes` key has been removed from its `wrangler.toml`, so `deploy:prd` will not claim `api.integritystudio.ai/v1/*`. **Update 2026-09-28:** `routes` is back on purpose — [[CR13]] (2026-08-08, `a61e4a6`) added `[{ pattern = "api.integritystudio.dev", custom_domain = true }]`. It still does not claim `api.integritystudio.ai/v1/*`.

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

<a id="cr25"></a>

### CR25: Auth0 tenant production-readiness (before flipping `dev-68gg87ow4mg4kzyo` to Production)

**Priority:** P2 | **Source:** session 2026-07-29, Management API audit of tenant `dev-68gg87ow4mg4kzyo`
**Estimated:** ~~the two remaining hard blockers…~~ **Restructured 2026-08-03** — the five open items were split into their own tracked items ([[CR32]] custom domain, [[CR33]] log streams, [[CR34]] implicit/ROPC strip, [[CR35]] breached-password), each with a distinct blocker (owner decision / build / verification / spend). What remains *inside* CR25 is one thing: **item 2, MFA enforcement (owner decision).**

**Status (restructured 2026-08-03; deferred 2026-10-06):** ⏸️ **Deferred by the owner 2026-10-06 — MFA enforcement, the one remaining item.** Of the original 13: 8 done (item 1 Google dev-keys disabled, 5 branding, 9 `Default App` grants stripped, 10 token 24h→8h, 11 dev clients OIDC-conformant, 12 stale slots deleted, plus the former 🔴 `integrity-dev-m2m` finding, deleted in CR11's Auth0 cutover — no active security finding remains), **4 carved out into their own items** (custom domain → [[CR32]], log streams → [[CR33]], implicit/ROPC → [[CR34]], breached-password → [[CR35]]), and **1 still tracked here: item 2, MFA enforcement** — factors are available (`otp` + `recovery-code`) but `GET /guardian/policies` is `[]`, so MFA is not required of anyone. Enabling enforcement forces all ~96 users to enrol at next login, so it is an owner decision (consider admins-only). That decision is the whole of CR25's remaining work.

Not counted as a CR25 blocker but adjacent: **item 10's real end state (1h token) is blocked on client refresh-token work**, which is application code, not Auth0 config.

The Dashboard's production-checks page (`manage.auth0.com/dashboard/us/dev-68gg87ow4mg4kzyo/production-checks`) **cannot be read programmatically** — it is behind an interactive login and `WebFetch` gets redirected to `auth0.auth0.com/authorize`. Everything below was therefore checked against the Management API directly, which is the authoritative source anyway.

**🔴 Blockers**

1. ✅ **FIXED 2026-07-29 — the Google connection ran on Auth0 development keys.** `con_ObPVzoOXoF6DWEtA` (`google-oauth2`) had no `options.client_id` or `options.client_secret`, so it used Auth0's shared, Auth0-owned Google application: heavily rate-limited, with a consent screen showing Auth0's name rather than Integrity Studio's. It was **enabled on 6 applications** while **no one used it** — all 96 identities in the tenant are database (`auth0`) identities, zero `google-oauth2`. **Fix applied:** disabled for every application via `PATCH /api/v2/connections/{id}/clients` with `status:false` (→ 204), verified `0` clients enabled, so Google cannot appear on any login page. The connection object was **deliberately kept, not deleted**, so it is one PATCH to restore once real Google Cloud OAuth credentials exist — at which point set `options.client_id`/`client_secret` *before* re-enabling.
2. ⏸️ **PARTIALLY FIXED 2026-07-29; enforcement deferred by the owner 2026-10-06 — MFA factors are available, enforcement is not.** Every factor had been disabled (`GET /api/v2/guardian/factors`) even though both database connections have `options.mfa.active: true`, so no second factor could be enrolled by anyone — on a system that mints customer API keys. **Fix applied:** enabled `otp` (authenticator app) and `recovery-code`. **`GET /api/v2/guardian/policies` was deliberately left `[]`**, which means MFA is now *available for enrolment* but is not *required* of anyone. Turning on enforcement would force all 96 existing users to enrol at their next login — a user-visible change that needs an explicit decision, and the remaining work on this row. Consider requiring it for administrators only rather than tenant-wide.
3. ➡️ **Carved out to [[CR35]] (2026-08-03)** — breached-password detection, plan-gated (PATCH 400 "upgrade your subscription"). A spend decision; see CR35.

**Verified after applying the above:** production database login is unaffected — `/signin` 200 with an 855-char JWT and `/send` `ok:true` with real user and org data — the dev-tenant isolation still holds (dev client authenticates the dev user), and all four Workers are healthy.

**Correction to the [[CR11]] auto-enable note:** that entry attributed the surprise client-enablement to `is_domain_connection: true`. That explanation is wrong. The Google connection has `is_domain_connection: false` and **both** `integrity-dev-ropc` and `integrity-dev-m2m` had been auto-enabled on it as well. So Auth0 enables newly created clients on existing connections **regardless** of the domain-connection flag. The operational rule is broader than first written: **after creating any client, audit every connection's client list, not just the domain ones.**

**⚠️ Should fix — user-visible or hygiene**

4. ➡️ **Carved out to [[CR32]] (2026-08-03)** — custom domain. Hostname now decided (`auth.integritystudio.ai`); **corrected 2026-08-06** — it is billing-gated (verified card required), not plan-gated as first read. See CR32.
5. ✅ **FIXED 2026-08-03 — Universal Login branded from real repo assets.** Was `{logo_url: ""}`, no colors. `PATCH /api/v2/branding` set `logo_url` = `https://integritystudio.ai/images/logo.png` and `favicon_url` = `.../icons/favicon-32x32.png` (both live, HTTP 200 on the `.ai` apex — the `.dev` host 404s, so the apex is deliberate), and colors `primary #3B82F6` (theme `blue500`) + `page_background #111827` (theme `gray900`, the app's dark background). Verified by read-back. Reversible: `PATCH` the fields back to `""`/absent.
6. ➡️ **Carved out to [[CR33]] (2026-08-03)** — log streams. Needs a purpose-built receiver (the OTLP ingest can't parse Auth0 events); not a toggle. See CR33.
7–8. ➡️ **Carved out to [[CR34]] (2026-08-03)** — `implicit` grant on the SPA + `My App`, and ROPC on the SPA + `AUTH0_MANAGER`. Minutes by API, but the strip must verify `sender-worker`'s `password-realm` login path survives; see CR34.
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

<a id="cr32"></a>

### CR32: Auth0 custom domain — login runs on a `dev-` hostname (tenant `dev-68gg87ow4mg4kzyo`)

**Priority:** P3 | **Source:** carved out of [[CR25]] item 4, 2026-08-03
**Estimated:** owner decision (hostname) + DNS + verification — **not spend, not a blind toggle**

`GET /api/v2/custom-domains` on the production tenant is empty, so every hosted-login page runs on `dev-68gg87ow4mg4kzyo.us.auth0.com` — users see a hostname containing "dev-".

~~**Measured, not assumed (2026-08-03):** this is **not plan-gated**, contra CR25's original wording. `POST /api/v2/custom-domains` with an empty body returns **400 payload-validation** (missing `type`/`domain`), not the **403** a feature-gated endpoint returns — so the plan allows a custom domain.~~

🔴 **That probe was incomplete, and the incompleteness hid the real gate — corrected 2026-08-06.** An empty body never reaches the billing check; it fails Auth0's payload validation first, so 400-not-403 proved nothing about plan-gating either way. Owner picked the hostname (**`auth.integritystudio.ai`**) and a real, fully-valid `POST /api/v2/custom-domains {"domain":"auth.integritystudio.ai","type":"auth0_managed_certs"}` was sent with a token confirmed to carry `create:custom_domains` scope. It returned:

```json
{"statusCode":403,"error":"Forbidden","message":"There must be a verified credit card on file to perform this operation","errorCode":"operation_not_supported"}
```

**So it is gated, just not the way either version of this entry claimed.** Not a hard plan-tier lock (the earlier "not plan-gated" framing) and not quite the M2M-scope or DNS blocker this entry expected either — it's a **billing prerequisite**: Auth0 requires a verified card on file before provisioning the TLS/cert infrastructure a custom domain needs, independent of whether the current plan nominally includes the feature. Whether adding a card alone clears this (no plan change) or it also requires an upgrade **is not visible from the Management API** — billing/subscription state is a Dashboard-only surface, same class of gap as CR35's plan-gate. This needs the account owner to check the Auth0 Dashboard billing page and add a verified card; only then can the `POST` above be retried.

DNS is not the blocker and was confirmed ready in the same pass: `integritystudio.ai` resolves via Cloudflare nameservers (`kristina`/`tony.ns.cloudflare.com`), zone id `822492ca06069b369c2a75d3789fb7fa` is reachable with the existing `CLOUDFLARE_API_TOKEN`, and `auth.integritystudio.ai` currently has no CNAME/TXT records — a clean slate, no conflicting record to remove first.

**Sequence, unchanged, resumable the moment the card is added:** retry the `POST /custom-domains` above → read back the verification records it returns → add them to the Cloudflare zone (confirmed reachable) → `POST /custom-domains/{id}/verify` → update the app's allowed callback/logout URLs and `AUTH0_DOMAIN` consumers if the login URL is user-facing. The "permanence" caveat below still applies once it succeeds.

**Permanence, unchanged:** a custom domain makes the tenant permanent — moving or removing it later invalidates existing sessions and bookmarks. That is why it should not be created speculatively, and why this stops here rather than working around the billing gate.

**Status:** ⏸️ **Deferred by the owner 2026-10-06** — blocked on adding a verified card to the Auth0 account (owner, Dashboard-only). Hostname is decided (`auth.integritystudio.ai`), DNS is confirmed ready, and everything from the retried `POST` onward is scriptable from here the moment the card is on file.

---

<a id="cr35"></a>

### CR35: Auth0 breached-password detection is gated behind a paid subscription

**Priority:** P3 | **Source:** carved out of [[CR25]] item 3, 2026-08-03
**Estimated:** spend decision — nothing to configure until the plan changes

`PATCH /api/v2/attack-protection/breached-password-detection` returns **HTTP 400 `"Please upgrade your subscription to enforce breached password detection"`**, and `GET` confirms it stays `enabled: false`. Unlike the custom domain (CR32 — probed 400-not-403, so *available*), this one is genuinely plan-gated: the 400 carries the upgrade message.

**Not a config item — a spend decision.** The two attack-protection features included on the current plan are on and were re-verified: brute-force protection (`block`, `user_notification`) and suspicious-IP throttling (`admin_notification`, `block`). Breached-password (a.k.a. credential-guard / compromised-credential detection) is the paid increment.

**Status:** ⏸️ **Deferred by the owner 2026-10-06** — blocked on a plan upgrade. Re-attempt the PATCH after any Auth0 plan change; no other work needed.

---

*Last updated: 2026-03-21 — backlog-implementer + backlog-migrate + auto-error-resolver session: L6/L7/L10/L11/L12/L13 marked done (38c339c); M36 fixed (7d86372); L5 env binding added (5c7a443, 8cdaa09, 306ccfc); 27 items migrated to v1.2; CSP test failure diagnosed and fixed (47b4dc3); L16 + M37 migrated to v1.2 changelog (2 completed items). Test Status: ✅ ALL 2631 TESTS PASSING. Remaining: T25, T28, V02-Remaining, M34, M38, M39 (6 deferred/design-decision items). Score: 9/10.*

*Backlog-implementer continuation (2026-03-21): L16 refactored (AppDecorations.card() 5786939, PASS); M34 fixed with soft-delete + active-only filter (33aa1a2, cf5059c, PASS); M37 verified done (no new commits). Test Status: ✅ 61 stripe-webhook tests passing. Remaining open items: 4 (T25, T28, M38, M39 require design decisions). Items completed: 2 (L16, M34). Score: 9/10.*

*Backlog-implementer session (2026-03-21): H3 DB filter fix (b2d23fe, PASS); H4 stripe_customer_id validation (162983d, PASS); M40 audit log waitUntil (8f999e6, PASS); M41 APP_URL env escalation (826d2f3, PASS); M42 503 retry + test fix (8b6120f, 51f8ad8, PASS); L20 error sanitization (32ee699, PASS); L21 insert call count assertion (32ee699, PASS); L22 billing_admin audit log count (user-applied); L23 sanitize read endpoint errors + fetchOrgList (15da535, c586ee8, 2ece18a, PASS). Test Status: ✅ 35 Dart + 17 TS tests passing. Items completed: 9. Remaining: T25, T28, M18 (design decisions / external deps). Score: 9/10.*

*Backlog-implementer session (2026-03-21): OTEL-1 POST /v1/ingest/otel implemented — OtelSpanSchema, IngestOtelRequestSchema, handleIngestOtel with API-key auth + quota enforcement + attribute size caps (1b771e3, c40a1c8, PASS); 10 new tests. Payments roadmap "Telemetry/monitoring setup" item DONE. Test Status: ✅ 120 api-gateway tests passing. Items completed: 1. Remaining: T28 (design decision). Score: 9/10.*

*Backlog-implementer session (2026-03-21): L23 rate-limit headers forwarded (e743c68, PASS); L25 OTEL_INGEST_ROUTE exported (2aa30eb, PASS); L24 start_time_ms upper bound refine (32658b9, PASS); L22 makeOpts typed as SupabaseClient|undefined (ce4c563, PASS); final review high finding addressed — applyRateLimitHeaders helper + boundary tests (5e5d2c4). Test Status: ✅ 122 api-gateway tests passing. Items completed: 4 (L22-L25). Remaining: T28 (design decision). Score: 10/10.*

*Code-review remediation session (2026-07-26): recovered and consolidated the 8-area review (43 items / 51 findings), fixed the PostgREST `Prefer` header and the `/signup?tier=Team` routing break, then a backlog pass closed 38 more. Added CR01–CR10 for the remainder: the 5 items never fixed, 2 marked-fixed-but-not-closed (inert rate limiter, JWT still in a URL fragment), and 3 found while converting the api-gateway and stripe-webhook tests to drive a real Supabase client over a stubbed transport. Test Status: ✅ 3,001 Flutter + 984 worker tests passing; zero TypeScript errors across all 7 workers.*

*⚠️ **Every SHA in this paragraph is dead** — CR01's history scrub and force-push on 2026-07-29 rewrote all commits preceding it, so **76 of the 85** seven-hex SHAs cited in this file no longer resolve (`git cat-file -t` → "Not a valid object name"). `d632263` below is really `1c83136`. Match on the change description, not the hash.*

*Backlog-implementer session (2026-07-26): CR01 doppler.json removed from git + .gitignore (88ef77a); CR05 usage/entitlements endpoints return 5xx on DB error (d11cf38); CR06 me.ts splits DB error from 404 (d11cf38); CR04 provision_page.dart comment corrected (d632263); CR07 CLAUDE.md status block refreshed (8d4c8e2); CR08 ~18 dead Array.isArray checks removed (2ada4e9); CR09 handler test fixtures use HTTP-format errors (424bbd2); CR10 fetchPendingDeadLetters null phantom filtered (1a8196a). CR02 (dev/prod separation) and CR03 (RATE_LIMIT_KV) deferred — need live wrangler/CF operations. CR01 steps 2–3 (history scrub + rotation) deferred to maintenance window. CR04 full fix deferred — cross-repo. CR05–CR10 migrated to the 1.3 changelog (*Review Backlog Pass*) and removed from this section. Test Status: ✅ 3,001 Flutter + 984 worker tests passing; zero TypeScript errors across all 7 workers.*

---

<a id="cr48"></a>

### CR48: integritystudio.ai signs in through Auth0 Universal Login, sharing one session with integritystudio.dev

**Priority:** P2 | **Source:** session 2026-09-29, the Observability card (`d20b1d9`) sent signed-in users to integritystudio.dev, which asked them to log in again
**Estimated:** done in code; remaining work is verification and the push

**Why:** `/login` and `/signup` exchanged the password server-side (sender `/signin`, `/signup`, Auth0 `password` grant on "My App"). That never creates an Auth0 browser session, so integritystudio.dev's SPA had nothing to reuse. Signing in on Auth0's own page with the SPA client integritystudio.dev already uses gives both sites one session.

**Deployed 2026-09-29:** `b2f88e6` pushed to `main`; every workflow green, including Deploy to Cloudflare Pages. Both `integritystudio.ai` and `www.` serve a `main.dart.js` carrying the production client id (and not the dev one), the CSP allows `dev-68gg87ow4mg4kzyo.us.auth0.com`, and `/callback` loads.

**What changed:**
- `lib/services/auth0_service.dart` (+ `auth0_browser{,_web,_stub}.dart`, `auth0_config.dart`): authorization code + PKCE S256, single-use state/verifier in sessionStorage, rotating refresh token in localStorage, one in-flight refresh at a time, `/v2/logout` on sign-out. Prod defaults; `--dart-define=AUTH0_DOMAIN/AUTH0_CLIENT_ID` selects the dev tenant.
- `/callback` (`CallbackPage`): exchanges the code, then `GET /v1/orgs` — no orgs → `/provision`, otherwise `/dashboard`. This is the route a new account never had.
- `/login` is a "Continue to Sign In" hand-off; `/forgot-password` redirects to it (reset is on Auth0's page). `/signup` keeps tier, email, company and terms, drops the password, and carries `{tier, orgName}` across the redirect.
- `/provision` sends the email exactly as Auth0 returns it (the receiver compares it byte for byte with `/userinfo`) and the enterprise company as `org_name`. A paid tier goes to checkout **after** provisioning, so the checkout session resolves to an org that exists.
- `/dashboard` without in-app args restores the stored session (reload, bookmark, new tab); its sub-pages route through it. The dashboard has a **Sign out** button that also ends the integritystudio.dev session.
- Removed: `ProvisioningService.signIn/signUp/forgotPassword`, `AuthSuccess/AuthError`, `AuthStorage`, `PasswordPolicy`. CSP `connect-src` allows both tenants' token endpoints.
- Tests: 2780 green, `flutter analyze` clean. Mutation-checked: dropping the refresh memo, the state comparison, or the refuse-vs-network distinction each fails its own test.

**Auth0 changes (applied 2026-09-29, additive, re-read after PATCH):** prod `integritystudio-dashboard` gained `https://www.integritystudio.ai/callback`, logout `https://www.integritystudio.ai/`, and web/allowed origins `https://integritystudio.ai` + `https://www.integritystudio.ai` (the existing `https://integritystudio.ai/` entries carry a trailing slash, which never equals an `Origin` header). Dev `integritystudio-dashboard-dev` gained `http://localhost:8080` (callback, logout, origins). Probed without credentials: every origin's `/authorize` returns 302 to `/u/login` (`/u/signup` with `screen_hint`), and `/oauth/token` returns its `Access-Control-Allow-Origin`; an unlisted origin gets 403 and no CORS header.

**Remaining:**
1. Click-through on the local release build against the dev tenant and dev Workers: sign up → `/callback` → `/provision` issues a key → dashboard lists the org; sign out → sign in → `/dashboard`; reload `/dashboard` stays signed in; growth signup → provision → checkout (sandbox) → the dev webhook updates the plan.
2. ~~Push `main`~~ ✅ done (above). ✅ **Verified by the owner 2026-09-29:** signed in at integritystudio.ai, opened **Observability**, and integritystudio.dev loaded **without** a login prompt — the shared session this item exists for.
3. Still unexercised in production: a **paid-tier** sign-up on to checkout. ✅ **A starter new-account sign-up ran in production 2026-09-30** (measured 2026-10-01): `alwaysrunningfast@gmail.com` signed up on Auth0's screen at 05:02:20Z (`ss` on `integritystudio-dashboard`), and its personal `starter` org (05:02:27Z) and API key (05:02:29Z) followed, which is the `/provision` → receiver path. Whether the dashboard then listed the org was not measured. ~~`alwaysrunningfast@gmail.com` (created by the old sender `/signup`) signing in through Universal Login~~ — **cannot be exercised for that account any more**: its sender-created identity was deleted 2026-09-30 04:52Z, before the re-signup (see [[CR51]]). Any other sender-created account's first Universal Login sign-in is the remaining case.

**Known limits:**
- Refresh-token rotation `leeway` is `0` on both SPA clients. Two tabs refreshing the same token at the same instant counts as reuse, and Auth0 revokes the family (both tabs signed out). In-tab calls are serialised; cross-tab is not. Setting a small `leeway` on the client would absorb it, but the client is shared with integritystudio.dev, so decide there.
- The old flow's `auth_jwt` localStorage key is no longer written or read, and is not cleared; it expires with its token.

---



<a id="cr60"></a>

### CR60: `users.last_login` moves on silent sign-ins, which Auth0 does not count as logins

**Priority:** P4 | **Source:** [[CR51]] verification 2026-10-01; `auth0/actions/provision-user-and-enrich-token.cjs` `profileFields`

**Status:** ✅ **Code done 2026-10-07, not deployed.** `profileFields` now writes `last_login` as the latest `event.authentication.methods[].timestamp` — the methods completed during the *session*, so a login writes its own time and a session reuse rewrites the original login time, which is Auth0's `last_login`. A method older than `SILENT_SIGN_IN_MAX_AGE_MS` (60 s) is logged as `silent sign-in for <subject>: session authenticated <time>, not counted as a login`. Only an event with no methods falls back to now; the refresh-token skip is unchanged. Three tests added (login, the measured 05:02:20Z → 05:05:36Z silent case, no-methods fallback); the two that pin the timestamp fail when the write reverts to `new Date()`. **Still to do:** deploy the Action to the production tenant (version 14; the README's deploy steps rebind the secrets from Doppler) and, after the next real silent sign-in, confirm the row's `last_login` equals Auth0's.

- **Measured.** `alwaysrunningfast@gmail.com` (`auth0|6abc97dc…`) has two `s` events on 2026-09-30:
  - 05:02:21Z, prompts `prompt-signup` and `login`.
  - 05:05:36Z, no prompts: an `/authorize` that reused the Auth0 session.
  - Auth0's user record says `logins_count` 1 and `last_login` 05:02:20Z. The row says `login_count` 1 (Auth0's count, so it agrees) but `last_login` 05:05:35.735Z, the second execution's start time.
- **Cause.** `profileFields` skips `last_login` only when `transaction.protocol` is `oauth2-refresh-token` ([[UA02]]). A silent sign-in also runs post-login, and Auth0 does not count it. Since [[CR48]], integritystudio.ai and integritystudio.dev share one Auth0 session, so opening one after signing in to the other is this case.
- **Impact.** None today: [[UA02]]'s investigation found no reader of `last_login` in either repo. It matters for the first "inactive user" query or admin page.
- **Fix shape (decide first).**
  - Write `last_login` only when Auth0 counted a login. A candidate is the latest `event.authentication.methods[].timestamp`; check that it keeps the original time on a session reuse before relying on it.
  - Or document the column as "last `/authorize`", not "last login".
  - Add a silent-sign-in case to `provision-user-and-enrich-token.test.ts` either way.
- **Acceptance.** A silent sign-in leaves `users.last_login` equal to Auth0's `last_login`.

---

## User Data-Integrity Audit 2026-09-18 → 2026-09-22 (UA01–UA08)

> Finished items from this section moved to [changelog 1.3](changelog/1.3/CHANGELOG.md) on 2026-10-04; only open or partly done items remain below.

Filed from a read of one paying user (`alyshia@inventoryai.io`, org `team-inventoryai-io`, plan growth) across Supabase, Auth0, Stripe, the obtool AUTH KV and the query API. What was wrong for that user and fixed the same day is not here (users.tier set to growth; `/v1/me` reads the org plan, `6dc91c2`; the webhook writes the billing period from the first item, `1a29d7b`; the InventoryAI and gmail keys now reach Doppler and the obtool resolver). What is here is what the audit showed to be true of **every** org or user — measured, not inferred, and each stated with the number that would change if it were fixed.

### ❌ UA12 — won't do (2026-09-27): Doppler prd `SUPABASE_SERVICE_ROLE_KEY` is a third live service-level key, origin unrecorded

**Priority:** P2 | **Source:** session 2026-09-27, count-only PostgREST probe

The slot CLAUDE.md said "exists in no config" now holds an `sb_secret_` key (41 chars, sha1 prefix `d1ace259a923`). Against production, `GET /rest/v1/organizations?select=id&limit=0` with `Prefer: count=exact` returned `206`, `content-range */7`: it sees every org through RLS, so it has full service-role access. It matches neither `SUPABASE_PROVISIONING_KEY` nor `SUPABASE_INTEGRITY_MEMERSHIP_KEY`, so `prd` now holds three distinct live bypass keys. Every Worker binds its service key under this same name, and the bound values cannot be read back, so which key production runs on is unknown. **Isolation holds:** `dev`'s `SUPABASE_SERVICE_ROLE_KEY` (`b9341dcac1c3`) gets `401 Invalid API key` against production and `206 */6` against its own project (positive control). `check-env-isolation.sh` watches the slot but only checks that the two values differ. **Scope:** in the Supabase Dashboard (API Keys), identify the named key behind each of the three and when it was created. Decide the single key production should use, re-bind the Workers to it with `wrangler secret put`, then revoke the others at Supabase **before** clearing their Doppler slots.

**Won't do (owner decision 2026-09-27):** this is a service key, not an application access key. Holding it in `prd` alongside the others is intended, so there is nothing to consolidate or revoke.

## Test Suite Review 2026-09-27 (TS01–TS16)

> Finished items from this section moved to [changelog 1.3](changelog/1.3/CHANGELOG.md) on 2026-10-04 (TS11 on 2026-10-05); none remain open.

Filed from a nine-area review of every test file, read against the code under test — not from `docs/repomix/tests-compressed.xml`, which strips every `test()`/`it()` body. The review's summary (method, section → item map, verified-not-problems, unfiled gaps) is in [changelog 1.3](changelog/1.3/CHANGELOG.md#test-suite-review-2026-09-27); the full per-area reports are in git history. Section letters below refer to it. Done in the same session and **not** listed here: the ~230 `workers/lib` tests of schemas no request parses were deleted (`bf12226`), `CreateApiKeyBodySchema` was wired into the create-key route (`df174a2`), and `AuditActionSchema` was narrowed to the four emitted actions and enforced at runtime in `writeAuditLog` (`df174a2`, `a3aa746`).

## Coverage Audit 2026-09-28 (TS19–TS25)

> Finished items from this section moved to [changelog 1.3](changelog/1.3/CHANGELOG.md) on 2026-10-04; only open or partly done items remain below.

Filed from a coverage audit of the production behaviour touched on 2026-09-27 (CR36, UA11, CR37, CR38, CR41) and from writing the first `api-keys-create` suite (`supabase/tests/edge-functions/`, 53 tests, 12/12 seeded defects caught). Closed in the same pass and **not** listed here: `api-keys-create` had no tests at all, and nothing tested that the CR36 limiter is wired into the router (5 router-level tests, 6/6 seeded wiring defects caught, including moving it ahead of authentication).

## Coverage Review 2026-09-29 (TS26–TS36)

> Finished items from this section moved to [changelog 1.3](changelog/1.3/CHANGELOG.md) on 2026-10-04; only open or partly done items remain below.

Filed from a test-coverage review of the production code changed on 2026-09-29 (CR50–CR58, UA03, and the contact-content and `/contact` route migration), run as four read-only reviewers with seeded mutants. Where an item says a mutant **survives**, it was run, not inferred. Closed in the same pass and **not** listed here:
- **Low-risk fixes** (`918d9dc`…`f72fbbf`):
  - the stale fail-open comments and the misplaced `QuotaThresholds` doc;
  - Try again refreshing the quota;
  - the usage percent capped at 100, a real bug the overage test found;
  - the rollover-recording test;
  - the usage threshold table, which kills 6 of 6 threshold mutants;
  - the `constantTimeEquals` shorter-first cases;
  - `hasLength(1)` for the CR55 signup event;
  - the Action stub failing unrouted requests by name;
  - the fixture FKs matching production.
- **Consolidations** (`b3a8252`…`456314b`):
  - one `fakeQuotaDO`;
  - shared `admittingQuotaDo`/`mapKv`;
  - one `makeDO`/`statusOf`;
  - the CR53 `it.each`;
  - `makeEvent({ user })`;
  - `supabase/tests/_lib/pg-harness.sh`;
  - `withContent`, and `testContentYaml` removed in favour of `realContentWith`;
  - `WidgetTester.pumpPage` for 15 page tests.

### TS30: nothing checks that the production content.yaml has the keys the loader reads, and one is already missing

**Priority:** P3 | **Source:** coverage review 2026-09-29; `lib/services/content_loader.dart`

**Status:** ✅ **DONE 2026-09-29; testimonials deferred** — `test/helpers/content_string_getters.dart` is the shared `(name, getter)` list of all **122** string getters. `content_loader_test`'s fixture table now holds only expected values and looks each getter up by name. The new `test/unit/content/content_yaml_keys_test.dart` loads the real content.yaml and expects every getter to be non-empty: all 122 are set today. It also pins the list to the `static String get` declarations in `content_loader.dart`, so a new getter can't be left out. **Mutants: 3 of 3 killed:** a key renamed in content.yaml, a getter missing from the list, and a mistyped key path. The `methodsHeading` check moved to the non-empty checks in `contact_content_test`, and the constructor round-trip is gone. ⏸️ **Deferred until there are real testimonials (owner, 2026-09-29): `social_proof.testimonials`.** It is still absent, so `socialProofTestimonials` is `[]`. There is **no visible effect**: `SocialProofSection` is commented out of `landing_page.dart` ("hidden until we have real testimonials"). Revisit when real testimonials exist: add them to content.yaml and restore the section, or remove the reader and model field. List and map getters are not in the real-content check. A test over them would fail on this key while it is deferred.

`_getString` returns `''` for a missing key, and only `_getMap` asserts. The getter tests run against the placeholder fixture, never the real file.

- **Live drift:** `social_proof.testimonials` is **not in content.yaml** (verified: the section has `title`, `stats_headline`, `stats`, `logos`). So `AppContent.socialProof`'s testimonials are empty in production, while `content_loader_test` passes because the fixture has the key. Owner to confirm whether testimonials were removed on purpose.
- **Table gaps:** 42 of the 121 string getters have no row in the table.
- **Trivial test:** `contact_content_test`'s new `methodsHeading` assertion only round-trips a required constructor field. The useful place is the non-empty checks at the top of that file.

**Scope:**
- Make the table's `(name, getter)` pairs a shared list.
- Add one parameterized test that loads the real content.yaml and expects every getter to be non-empty, as `signup_tier_consistency_test.dart` does for tiers.
- Fix or remove the testimonials reader.

### TS33: CR50 — the tie-break and the invariant under change are untested

**Priority:** P4 | **Source:** coverage review 2026-09-29; `supabase/migrations/20260929010000_default_org_from_first_membership.sql`, `supabase/tests/default-org-from-membership/`

**Status:** ✅ **DONE 2026-09-29 for the tests; the behaviour questions need a decision** — **Tie:** the fixture adds two users, each with two active memberships sharing one `created_at`. tie-a's higher id arrives first and tie-b's lower id arrives first, so an order by `created_at` alone gets one of them wrong whichever order it returns. T1f and T1g expect the lower membership id. **Mutants: 2 of 2 killed** (dropping `, id`, and `id desc`). **Invariant:** `assert_invariant(label)` runs at the end of each `begin … rollback` block (T4–T7) and at rest (T8). A default cleared inside a block fails it (checked). Suite: 23 assertions; README updated. ⚠️ **Needs a decision (unchanged):**
- a deleted or suspended default membership leaves the default on the old org, and `tier` keeps following it;
- a default set back to null while memberships are active is never refilled;
- the readers (`custom_access_token_hook`, sender checkout) order by `created_at` alone, so on a tie they are not guaranteed to pick the org the backfill stored. Aligning them means adding `, id` to each: a production function change and a Worker deploy.

- **Tie-break (measured):** dropping `, id` from the backfill's `order by` survives 17 of 17 assertions.
  - Ties are realistic, because `now()` is fixed for a whole transaction.
  - The readers (`custom_access_token_hook`, sender checkout) order by `created_at` alone, so on a tie "the same org as the readers" is not guaranteed either.
- **T8 is too narrow:** it runs once, on static data.
- **Unspecified behaviour (owner to confirm):**
  - A deleted or suspended default membership leaves the default pointing at the old org, and `tier` keeps following it.
  - A default set back to null while memberships are active is never refilled.

**Scope:** a tie fixture; the invariant asserted inside each `begin … rollback` block; a decision on the two unspecified cases.
