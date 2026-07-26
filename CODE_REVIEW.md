# Codebase review — final report

**Scope:** Flutter web app + all Cloudflare Workers
**Method:** 8 parallel area sweeps, each finding adversarially verified by an independent agent that re-read the cited source and tried to refute it
**Review date:** 2026-07-24 · **Consolidated & extended:** 2026-07-26

The original run finished all 8 area sweeps, but rate limits killed the last verifier and the final report. All 16 agents' results were recovered from the workflow journal, the 5 findings that never received an adversarial check were verified by hand (3 confirmed, 2 were duplicates of already-confirmed issues), and everything was consolidated here.

**43 line items** below cover **51 confirmed findings** — a few entries bundle two locations in the same file. **3 further claims were refuted** during verification and are listed in the appendix.

## Status

| Severity | Total | Fixed | Open |
|---|---|---|---|
| High | 9 | 9 | 0 |
| Medium | 16 | 4 | 12 |
| Low | 18 | 7 | 11 |
| **Total** | **43** | **20** | **23** |

Items 2 and 7 were fixed on 2026-07-26 (initial pass). Items 1, 3, 4, 5, 6, 9 (High), stripe-webhook verify + auth_page + cookie_banner + contact_section (Medium), and request_failure_page + auth.ts exp + stripe-schemas InvoiceSchema + contact-form CSRF/CRLF + signup_page analytics + status_result_page spacing + shared_app_bar URL (Low) were fixed on 2026-07-26 (backlog-implementer pass). Every other item is unverified-since-review and should be re-confirmed against current `main` before work starts.

---

## High severity

- [x] **1. Meta Pixel tracks every visitor before consent** — `web/index.html:500` loads `js/meta-pixel.js` unconditionally in `<head>`; it runs `fbq('init', …)` and `fbq('track', 'PageView')` immediately. The Dart consent gate `TrackingWeb.injectFacebookPixel()` (`lib/services/tracking_web.dart:165`) is a no-op that only flips a boolean, so the entire ConsentManager architecture is defeated. An EU visitor who rejects all cookies has already been reported to Facebook. GDPR/ePrivacy breach on a site that markets GDPR compliance.

- [x] **2. Primary "Get Started" CTAs route to a nonexistent tier `Team`** — `lib/pages/landing_page.dart:106` and `:169`, plus `Routes.signupTeam` (`lib/config/content/constants.dart:104`), navigated to `/signup?tier=Team`, but content.yaml only defines starter/growth/enterprise. `ContentLoader` returns `''` for missing keys, so the main conversion page rendered a blank heading, blank description, no features, and an unlabeled submit button. `Team` signups also skipped checkout and took the free `/provision` path.
  **Fixed 2026-07-26.** See [Fix notes — item 2](#item-2--team-tier-routing).

- [x] **3. JWT accepted and propagated via URLs** — `/provision?jwt=…&email=…` is trusted from query params with no session binding (`lib/routing/app_router.dart:179`), and the dashboard redirect puts the JWT in `?access_token=` (`lib/pages/provision_page.dart:87-89`). Bearer tokens leak via history/logs/Referer, and an attacker can deep-link a victim into an attacker-controlled session (login-CSRF).

- [x] **4. Signup has no rollback** — `workers/sender-worker/src/index.ts:96` runs Auth0 user creation and Supabase org creation concurrently in `Promise.all` with no compensating cleanup anywhere. Any mid-flow failure leaves orphans, and every retry then fails with "email already registered" — the email is permanently locked out of signup.

- [x] **5. No rate limiting on `/signin` and `/signup`** — sender-worker forwards arbitrary credentials to Auth0 ROPC with no KV/DO rate limiter, no CAPTCHA, and no `auth0-forwarded-for` header (so Auth0's own brute-force protection can't distinguish attackers from legitimate users). The sibling contact-form worker does have KV rate limiting. The verifier noted Auth0's built-in protections still apply crudely, so this is arguably medium-high.

- [x] **6. `workers/lib/supabase.ts:37` — duplicate-column filters are silently overwritten**, so date-range queries (`gte` + `lte` on the same column) lose their lower bound and daily/monthly rollups aggregate all history. String values are also unescaped. *(Same file as item 7, but a separate defect — `serializeFilters` still uses `url.searchParams.set`, which overwrites rather than appends.)*

- [x] **7. `workers/lib/supabase.ts:115` — `returning=representation` sent as a query parameter** instead of the PostgREST `Prefer: return=representation` header, so every gateway DB write path misbehaved/misreported. Confirmed independently by two area verifiers.
  **Fixed 2026-07-26.** See [Fix notes — item 7](#item-7--postgrest-prefer-header).

- [x] **8. Quota consumed before authentication** — `workers/api-gateway/src/index.ts:128` decrements quota before verifying credentials, so an unauthenticated attacker can exhaust any org's rate limit and monthly quota.

- [x] **9. `workers/bootstrap-worker/src/bootstrap.ts:128` — `loadUsageSnapshot` queries columns that don't exist** on `usage_events`, so the usage snapshot is always zeros.

## Medium severity

- [ ] **`doppler.json` — full encrypted secrets export committed to the repo** (37 KB, tracked since commit `faf0ccc`). Anyone with repo read access holds a permanent offline copy of all worker secrets, decryptable the moment any Doppler token leaks. Rotation can't retract it; it needs removal + history scrub + secret rotation. *(newly verified 2026-07-26)*
- [ ] **No dev/prod environment separation for worker deploys** — `npm run deploy` (Doppler dev) and `deploy:prd` both run plain `wrangler deploy` against the same single-name `wrangler.toml`, so a "dev" deploy overwrites the production sender-worker — the exact worker the CI-built Flutter site calls (default URL in `provisioning_service.dart:15`, no `--dart-define` in `ci.yml`). CLAUDE.md's "deploys to dev environment" claim is false. Same pattern in the other workers. *(newly verified 2026-07-26)*
- [ ] `workers/api-gateway/wrangler.toml:5` — routes exist only under `[env.production]` but deploy scripts never pass `--env`, so production routes are never attached; conversely `--env production` would lose the `QUOTA_DO` binding (not inherited).
- [ ] `workers/api-gateway/src/durable-objects/quota.ts:229` — quota DO persists at most every 10s and never for sparse traffic; counts are lost on eviction, under-enforcing monthly limits.
- [ ] `workers/api-gateway/src/lib/quota.ts:126` — plan-key mismatch (`starter` vs `DEFAULT_QUOTAS`' `free`), and a `quota_version` bump resets `monthlyUsed` mid-month.
- [ ] `workers/api-gateway/src/routes/api-keys.ts:67` — any active org member, including viewers, can create/revoke org API keys (no role check).
- [ ] `workers/stripe-webhook/src/index.ts:183` — dead-letter retries replay stale events with no ordering guard, able to regress billing state.
- [x] `workers/stripe-webhook/src/verify.ts:28` — signature parser keeps only the last `v1` value, so webhooks are rejected during Stripe secret rotation.
- [ ] `workers/stripe-webhook/src/index.ts:116` — returns HTTP 200 even when both the handler and dead-letter insert fail; the event is permanently lost.
- [ ] `workers/sender-worker/src/index.ts:49` — `ALLOWED_ORIGINS_JSON` shape unvalidated: a JSON string turns the CORS allowlist into a substring match; a JSON object crashes every request.
- [ ] `workers/sender-worker/src/supabase.ts:29` — `dedupSlug` collides for distinct emails (`a.b@`, `a-b@`, `a+b@` → same slug); the second signup fails permanently (compounds the no-rollback bug in item 4). The `tier` param is unused.
- [ ] `workers/bootstrap-worker/src/index.ts:59` — no CORS/OPTIONS handling (`ALLOWED_ORIGINS_JSON` is dead config); unknown routes return 500 instead of 404.
- [x] `lib/pages/auth_page.dart:114` — mode toggle clears password state but not the visible field (`FormTextField` uses `initialValue`, not a controller), desyncing UI from validation.
- [x] `lib/widgets/consent/cookie_banner.dart:47` — analytics toggle defaults to ON (pre-ticked consent is invalid under GDPR).
- [x] `lib/widgets/sections/contact_section.dart:494` — form analytics hardcodes `success: true` before the request runs; and `:521` — state cleared on success but fields display stale text.
- [ ] `content.yaml:873` — resources doc cards link to unrouted paths `/docs/api` and `/docs/compliance`.

## Low severity

- [ ] `lib/services/consent_manager.dart:200` — consent downgrade never disables already-initialized trackers.
- [ ] `lib/services/provisioning_service.dart:200` — `signUp` returns `AuthSuccess` with an empty JWT when the 201 body lacks `jwt`.
- [ ] `lib/services/content_loader.dart:89` — failed `load()` raises an unhandled async error when there are no concurrent waiters.
- [x] `lib/pages/request_failure_page.dart:101` — "Go to Sign In" navigates to `/signin`, which does not exist (the router defines `/login`).
- [ ] `lib/pages/dashboard_page.dart:17` — dashboard route family unreachable; nothing constructs `DashboardArgs`, so `/dashboard` always redirects to `/login`.
- [ ] `lib/pages/oauth_callback_page.dart:211` — OAuth code callback spins forever; nothing exchanges the code.
- [x] `lib/pages/signup_page.dart:330` — success analytics and the Facebook Lead pixel fire before the signup request is attempted.
- [x] `lib/pages/status_result_page.dart:160` — spacing loop emits all spacers before the items instead of between them.
- [x] `lib/widgets/navigation/shared_app_bar.dart:62` — default CTA hardcodes the absolute production URL instead of an in-app route.
- [ ] `workers/sender-worker/src/index.ts:87` — unhandled TypeError when email is a non-string; and `:295` — the checkout-session handler has no try/catch, so Stripe network failures escape unhandled.
- [x] `workers/lib/auth.ts:86` — `verifyJwt` accepts tokens with no/malformed `exp` as never-expiring (confirmed by two areas).
- [ ] `workers/stripe-webhook/src/index.ts:67` — idempotency guard is check-then-act; concurrent deliveries process an event twice.
- [x] `workers/stripe-webhook/src/stripe-schemas.ts:23` — `InvoiceSchema` rejects `subscription: null`, dead-lettering every non-subscription invoice event.
- [x] `workers/contact-form/src/index.ts:414` — CSRF validation fails open when `CSRF_SECRET` is unset; and `:491` — CRLF from name/organization flows unsanitized into the email Subject header.
- [ ] `workers/bootstrap-worker/src/bootstrap.ts:83` — crashes on `orgs[0].id` when memberships exist but no org row matches; the organizations table is fetched unfiltered.
- [ ] `workers/cors-utils.ts:20` — reflects the caller's origin into `Access-Control-Allow-Origin` unconditionally; the allowlist only gates the credentials flag.
- [ ] `workers/receiver-worker/src/index.ts:72` — the stub's replay protection is a 5-minute timestamp window with no nonce cache (local test double only).
- [ ] `test/unit/csp_config_test.dart:163` — the frame-ancestors clickjacking test passes by matching an HTML comment in `index.html`; the real policy lives in `web/_headers`, which the test never inspects, so it stays green if that protection is deleted. *(newly verified 2026-07-26)*

---

## Fix notes

### Item 7 — PostgREST Prefer header

**Files:** `workers/lib/supabase.ts`, `workers/api-gateway/src/routes/api-keys.ts`, `workers/lib/types/supabase.ts` (+ tests)

PostgREST only honors `return=representation` via the `Prefer` header; the query parameter was ignored entirely, so the two write paths failed differently:

- **`insert()` was hard-failing every call.** Without the header PostgREST returns `201` with an empty body. The old code unconditionally called `response.json()` on any 201, which threw a `SyntaxError`, got swallowed by the `catch`, and returned `{ok: false}`. Every insert reported failure even though the row was written — API-key creation returned a 500 to the user after successfully inserting the key, and audit-log, usage-event, and webhook-log writes logged errors on success.
- **`update()` was silently returning nothing.** Without the header PostgREST returns `204 No Content`, but the code only parsed a body on `200`, so it fell through to `{ok: true, data: null}` — callers asking for updated rows always got `null` with no error.

Both functions now compute `returning` once, send `Prefer: return=<value>`, and gate body parsing on the same value. `upsert()` already did this correctly and was left alone.

**Follow-up cleanup (same change set):** `workers/lib/types/supabase.ts` declared `InsertOptionsSchema`/`UpdateOptionsSchema` with `returning: 'minimal' | 'representation'` plus a `select` field, while the client took `returning?: boolean` and supported no `select` — schemas that were exported and tested but never imported by the client they described. The client now consumes `InsertOptions`, `UpdateOptions`, `QueryOptions`, and `QueryFilter` from that module as its parameter types, the three duplicate row interfaces are re-exported instead of redeclared, `returning` uses the string form (mapping 1:1 onto the header, so `return=minimal` is now sent explicitly), and the unimplemented `select` field was dropped from the write schemas. Adopting `QueryFilter` also tightens `operator` from a bare `string` to the enum — every operator in use across the workers (`eq`, `gte`, `lt`, `neq`, `in`, `lte`, `is`) is within it. All schema imports are `import type` so no Zod is pulled into workers that only make REST calls.

**Verification:** new `workers/lib/supabase.test.ts` (5 tests) covers the header, the absence of the stale query param, body parsing on 201/200, and the no-body 201/204 paths. The shared client had no HTTP-level test at all — every existing test mocks `sb.insert`/`sb.update` rather than `fetch`, which is why this shipped. Confirmed the tests catch the bug by stashing the fix and re-running: 3 of 5 fail against the old code. Suites: shared lib 400, api-gateway 122, stripe-webhook 137, bootstrap-worker 4 — all passing. `tsc --noEmit` clean for lib, stripe-webhook, bootstrap-worker, sender-worker, contact-form, receiver-worker. api-gateway reports 19 pre-existing errors (vitest mock typing in `ingest.test.ts`), unchanged from baseline.

### Item 2 — `Team` tier routing

**Files:** `lib/config/content/constants.dart`, `lib/pages/landing_page.dart`, `lib/config/content.dart`, `lib/config/content/services_content.dart`, `lib/widgets/sections/services_section.dart`, `lib/routing/app_router.dart`, `lib/pages/signup_page.dart`, `lib/pages/checkout_page.dart` (+ test)

**Root cause:** `Team` was the middle tier's name in `lib/config/content/pricing_content.dart`, but content.yaml was later renamed to `Growth` to match the backend enum `starter | growth | enterprise` (`workers/lib/types/schemas.ts`). The hardcoded CTA links were never updated. The Dart file that still says `Team` is dead code — `PricingContentVariants` and `ServicesContentVariants` have zero references anywhere, and the live pricing table reads from YAML, so it correctly shows Starter/Growth/Enterprise.

**Five** broken call sites were found, not the three originally reported — the services section had two more (`lib/config/content.dart:235` and `lib/widgets/sections/services_section.dart:42`). All now point at `Routes.signupGrowth`; `Routes.signupTeam` is gone.

**A second, unreported bug in the same family was also fixed.** The pricing table passes its *display* name into the URL, producing `/signup?tier=Growth` — capital G. That routes to checkout fine (the comparison lowercases), but was passed verbatim to `ProvisioningService.signUp(tier:)`, where the backend's `ApiKeyTierSchema.safeParse('Growth')` fails and silently falls back to `DEFAULT_TIER = 'starter'`. **Paying Growth customers were being provisioned at the free starter tier.**

The router now normalizes the query parameter through a new `SignupTiers.normalize()`, so `widget.tier` is always a canonical lowercase key before it reaches content lookups, checkout routing, or provisioning. That normalization is also what makes any future bad `?tier=` value degrade to the default instead of rendering a blank page. Supporting changes: `SignupTiers` (canonical keys, default, `normalize`) added to `constants.dart`, and the `'growth'`/`'enterprise'` string literals in `signup_page.dart` and `checkout_page.dart` replaced with those constants.

**The dead Dart content was deleted.** `PricingContentVariants` and `ServicesContentVariants` had no references anywhere, and each file declared nothing else. They were a second, unused source of truth whose stale `Team` tier name is what the broken links were built from, so removing them eliminates the drift risk rather than guarding it.

**The stale `Team` display name was renamed to `Growth`** everywhere else it survived. The live pricing table already read `Growth` from content.yaml, so no production-rendered copy changed; this retired the name from the rate-limit note in `lib/pages/docs_api_page.dart:126`, the unused `PricingConstants.teamTracesLimit`/`teamRetention` constants, a `PricingCard` doc-comment example, the `test/helpers/test_content.dart` fixture, and the tests asserting the old name (`cards_test.dart`, `analytics_test.dart`, `landing_navigation_test.dart`, and the stale "Team tier" test names in `pricing_page_test.dart`, one of which already looked up `t.name == 'Growth'`). Unrelated uses of the word — team-member profiles, "Meet the Team", the `Team` nav item for the about section, "Microsoft Teams", "Team collaboration" — were left alone.

**Verification:** new `test/unit/content/signup_tier_consistency_test.dart` (7 tests) pins the contract — every canonical tier has complete signup content, every pricing tier in YAML maps to a signup entry, and no `.dart` file links to a non-canonical tier. Confirmed it catches the regression by reintroducing `tier=Team` and watching 2 tests fail. `flutter analyze` clean; full suite passes at 2,991 tests. Note the existing router tests only asserted that `SignupPage` renders, so they passed happily with a completely blank page — that is the gap that let this ship.

---

## Appendix — refuted claims

These three were raised by area sweeps and **failed** adversarial re-reading of the cited code. They are recorded so they are not re-reported by a future review.

| Claim | Location |
|---|---|
| `revokeConsent` leaves GTM consent granted and the FB pixel enabled; re-consent permanently mutes analytics | `lib/services/consent_manager.dart` |
| `getClientIp` falls back to the client-supplied `X-Forwarded-For`, letting callers spoof the IP forwarded to the receiver | `workers/sender-worker/src/utils.ts` |
| An unauthenticated attacker-chosen `X-Idempotency-Key` can suppress other users' submissions | `workers/contact-form/src/index.ts` |

## Provenance

- Raw per-agent results: `~/.claude/projects/-Users-alyshialedlie-code-is-public-sites-IntegrityLandingPage/dcaf2f18-2817-40e5-9bfb-3d94321fe0e6/subagents/workflows/wf_f801cf11-d4b/journal.jsonl`
- Consolidated workflow output: `/private/tmp/claude-501/-Users-alyshialedlie-code-is-public-sites-IntegrityLandingPage/dcaf2f18-2817-40e5-9bfb-3d94321fe0e6/tasks/w99mk1j47.output` (temp directory — may be cleaned up)
