# Test suite review: tautological, unnecessary, stale, duplicated (2026-09-27)

**Scope.** Every test file `docs/repomix/tests-compressed.xml` includes (174 files: 126 Dart, 48 TypeScript) plus one it omits, `workers/tests/org-quota-do.test.ts`. The compressed pack strips every `test()`/`it()` call and assertion, so the review read the source files against the code under test. Nine area reviewers each read their files in full; the counts below are theirs, and every finding carries a `path:line`. The nine raw reports are appended as evidence.

**Size.** Mechanical scan: 2,760 Dart and 1,255 TS `test`/`it` call sites; with loops and `it.each` tables expanded the reviewers read about 4,260 tests. Roughly 1,400 of them are flagged below as unable to fail, duplicated, or testing code that does not run. That figure is a sum of the per-area counts, not an independent measurement.

**Bigger problem: quality, not coverage.** The suite is large and green, and a meaningful share of it would stay green through real regressions. The dominant patterns are `findsOneWidget` on the widget just pumped, `returnsNormally` on void methods, constructor read-backs, theme constants compared to copies of themselves, and worker tests of Zod schemas no request passes through.

---

## A. Production defects the review surfaced

These outrank any test cleanup. Each was found because a test could not fail.

1. **Provisioning `received` type mismatch.** `lib/services/provisioning_service.dart:389` casts `data['received'] as String?`; the receiver stub (`workers/receiver-worker/src/index.ts:126`) and the `InboxSuccessResponse` interface return an object. Six tests in `test/services/provisioning_service_contract_test.dart` (:29, 54, 80, 98, 120, 140) silently take the TypeError path and pass only because they assert the request body. Verify the production receiver's shape in observability-toolkit. If it returns an object, `/send` provisioning is broken in the app.
2. **Local-time month boundary** in `workers/api-gateway/src/routes/usage.ts:101` (`new Date(y, m, 1).toISOString()`). `bootstrap.ts:113` fixed the same bug on 2026-07-30 and `bootstrap.test.ts:492` pins it under `Asia/Tokyo`. `usage.test.ts:174` derives both sides of its assertion from the same value, so it cannot fail.
3. **Audit action vocabulary contradiction.** `writeAuditLog` (`workers/api-gateway/src/lib/helpers.ts:21`) emits `api_key.created`, `api_key.revoked`, `billing_portal.accessed`, `checkout_session.created`. `AuditActionSchema` (`workers/lib/types/audit.ts`) accepts 17 other names and none of these. No worker imports the schema; 33 tests certify it.
4. **Create-API-key body is unvalidated.** `CreateApiKeyBodySchema` (strict, name 1–255, ISO `expires_at`) runs nowhere: `workers/api-gateway/src/routes/api-keys.ts:16-82` casts `request.json()`. Seven tests certify limits the route never enforces.
5. **`npm test` reaches the real network.** `workers/sender-worker/src/index.test.ts:1569` uses an order-dependent `mockResolvedValueOnce` that the Supabase lookup consumes, so the Stripe call goes through `vi.spyOn` call-through (measured: 401 from api.stripe.com). Lines 1526, 1829, 1846 fetch `https://supabase.test`. `workers/api-gateway/src/index.test.ts:31` fetches `https://test.supabase.co` for `/health`.
6. **Quota fail-open is untested.** The catch at `workers/api-gateway/src/lib/quota.ts:140` is reached by no test; `index.test.ts:228` mocks `enforceOrgQuota` to ok and asserts not-429.
7. **Stripe cron routing can mis-route silently.** `workers/stripe-webhook/src/index.test.ts:700, 727, 752, 777` are titled "handleX called" and never assert the handler; they pass because sibling handler mocks keep implementations across `vi.clearAllMocks`.
8. **Contact form clear-on-success is a latent bug.** `_formData.clear()` (`lib/widgets/sections/contact_section.dart:524`) cannot clear visible fields because `FormTextField` uses `initialValue` (`form_fields.dart:118`). `contact_section_test.dart:1076` is titled "…and clears form" and never asserts clearing; the W2 comment at :382 cites it as the test that does.
9. **Live suites that cannot fail.** `test/services/provisioning_service_live_test.dart` runs in CI with `continue-on-error: true` against the production sender URL, and its four `skip:` reasons are stale. `workers/stripe-webhook/src/webhook-signature.live.test.ts:54` accepts a 500 as "signature verified" on the premise that dev has no DB binding, false since 2026-08-03.
10. **Content contradictions pinned by tests.** `test/unit/content/resources_content_test.dart:193-203` asserts "5 minutes" while `content.yaml` says "15 min". `test/config/contact_content_test.dart` tests a Dart copy that has drifted from the YAML (6 contact methods vs 5, 6 use-case options vs 7) and that nothing in `lib/` reads.
11. **Stale prose in `workers/sender-worker/wrangler.toml`** (:50-56, :109-113, :138-143) claims `SHARED_SECRET` is still bound and dev `RECEIVER` still points at production. Both are closed (CR29, CR02).
12. **Tests pin an API inconsistency:** a missing `users` row is 401 on `/bootstrap` but 404 on `/me` and `/api-keys`.

## B. Never runs, or tests nothing: delete outright

| Path | Tests | Why |
|---|---|---|
| `integration_test/e2e/` (5 files) | 48 | No CI job, script, or workflow runs it (`ci.yml:47` runs `test/` only; `e2e.yml` runs Playwright). These are the originals `test/integration/` was cloned from (31d4a65 → f6561e1). `smoke_test.dart:9` pumps `Text('smoke')`. Only `contact_form_test` is substantive and its promises already run via `contact_section_test.dart:551-592`. Also delete `test_driver/` and the README section. |
| `workers/tests/org-quota-do.test.ts` | 26 | Outside every vitest `include`; imports only vitest; drives `/check`, `/commit`, `/sync`, `/snapshot` which exist nowhere in `QuotaDurableObject`; 19 `tsc --strict` errors; maintained through the tier rename while testing nothing. |
| `test/config/contact_content_test.dart` | 100 | Tests `ContactContentVariants`, `_formFields`, `_contactMethods`; nothing in `lib/` reads them (the form renders `AppContent.contact`). Delete the dead members in `lib/config/content/contact_content.dart` too. Survivor: `test/unit/content/contact_content_test.dart`. |
| `test/widgets/sections/social_proof_section_test.dart.inactive` and `lib/widgets/sections/social_proof_section.dart` | 53 | Widget mounted nowhere (`landing_page.dart:122-127` commented out). Delete both; do not reactivate. |
| `test/widgets/common/base_action_button_test.dart` | 21 | 15 constructor read-backs, 3 `isA` on `extends`, 3 "does not fire callback" that never wire the flag. |
| `test/widgets/sections/status_section_test.dart` | 11 | Never imports `StatusSection`; 10 validate the fixture; move :91 to `models_test`. StatusSection has zero widget tests. |
| `test/unit/services/tracking_none_test.dart` | 24 | Every stub is `{}` / `=> null` / `=> false`; compiling `analytics.dart` already proves the interface. |
| `test/widget_test.dart` | 8 | Flutter template leftover; 7 presence-only; :89 = :24. |
| `workers/lib/types/handler-options.test.ts` | 22 | `handler-options.ts:27` says "nothing imports this schema … should be deleted". |
| Unconsumed `workers/lib/types` schema suites: provisioning 34, audit 33, request-bodies 25, supabase 36, 20 of 27 schemas in `schemas.ts` | ~150 | No request passes through these validators. Wire in (`audit`, `request-bodies`) or keep one round-trip per schema. |

## C. Cannot fail as written, by area

- **Flutter services.** `analytics_test.dart`: about 110 of 122 are `returnsNormally` on void methods or ErrorTrackingService calls against uninitialised Sentry; keep one smoke test and rewrite about 6 on `enableCallLog()`. `test/unit/services/analytics_service_test.dart`: about 55 of 73, same pattern. `dashboard_service_test.dart`: 91 `isA<>` assertions check the result variant only, never the payload.
- **Flutter integration.** About 60 of 117 executed tests end in `find.byType(MaterialApp)` after pumping one, use `|| true`, or wrap the only real assertion in `if (x.evaluate().isNotEmpty)`. Six "flow" tests build their own GoRouter and assert a local their own builder set (`landing_navigation:97`, `comparison:183/308`, `pricing_signup:144`, `blog_contact:217`, `docs_navigation:259`).
- **Flutter pages.** 12 "creates with …" constructor tests across about/contact/features/status; 11 Family A tautologies in careers/request_failure/request_success (`Container findsWidgets`, footer never found, "tappable" never taps); `landing_page_test` 10; about 20 constant or literal assertions inside page files (`docs_api:546/551`, `security:271`, `blog:106-153` incl. `expect(true, isTrue)`); `request_failure:293` has zero `expect`.
- **Flutter unit.** Theme mirror tables copy `lib/theme` literals: colors 43, spacing 42, typography 16, decorations 9. About 37 const data-class constructor tests. `content_test.dart`: about 30 `isNotEmpty` on hardcoded consts and 10 `icon isNotNull` on non-nullable `IconData` (YAML-backed `isNotEmpty` checks are legitimate). `typography_test:10-18, 403-420` `expect(true, isTrue)`.
- **Flutter widgets.** `animated_orb_test` 9 of 14; `containers_test` 9 `findsWidgets` whose values are never read; a "structure" family of about 20 `Semantics`/`GestureDetector`/`Stack` `findsWidgets` across buttons, cards, alert, cta, hero, footer; `pricing_section:47` taps the toggle and asserts only the section exists.
- **workers/lib.** `entitlements.test.ts:83` computes its expected value with the code under test; `deploy-environments.test.ts:226` asserts a word appears in a toml; `validation/parse.test.ts:19, 28, 38` put assertions inside `if (!result.success)` with no prior failure assert; about 20 per-field positive controls; about 30 tests of Zod itself.
- **api-gateway.** `usage:174` and `index:228` (section A); `me:83` and `bootstrap:89` "expired jwt" use an unsigned token and never reach the `exp` check.
- **sender-worker.** `index.test.ts:2414-2464` assert the test's own `mockEnv`; ten signup-error tests (:923, 1912, 1943, 1976, 2012, 2051, 2066, 2087, 2110, 2149) assert `error` but never `code`, so the classifier is covered only by the opt-in e2e suite. **receiver-worker** :100, 111, 293, 346 test the stub's mock body.
- **stripe-webhook / contact-form.** `contact-form:771` `toBeDefined()` on a header `get()` that returns null; `:641` `not.toBe(500)` while the real response is 504; `stripe-schemas:30, 84, 126` passthrough; `index.test.ts:75-146` seven rejections assert only `ok:false`; `:148` mocks a rejection the wrong signature already triggers.

## D. Duplicated families

| Family | Locations | Recommendation |
|---|---|---|
| Contact service, two files | `test/services/contact_service_test.dart` vs `test/unit/services/contact_service_test.dart`, about 22 shared promises | The two reviewers picked opposite survivors. The unit file has more cases but drives `MockDio`, which is how its stale "5xx not retried" tests pass. Keep the services file (real Dio) as the base, port the unit file's unique cases (companySize/useCase limits, 403 CSRF refresh, CSRF-fetch failure, connectionError, non-Dio), then delete the unit file and its 889-line `.mocks.dart`. |
| Consent model | `consent_manager_test.dart:588-807` (28) vs `test/unit/models/consent_preferences_test.dart` | Keep the model test; move :710, :609, :802, :726. |
| Provisioning | contract vs unit, 13 same act+assert pairs (28↔330, 53↔301, …) | Keep the contract copy (full-map equality); delete the unit copies. |
| Calendly URL literal | `calendly_consistency:13-16`, `config/constants:35-38`, `content_test:340-352`, `unit/contact_content:29-34` | Keep `calendly_consistency_test` only. |
| Route → page | `app_test.dart` vs `app_router_test.dart`, 24 assertions | Merge into `app_router_test`; delete `app_test` 'routing', 'all routes', 'redirects' (26). |
| SharedAppBar per page | about 25 across careers, request_*, pricing, status | Test once in `shared_app_bar_test` with `find.descendant(of: SliverAppBar)`. |
| Viewport "renders on X" | 12 page files + 8 widget files, each asserts only `find.byType(W)` | One per widget with a layout-specific finder, or `testResponsiveLayout`. |
| Back-button | about 10 page files + 9 integration files | `testBackButtonCallback`. |
| dashboard_service error blocks | 504≡500 and receiveTimeout≡connectionTimeout ×6 each; orgId charset ×17 | One table over 6 invokers; keep one per pair (production duplicates the mapping per method, so per-method wiring is legitimate). |
| workers/lib schemas | `StripeEventSchema` ≡ `StripeEventBodySchema` (byte-identical); `UsageBucketSchema` defined twice with different shapes; `auth.test.ts` five identical positive tokens (:119, 140, 210, 252, 326); `errors:36` ≡ `responses:5` | Delete one of each; keep `auth:159` and `:419`. |
| api-gateway gates | `orgs.test.ts` portal/checkout ×4 share `authorizeBillingRequest`; `api-keys.test.ts` create/revoke ×4; `bootstrap` 114⊂135, 552⊂335; `quota` 176/184/197 | `it.each` wiring rows. Cross-file 401/403 tests are legitimate: the membership check is copied per route, not shared. |
| sender-worker unit vs e2e | 19 validation/CORS tests in `index.e2e.test.ts` with no workerd-specific failure mode; invalid-JSON ×5 in unit | Keep one e2e smoke per route and `e2e:508`; `it.each` the JSON family. |
| stripe / contact | `index.test.ts` 211⊂293; invoice paid/failed 5-test family shares two helpers; "customer absent" ×4 is the schema case; `contact-form:857-1007` six tests for a single `to:` | Delete or `describe.each`. |

## E. Stale (beyond A and B)

- `provisioning_service_live_test.dart`: `:57` skip ("requires Auth0 on staging") would create real Auth0 users in the prod tenant if unskipped; `:104` skip cites a receiver return that is deployed; `:139` Stripe is configured; `:89` asserts 404 for a `/signin` route that exists.
- `test/unit/services/contact_service_test.dart:1361-1463` pins "500 is not retryable"; production retries (`contact_service.dart:333, 356-361`) and the services file proves three attempts with real Dio.
- `app_test.dart` names `_checkConsent`/`_createRouter`, which do not exist; `app_router_test:430` says "22 routes" (44 exist, 17 have no route→page test anywhere); `:139` '/support redirects to /contact' has no such redirect.
- `test/README.md`: "~1978 tests", a removed `providers/` directory, 4 of 5 e2e files, a command CI never runs.
- Integration headers promise steps that are absent (hamburger tap, pricing toggle, breadcrumb); `contact_flow:95` 'Start Your Journey' exists nowhere; `signup_flow:154` types a company name into the password field.
- `workers/sender-worker/src/utils.test.ts:124-146` tests `corsPreflightResponse`, an export nothing calls.
- `workers/lib/auth.test.ts:344-354` describes Supabase ES256; production verifies Auth0 RS256 and this file has no RS256 test. `schemas.test.ts:44-54` checks 4 of 9 billing statuses (pre-CR27).
- `stripe-webhook/src/supabase.test.ts:234` cites a `?? 'Unknown error'` fallback absent from src.
- Dead helpers with zero callers: `test/helpers/test_content.dart` `testContentYaml` and `initializeMinimalTestContent`; `mock_provisioning_dio.dart` `upload`/`uploadFileStream`; every class in `test/integration/helpers/mock_services.dart`; eight helpers in `integration_test_helpers.dart`; `test_helpers.dart` `pumpApp`, `pumpSection`, `expectTextStyle`, `expectContainerDecoration`, `resetTestContent`, `scrollUntilVisible`, `widgetWithText`, `loadRealContent`; seven builders in `workers/sender-worker/src/test-helpers/fixtures.ts`.
- `scripts/repomix/instructions/tests.md` says "Sender-worker has 15 known failing tests"; the unit suite is 203/203 green.

## F. Verified not problems

- Same-named tests across files that target different schemas, widgets, or views (`'has semantics label'` ×7, `'has correct semantic label'` ×4, `'defaults metadata to {}'`, `'rejects unknown action'`, form_fields/containers/cookie_banner pairs).
- CR29 fixtures: `SHARED_SECRET` present with a value different from the active key in both workers; every keyless-path test asserts rejection; `auth.verified_legacy_key` appears in no test.
- `workers/constants.ts`, `cors-utils.ts`, `http-helpers.ts` are live imports (stripe-webhook, contact-form, receiver, api-gateway).
- `test/coverage_setup.dart` is live; `deploy-environments` `STUB_WORKERS` and `:133-134` are intentional; legacy `int_live_` fixtures are still valid alongside `obtk_`.
- `checkout.ts:24` both branches plus the absent case are tested; `makeMockCtx().flush()` genuinely tests CR21; the 429 test correctly omits CSRF.
- `login_nav_test` (5) is fully real; `signup_flow` validation strings match `signup_page.dart`.

## G. Missing coverage worth adding

- AuthPage forgot-password flow and `ProvisioningService.forgotPassword`/`signIn`: zero tests.
- 17 of 44 routes have no route→page test; `state.extra` redirect guards (`app_router.dart:176-270`) untested through `createAppRouter`.
- StatusSection: zero widget tests. CookieBanner never asserts which `ConsentLevel` is saved. PricingSection never asserts the price swap or `onSelectTier`.
- `api-gateway/src/lib/quota.ts` (fail-open, 429 mapping) and `lib/helpers.ts`: no direct tests; `preVerifyToken` API-key branch never hit.
- `workers/lib`: auth RS256 branch, JWKS TTL and cooldown; `crypto.ts` `sha256Hex` and `arrayBufferToBase64Url`; most `supabase.ts` verbs.
- contact-form: in-memory rate-limit denial without KV; idempotency KV throw paths; CRLF in subject.
- sender-worker: `enrichReceiverErrorBody`; KV happy-path rate limit; `X-Forwarded-For`; e2e checkout never intercepts `/rest/v1/users`, so `metadata[org_id]` is unexercised in workerd.
- No dashboard test asserts request path or `Authorization` header; contact CSRF/idempotency headers never asserted though the mock exposes them.

## H. Suggested order

1. Verify and fix section A, items 1 through 8. Several are one line.
2. Delete section B. About 470 tests that cover nothing; zero coverage risk.
3. Section D merges: parameterize and use the shared helpers. Behaviour-preserving; run `flutter test` and each worker's `npm test` after every file.
4. Rewrite the section C families with real assertions (analytics on `callLog`, integration on concrete finders, theme on a computed contrast). This changes what the suite verifies; review it separately.
5. Add section G.

## Pack notes

- `tests-compressed.xml` keeps imports, helper signatures, and comments only. Use it to navigate; review from source.
- Its include patterns miss `workers/tests/`. Delete that directory rather than adding it.

---

## Appendix: per-area reports (verbatim, working notes precede the final report in some)


---

<!-- source: review-flutter-services.md -->

# Review: Flutter services tests (test/services/**) — COMPLETE

## 1. Test counts (`test(` calls; no `testWidgets`)
analytics 122 | consent_manager 87 | contact_service 36 | content_loader 52 source (+62 generated by the :164 loop = 113 at runtime) | dashboard_service 124 | provisioning_contract 25 | provisioning_live 10 | provisioning_service 53. Total 509 source calls checked.

## 2. Findings (impact order)

**provisioning_service_contract_test.dart — not a contract**
- :27,159,253,299,380,449 — STALE — all six "Links to" refs are wrong: `SendRequestSchema` is `workers/sender-worker/src/types.ts:153–175` (82–92 is `ERROR_DESCRIPTIONS`); inbox success is `receiver-worker/src/index.ts:126–127`, health :133–135; signup response `sender-worker/src/index.ts:167`. Nothing reads any Zod schema; every expected key is a hand-typed Dart literal, so a `types.ts` edit cannot fail this file. Only key names are checked — not required-ness, `z.string().jwt()`, or the tier enum.
- :29,54,80,98,120,140 — fixture `'received': {}` matches the stub (`received: payload`, `InboxSuccessResponse.received: Record`) but `ProvisioningSuccess.received` is `String` and `sendEvent` does `data['received'] as String?` (provisioning_service.dart:389) → TypeError → generic catch → `ProvisioningError`. All six tests run the error path and pass only because they assert `lastPostBody`. Group :160–249 then uses `'received': ''`, contradicting the interface it cites. Action: assert the result variant in every test; confirm the production receiver's `received` shape in observability-toolkit — if it is an object, the app's provisioning is broken.
- :119, :138 — TAUTOLOGICAL — `isA<Map<String,dynamic>>` on `Map<String,dynamic>?`; `MockProvisioningDio.post` discards `options`, so no header is observable. Delete or capture headers in the mock.
- :79, :97, :227 — TAUTOLOGICAL — Dart passes `action`/`tier` through unvalidated; :227 `startsWith('sk-')` on the fixture the test wrote.
- :450 — asserts variant only; for 500 the message is `_errorServer`, not the body, so "{ error: string }" is false. :473 ⊂ :450. Tighten/merge.
- :30,55,81,99,121,141,166,189,211,233 — dead `mockGetResponse`; `sendEvent` never GETs.
- Cross-file DUPLICATES (same act+assert) with provisioning_service_test.dart: 28↔330, 53↔301, 160↔84, 254↔353, 284↔363, 300↔628, 338↔617/638/672, 360↔704, 381↔723, 400↔758, 413↔741, 431↔769, 494≈769. Keep the contract copy (full-map equality is stricter), delete the unit copy.

**provisioning_service_live_test.dart — permanently ineffective**
- CI `integration-live` runs on push to `main` with `continue-on-error: true` against `SENDER_WORKER_URL=https://sender-worker.alyshia-b38.workers.dev` (production). It cannot fail the build; header says "staging" but none exists (`stg` empty, dev workers are `*-dev`).
- :57 skip — STALE: `/signup` is live; unskipping creates real Auth0 users in the prod tenant. :104 skip — STALE: receiver minting is deployed; the real blocker is the `received` mismatch above. :139 skip — STALE: Stripe is configured. :169 — the `BOOTSTRAP_TOKEN` guard inside is dead under a permanent skip.
- :89 'returns AuthError (404) - not implemented' — STALE: `POST /signin` exists (sender index.ts:481); passes only because creds are bogus.
- :152 — TAUTOLOGICAL — `isA<CheckoutResponse>()` is the declared return type; name also stale.
- :37, :45 — both `http://`, rejected before any network call; DUPLICATE of unit :385 and of each other; :37 misnamed.

**analytics_test.dart — ~110 of 122 cannot fail**
- :77–340 (33) and :956–1082 (15) — TAUTOLOGICAL — `returnsNormally` on void methods. `AnalyticsService.enableCallLog()` (analytics.dart:215–232) is used by landing_controller_test and sub_page_shell_test but never here. Rewrite ~6 tests on `callLog` (event + params per method; `trackScrollDepth(30)` logs nothing). Note the spy records before the `isReady` guard, so "does nothing when disabled" needs a TrackingWeb seam.
- :379–902 ErrorTrackingService (58) — TAUTOLOGICAL — Sentry uninitialised, calls are no-ops; :799,825,839,840 `isNotNull` on non-nullable `ISentrySpan`; :808 `isA<ISentrySpan>` = declared type. `_configureScope` is the only logic and is untested. Keep one smoke test.
- :33, :911, :952 — `isA<bool>()` on a bool getter; names claim "returns false", assert nothing.
- DUPLICATES: :38≈:56≈:69; :915≈:940≈:947; :223/:230 verbatim = :1055/:1062 (and misfiled under AnalyticsService); :1118 ⊂ :1108.
- UNNECESSARY: :21, :374 enum counts; :1093 order; :7 copies the literal table (keep only as the GA4-name contract, paired with :1103/:1108).

**dashboard_service_test.dart — mechanical families**
- Error mapping is copy-pasted per method in dashboard_service.dart (only the status→message helpers are shared), so per-method coverage is legitimate but should be one table over 6 invokers. Within each: receiveTimeout (:298,580,828,1075,1277,1479) is the same `||` branch as connectionTimeout; 504 (:249,543,791,1038,1249,1375) same branch as 500 → DUPLICATED ×6 each. Keep one per pair.
- orgId regex `[/?#%]` ×17 tests (:120–163, 430–455, 674–699, 921–946, 1449–1465, 1605): parameterize charset once + one wiring input per method.
- :82 ⊂ :72; :272 = :237 arrangement (merge as :530 does).
- Variant-only `isA<>`: unrecognized-4xx ×5, non-DioException ×6, orgId ×17, url-missing ×3 — tighten to `_errorUnexpected`. :745,999,1387,1397 use `isNot('Unauthorized')` (equality) vs :219's `isNot(contains())`.

**consent_manager_test.dart**
- :588–807 (28) DUPLICATED with test/unit/models/consent_preferences_test.dart (:618↔29, :604↔20, :633↔40, factories, JSON, toString, toPreferences). Unique here: :710, :609, :802, :726 (exact round-trip; unit's is lossy). Move those, delete the rest.
- :761–776 enum count/order/`.name`; :822–860 ISO round-trips — UNNECESSARY (language/stdlib).
- :911–941 Re-exports — TAUTOLOGICAL (`// ignore: unnecessary_type_check`; missing export fails compile). :947–966 tests a helper used only here. :197, :871 `expect(true, isTrue)`; :167–185 four `completes` on non-web no-ops.

**content_loader_test.dart**
- :36–89 — UNNECESSARY: 19 `isNotEmpty`, each literally written twice (:38/39 … :87/88), all subsumed by the 62-entry equality table.
- :361–383 'Content static methods' — STALE name (no `Content` class in lib/); all four duplicate :355, :100/:172, :343.
- :402, :409 `isA<List<…>>` on declared getter types — tautological.

**contact_service_test.dart vs test/unit/services/contact_service_test.dart**
- Unit file is the superset (also covers companySize/useCase limits, 403 CSRF refresh, CSRF-fetch failure). Duplicates: :163=unit:368, :151=:356, :56–:215≈unit:305–579, :335/:352=unit:860/1005, :418/:435=unit:897–937. Unique here: :368/:385 zero/negative Retry-After, :402 `local_`, :452, :467, :479, :26/:41. Move those; delete file.
- :258 message `'short'` — STALE remnant of a min-length rule. :294 variant-only; assert `error == 'Server error occurred'`.

**provisioning_service_test.dart**: :784–830 tests the mock (:785≈:171, :805≈:400, :820=:353) — delete; :833–836 header STALE; :26/:58/:71 overlap.

**Helpers**: test_content.dart:13–461 `testContentYaml` + :496 `initializeMinimalTestContent` — STALE, zero callers. mock_provisioning_dio.dart:396–403 `upload`/`uploadFileStream` — not Dio members, dead.

## 3. Verified not a problem
- Dashboard ×6 blocks are not a shared helper — production duplicates the mapping per method.
- consent :356/:399 — same name, different act (set vs remove).
- contact :544 is `ContactFormPayload`, unrelated to consent :618.
- contract :183/:205 (missing/empty apiKey) are unique and real (073672d).
- content_loader :436 zone-error test is load-bearing.
- test_constants.dart: all 19 constants have consumers; mock_http_adapter APIs all used by page tests.

## 4. Missing coverage
- No dashboard test asserts request path or `Authorization: Bearer`; the shelf handler ignores both — a URL typo passes.
- `ProvisioningService.forgotPassword` and `signIn`: zero tests.
- 503 on GET dashboard methods (not retried; only POST methods list `serviceUnavailable`) untested.
- `_configureScope` context/extra mapping and the "never put jwt in extra" invariant unverified.
- Contact `X-CSRF-Token`/`X-Idempotency-Key`/`X-Request-ID` never asserted though `MockHttpAdapter.requestLog` exposes them.


---

<!-- source: review-flutter-pages.md -->

# Flutter page test review (test/pages/*.dart, 28 files + test/helpers/test_helpers.dart)

All 28 files read in full; production compared: lib/pages/*.dart, sub_page_shell.dart, doc_page_scaffold.dart, shared_app_bar.dart. Nothing edited.

## 1. Test counts (raw `testWidgets(`/`test(` calls / effective incl. helper- and loop-generated)

about 22/26 · api_toolkit 2/10 · auth 48/48 · blog 22/22 · careers 36/43 · checkout 5/5 · checkout_success 11/11 · comparison 36/36 · contact 12/20 · docs_alerts 71/79 · docs_api 53/61 · docs_interoperability 53/59 · docs_observability 53/59 · docs_quickstart 58/66 · eu_ai_act 11/18 · features 9/17 · landing 53/53 · legal 32/39 · pricing 36/41 · provision 14/14 · request_failure 32/39 · request_success 29/36 · security 33/41 · sender_health 9/11 · signup 41/41 · sources 35/35 · status 22/29 · usage_summary 6/6. **Total 844 raw / 965 effective.**

## 2. Findings (by impact)

**A. SharedAppBar tests copied per page** — UNNECESSARY/DUPLICATED (~25 tests). 'renders company name in app bar' (careers:55, request_failure:53, request_success:53, pricing:49), 'renders shield icon' (careers:61, rf:59, rs:59, pricing:55, status:144), 'renders navigation links on desktop' (careers:71, rf:69, rs:69, pricing:68), 'renders popup menu on mobile' (rf:78, rs:78), 'hides navigation links on mobile' (careers:85,93), 'back button has tooltip' (careers:387, rf:270, rs:290), toolbar height (status:149, 285 [= 149 exactly], 301; pricing:444), 'renders app bar icons' (careers:330, rf:240, rs:260 = shield + testPageStructure back button). All exercise `SharedAppBar.subPage`, identical on every SubPageShell page; `test/widgets/navigation/shared_app_bar_test.dart` covers only overflow/semantics. Action: move once into shared_app_bar_test with `find.descendant(of: find.byType(SliverAppBar))` exact counts; delete per-page copies.

**B. In-file duplicates (same act + same assertion)** — delete 14: careers 246 (=71+79), 254 (=85+93), 337 (=134), 344 (=161), 352 (=199), 370 (=126), 377 (=153), 301 (=101+107); request_failure 188 (=69), 247 (=87), 262 (=110); request_success 208 (=69), 267 (=87), 282 (=110).

**C. Family A tautologies** — 'hero section renders with containers' (careers:362, rf:255, rs:275: `Container findsWidgets`); 'page structure includes footer in slivers' (careers:291, rf:231, rs:251: never finds FooterSection); 'mobile hides desktop nav links' (rf:196, rs:216: asserts only SliverAppBar exists); 'tablet viewport renders correctly' (careers:262, rf:205, rs:225: re-implements `testResponsiveLayout(includeTablet:true)`); '<X> button is tappable' (careers:209,225; rf:155,168; rs:175,188: asserts a GestureDetector ancestor, never taps). Delete 11, pass `includeTablet:true`, replace "tappable" with GoRouter taps asserting '/', '/contact', '/features', '/contact?ref=careers'.

**D. request_failure:293** — zero `expect()`, pumps with no `error`; delete (299/338 cover it). request_failure:287 'CompanyInfo has email defined' — constant; delete.

**E. Family B (about/contact/features/status + landing:379-413)** — 'creates with default/onBack/onShowCookieSettings' ×12 assert only `find.byType(Page)`: TAUTOLOGICAL, delete. 'renders SelectionArea' (about:58, contact:64, features:64, status:102, pricing:41) and 'renders FooterSection' (about:193, contact:121, features:93, status:259) are SubPageShell behaviour already in sub_page_shell_test.dart:50,75: delete (landing:70 may stay, own tree). 'passes onShowCookieSettings to footer' (about:204, contact:132, features:104, status:270) only finds FooterSection; tighten to `tester.widget<FooterSection>(..).onCookieSettings` identity, else delete.

**F. Viewport family re-implementing `testResponsiveLayout`** — legal:285-322, about:220-236, docs_observability:430-451, checkout_success:120-134, auth:492-506, docs_interoperability:511, signup:164-186, pricing:437, sources:404-447, blog:347-399, comparison:423-452, landing:227-257; all assert `find.byType(Page)` (± one text). Replace with `testResponsiveLayout<T>(pump, includeTablet:true)` (auth/signup pumps need a matching wrapper). STALE comments: docs_observability:431 (test named "mobile" pumps tablet "to avoid badge overflow"), docs_interoperability:519-520, pricing:77-78,451 — all three files install `setUpOverflowErrorSuppression`, and docs_quickstart (5 DocCallouts) runs the helper's mobile test green; enable mobile and drop the comments (confirm with one run).

**G. `back button triggers onBack` re-implemented** — legal:130 and legal:100 (same act/assert via factory), status:114, about:75, sender_health:75, comparison:341/361, blog:305/326, sources:348/367: use `testBackButtonCallback(s)`. status:109, about:70 'has back arrow' = testPageStructure 'renders back button': delete.

**H. Family C docs** — 'renders Back to Home text button' (docs_alerts:63, docs_api:44, docs_interop:44, docs_obs:44, docs_quickstart:45, legal:125): DocPageAppBar hard-codes it (doc_page_scaffold_test:48) and `testBackButtonCallbacks` already taps it; delete (security:44 has its own SliverAppBar, keep). security:38 'renders page title' (findsWidgets) equals the `testResponsiveLayout(expectedTitle)` desktop assertion: delete; docs_api:38, docs_obs:38 findsWidgets → descendant-of-SliverAppBar findsOneWidget. 'renders correct icons for each section' (docs_alerts:664 = 77+130; docs_quickstart:553 = 63+126+172; security:285 = 62+76, only `user` new): merge. docs_interoperability 'section icons' 524-615 repeat the icon half of 'documentation sections' 86-183 at identical offsets; 619 (= 86, asserts no styling); 632-660 (= 449/329/461): delete 13. docs_api:574 = 79-105.

**I. Constant/literal tests in page files** — docs_api:546 + security:271 'CompanyInfo has name defined' (also constants_test.dart:7); docs_api:551 asserts `CompanyInfo.copyright`, which DocPageFooter never renders (hard-codes '© 2026 Integrity Studio LLC') — STALE; docs_interoperability:502 compares string literals to themselves; blog:106-153 four tests incl. `expect(true,isTrue)` and locals-vs-locals, comment "_posts is private" stale (`BlogContent.posts`); security:266 lastUpdated (page renders it, security_page.dart:91 — assert the widget); sources:487-494 Routes.sources; legal:14-23 enum; auth:143-151 enum; auth:108-137 PasswordPolicy tests a local copy of private `_isPasswordValid`, header "(existing tests preserved)" is stale rationale, and 299 already covers it via the widget; auth:157-169 isValidEmail duplicated in test/services and test/unit/services; comparison:12-64, blog:15-102, sources:23-56 constructor-echo tests; pricing:519-542 (content_test.dart, pricing_section_test). Delete all except: move sources:60-128 and comparison:67-152 to test/config (no other coverage), and drop comparison:488-508 (re-assert competitorName from 68/136).

**J. Conditional / assertion-free widget tests** — landing:556 (if-guarded), 578 & 902 (entire body in `if`; same act+assert, two routers), 606, 628 (three nested ifs, ends "page exists"), 665 (no act), 678 & 953 (tap nav, never check offset as 692/715 do), 928 ("after tier selection tap": no tap; = 354). pricing:338 else-branch degrades to a title check. signup:110 (enterText, no expect), 198 (page-type only; 316 is the real test), 84-106, 31, 39, 190 (= 74), 214. checkout:124,144 (= loading arrangement). checkout_success:85 'sanitizes email' passes a clean email and asserts page exists — feed `<script>` and assert stripped output (page calls `SecurityUtils.sanitizeUserInput`). blog:439 `tester.widget(..) isNotNull` (throws first). Make unconditional or delete.

**K. landing tautologies** — 56 (Scaffold findsWidgets), 83, 99 (Semantics findsWidgets), 115 (Text findsWidgets), 137 (TextButton, but nav links are HoverTextLink), 164 (asserts KeyedSubtree present, not the "without key" claim; = 185), 108 (= 76; also 248,256,481,503), 295 (= 271), 261/362. Delete 10.

**L. auth** — 414 = 436 (identical `'Sign In' findsWidgets`): one `findsNWidgets(2)`. 357 ends with the same asserts as 330 and never checks the button is disabled (own comment admits): assert `onPressed isNull`. 314 asserts Alert absent when none was set: stub a 401 first. 187 'renders GradientBackground' asserts AuthPage. 651 negative-asserts 'provision_page' (copied from sign-up; should be 'dashboard_page'). 232/441 `RichText findsWidgets` → predicate on `toggleModePrompt`.

**M. findsWidgets where count is knowable** — about:94 (2 GradientButtons), about:99 (3 checks), status:169/174/196 (174 = 196), status:183 `Wrap`, docs_quickstart:89/96/103/110 (digit strings), 126/352/649, docs_alerts:110-113/625, docs_obs:120/186/208/489/499/509, pricing:65/72-74/161-165 ('Free' also at 142), sources:464/465/481, comparison:189/247/478/482, eu_ai_act:133 (assert the literal at eu_ai_act_page.dart:127). Tighten or scope with `find.descendant`.

**N. Stale names/comments** — blog:195/211/229/245/276 disagree ("5th/7th/4th post"); blog:228 subsumed by 258; comparison:194 'renders special offer banner' asserts `findsNothing` — rename.

## 3. Verified NOT a problem
- landing:440 `PopupMenuButton<String>` matches landing_page.dart:248 (own app bar; SharedAppBar is `<int>`).
- `Icons.arrow_back` in sender_health/auth/provision/checkout_success/signup is correct (GradientPageShell / AuthPage AppBar).
- comparison:68/136 and 82/140 are WhyLabs vs Arize, not duplicates (140 is weaker than 82).
- request_failure 'Try again' (item label) vs 'Try Again' (action) both exist in source.
- docs_api:382 'Sandbox' findsNothing: string absent from page; harmless guard.
- careers `findsOneWidget` vs request_* `findsWidgets` for nav text is footer visibility at desktopLarge, not a defect.
- landing:471 references test/integration/landing_navigation_test.dart and mobile_navigation_test.dart — both exist.
- sender_health, provision, usage_summary are tight and non-redundant; contact:83/103 `findsNWidgets(2)` is the model.

## 4. Missing coverage
- RequestFailurePage auto-redirect to /login on user-exists (initState microtask) — no GoRouter in any test, so the catch swallows it; nothing asserts it. Page-level CTA navigation (Try Again → /contact, Explore Features, Keep in Touch → /contact?ref=careers) untested.
- AuthPage forgot-password flow (`initialForgotPassword`, 'Forgot password?', 'Send Reset Link', success/error, 'Back to sign in'): zero tests.
- Per-page `analyticsPageName` values (e.g. 'request_failure_user_exists') and ContactPage `trackPageView('contact', ref:)` never asserted; sub_page_shell_test covers only the mechanism.
- UsageSummaryPage has no widget test (only `aggregateUsageByDate`); ApiToolkitPage has no body-content assertion.
- StatusPage `_ServiceRow` non-operational branch and SharedAppBar sub-page nav routing ('/?section=features', CTA external-vs-route) untested anywhere.


---

<!-- source: review-flutter-unit.md -->

# Flutter unit/config/utils test review

Scope: 22 files read in full (21 in scope + test/services/contact_service_test.dart for overlap), plus lib/config/**, lib/models/consent_preferences.dart, lib/services/{analytics,contact_service,tracking_none,content_loader}.dart, lib/theme/**, lib/utils/security_utils.dart, web/{index.html,_headers,_redirects}, content.yaml.

## 1. Test counts (test(/testWidgets( call sites; runtime count where loops generate tests)

about 19 | calendly_consistency 10 | contact_content(unit) 29 | content 52 | resources 16 | services 13 | signup_tier 7 | consent_preferences 15 | analytics_service 73 | contact_service(unit) 74 | tracking_none 24 | colors 11 (51 runtime: 4 tables) | decorations 39 | spacing 3+18w (60 runtime: 3 tables) | typography 23+11w | csp 14 | redirects 10 | config/constants 20 | config/contact_content 100 | config/models 15 | security_utils 43 | (services/contact_service 36, other reviewer).

## 2. Findings (impact order)

**test/config/contact_content_test.dart (whole file, 100 tests) — STALE + TAUTOLOGICAL.** Tests `ContactContentVariants.current`, `_formFields`, `_contactMethods` and 44 field constants; nothing in lib/ reads them (only the hero trio at lib/pages/contact_page.dart:55-57, already covered by test/pages/contact_page_test.dart:78-89; the form renders `AppContent.contact`, contact_section.dart:59). The Dart copy has drifted from what ships (6 methods incl. Phone vs yaml 5; 6 useCase options vs yaml 7). 331-452 compare `field.label` to the const it was built from. Action: delete file; delete the dead members from lib/config/content/contact_content.dart. Survivor: test/unit/content/contact_content_test.dart. Hint: 'message field is textarea' config:300 vs unit:314 are different sources, not duplicates, but config guards nothing.

**Calendly literal ×4 — DUPLICATED.** `== 'https://calendly.com/integritystudio/demo'` at calendly_consistency:13-16, config/constants:35-38, content_test:340-352, unit/contact_content:29-34; all read `ContentLoader.calendlyUrl`. '15-minute' ×3 (calendly:23-31, contact:36-44, content:346-351). Keep calendly_consistency only. calendly_consistency:18-21 — TAUTOLOGICAL: `AppContent.contact.calendlyUrl` and `ExternalUrls.calendlyDemo` are the same getter (content.dart:341, constants.dart:66). 42-54 restates 30; 67-78 re-greps the yaml text the loader already parsed (load_content_native.dart) — keep only the `isNot(contains('alyshialedlie'))` negative. constants:40-42 subsumed by 35-38.

**Theme mirror tables — TAUTOLOGICAL.** colors_test:8-107 (29 hex + 10 alias + 4 gradient tests copy colors.dart); spacing_test:8-68, 227-241 (25+10+7 tests copy spacing.dart; hint at 43/238 confirmed); typography_test:24-167 (16 tests copy literals); decorations 'creates decoration with default values' ×4, static dots ×3, backgrounds ×2. Delete; keep the responsive/branch tests (spacing 70-223, 244-440; typography 187-399; decorations `dot` 91-115). colors:139-147 DUPLICATE aliases 56-57; 149-153 `isNotNull` on const. Replace with one computed WCAG contrast assertion.

**decorations_test — UNNECESSARY passthrough:** 'accepts custom radius' ×8 (50,83,159,192,215,250,273,296), 'custom background color' ×4, 'custom gradient' ×3. TAUTOLOGICAL non-null on non-nullable: 18-24 (never checks opacity 0.25), 152-157 (never checks blue500 border), 289-294, 303-312 — tighten to `color.a≈0.25` / `(border as Border).top.color`. 26-31 DUPLICATE of 10-16.

**typography_test:10-18, 403-420 — UNNECESSARY:** `expect(true,isTrue)` ×3, `expect(AppTypography, isNotNull)`. Delete.

**analytics_service_test (73) — ~55 cannot fail:** `returnsNormally`/`completes` on methods that early-return (`!isReady`, `!kIsWeb`) or hit uninitialised Sentry. 49-59 asserts no filtering; 187-238 (11) enum name == copied literal; 323-342 (5) enum→SentryLevel copy; 546-553 `isNotNull` on non-nullable. The spy `enableCallLog()/resetForTesting()` (analytics.dart:215-232) is used by test/controllers and test/widgets but never here; no tearDown resets `_enabled`. Action: ~8 callLog-based tests (event+params per track*, 25% filter, disable suppresses), delete the rest. Hint 27/261, 31/265, 45/271: same names, different classes — not copies, but all assert nothing.

**tracking_none_test (24) — UNNECESSARY:** every stub method is `{}`/`=> null`/`=> false`; analytics.dart already compiles against it. Delete file.

**unit/contact_service_test:1361-1463 — STALE.** Group "validateStatus rejects unhandled 5xx" / "500 is not retryable — single attempt": production sets `validateStatus: status != null` (contact_service.dart:333) so Dio never throws badResponse, and 500 IS retried (356-361; test/services/contact_service_test.dart:435-450 proves 3 attempts with real Dio). Passes only because MockDio bypasses Dio. Delete 3 tests. 655-688 DUPLICATE of 623-653 with weaker asserts; 156-180 passthrough, 1467-1504 tests Dart sealed-class switch — UNNECESSARY. Overlap with test/services (~22 promises): toJson 38-64≈26-52; validateForm ×11 293-540≈56-213; isValidEmail 270-289≈234-248; submitForm invalid/success/200-false/timeouts×2/429×2/504/local_ 604-1174≈258-433; ContactFormErrors 183-265≈508-540; payload 130-154≈543-572. Survivor for HTTP: test/services (real Dio); move CSRF-403 (1180-1358), connectionError (1071-1101), non-Dio (973-999) there, drop MockDio and the 889-line mocks file.

**Content constructor tests — UNNECESSARY** (const data classes): 'creates with all required fields' ×12 (about 3, contact 3, resources 4, services 2 — hint said 13) plus about:119-129, contact:201-225, 245-254, resources:122-134, 155-166, services:91-101, and all 15 of test/config/models_test.dart (164-173 = contact:216-225; 176-187 = resources:155-166). Delete ~37.

**content_test.dart — hint premise wrong:** AppContent reads content.yaml via ContentLoader and `_getString` returns '' on a missing key, so `isNotEmpty` on yaml-backed fields does guard. TAUTOLOGICAL only where content.dart hardcodes: sectionId (202,220,261,300; about:12, contact:12, resources:12, services:12), 32-33, logos 103-110 (const placeholders), 139, 188, 191-195, resources CTAs 286-293 (+resources_content_test:15-18), services.ctaUrl 206, comparison pages 400-448 (6 tests on `static const`). `icon isNotNull` ×10 (69,456,466,474,482,490; about:60; contact:157; resources:41; services:55-61) — IconData non-nullable. 112-122 vacuous (yaml has no testimonials key; body inside `if`). DUPLICATED: groups services 198-214, about 216-255, resources 257-294, contact 296-353 restate the per-section files. Action: delete those + hardcoded asserts; extend 458's `isNot(LucideIcons.circle)` to every icon loop (the real guard).

**consent_preferences_test:** 20-27 DUPLICATE of 13 (and ctor accepts `essential:`, so "always true" is only a default); 29-48 passthrough; 147-160 toString; 52-74 subsumed by 164-183; 17 `isNotNull` on non-nullable; 139-143 ISO round-trip is exact — use `equals`.

**csp_config_test:** 68-77 DUPLICATE of 79-85; 41-52 subsumed by 54-66; 119-134 `&& !contains('wasm-unsafe-eval')` passes when both tokens present — drop clause; all `contains` checks match the comment at index.html:18-25 too (file's own 172-180 notes it) — extract the meta `content` attribute first.

**redirects_config_test:** 71-79 subsumed by 52-69 and 122-143; 28-30 implied by setUpAll + 33-37.

**config/constants_test:** isNotEmpty on compile-time consts 6-12, 24-31, 70-77; 105-110 literal copies; 97-99 implied by 93-95. (Navigation/form CTAs and PlatformMetrics are yaml-backed — fine.)

**security_utils_test:159-169 — misleading:** input yields buffer 197 ≤ limit, so `_truncateWithCleanBoundary`'s back-up branch (security_utils.dart:122-128) never runs; the loop breaks before exceeding `limit`, so that branch is unreachable in production too. 52-67 loose (`<=210`/`<=60`; exact is `maxErrorLength+3`); 316-318 literal copy; 126-141 only `contains('&lt;')`, missing that right-bracket lookalikes map to `&lt;`.

**resources_content_test:193-203** pins "5 minutes" while yaml platform_metrics.setup_time and trust indicators say "15 min" — enforces a content contradiction. **signup_tier:82-85** redundant with 87-105. **unit/contact_content_test:150** duplicate `contains('GitHub')`.

## 3. Verified not a problem
- calendly_consistency:81-127 `markTestSkipped` guards: jsonld_combined.json and web/resources/whylabs-migration-guide.html both exist; tests run.
- signup_tier_consistency: Dart SignupTiers vs yaml signup/pricing vs lib link literals — independently editable, legitimate.
- content `isNotEmpty` on yaml-backed fields guards key deletion (see above); every yaml icon name is in `_iconFromString`.
- spacing/typography responsive testWidgets and ResponsiveUtils: real branch coverage incl. 768/1024 boundaries.
- security_utils isSafeForDisplay / sanitizeServerError groups: behaviour-driven.
- analytics:7-11 `isReady` false is deterministic on VM (`!kIsWeb` early return).
- redirects `_parseRedirectRules` is used; 'creates with all required fields' is 12, not 13.

## 4. Missing coverage
- Nothing compares Dart `TrustIndicators.current` (constants.dart:191 "keep in sync") with yaml trust_indicators.current.
- No assertion that any track* call emits the right event/params or that `disable()` suppresses sends (spy exists).
- `resources.leadMagnets` (3 yaml items) untested; `isNot(circle)` icon check only for services.
- No computed WCAG contrast check; comments assert ratios nobody verifies.
- contact_service: no test that X-CSRF-Token/X-Idempotency-Key/X-Request-ID headers are sent or that the idempotency key is stable across retries.


---

<!-- source: review-flutter-widgets.md -->

# Flutter widget test review — test/widgets (working notes, 2026-09-27)

All 37 files under test/widgets (36 active + social_proof .inactive), test/helpers/test_helpers.dart, and every
lib/widgets/** and lib/theme/** source they exercise were read in full. Counts: 435 testWidgets + 20 test active; 53 inactive.

## Per-file notes (in reading order)
- common/base_action_button_test: 21 tests, all worthless (15 ctor round-trips, 3 isA<> type checks, 3 "null onPressed" with an unwired `pressed` var).
- common/alert_test: 146 Semantics findsWidgets tautological; 177/201 filler; AnimatedAlert unused in lib/.
- common/buttons_test: 67/281 structure findsWidgets tautological; disabled sub-blocks only assert text present.
- common/cards_test: 39/51/121 Semantics/MouseRegion findsWidgets never read label/cursor; 160 "primary GlassCard" tier never read.
- common/chip_badge_test: 73 implementation detail covered by 54; labelStyle/descriptionStyle untested. Otherwise tight.
- common/containers_test: 9 findsWidgets, values (maxWidth 800, colour, gradient, 'features section' label, header) never read; showOrbs=false asserts nothing.
- common/copyable_code_field_test: 153 "both desktop and mobile" sets only desktop (a313c54), duplicates 8.
- common/dashboard_card_test: clean.
- common/form_fields_test: 12 enum; 121 never reads keyboardType; 138/182 only TextFormField findsOneWidget. Same-named across groups = different widgets.
- common/gradient_pill_badge_test: clean.
- common/hover_text_link_test: clean (#69/#70 regressions asserted).
- common/info_card_test: 526 cannot fail (chevron never passed). Otherwise fine.
- common/status_badge_test: clean; overrides + transparent-border branch untested.
- common/status_icon_test: 4 semantic-label tests are distinct strings (OK); 208 isNotNull weak; 135/150 ignore secondaryColor/iconSize.
- common/trust_badge_test: clean; default check icon untested.
- common/vertical_indicator_list_test: 147 subsumed by 193; 170 >=1; 122 dup of 253; 13 dead capture var; 300 tests super.key.
- consent/cookie_banner_test: 349 dup of 147; 377 SafeArea unconditional; 369 not accessibility; 45/71 dup test/unit/models; no test asserts saved ConsentLevel.
- decorative/animated_orb_test: 9 of 14 tautological/duplicate (8,25,45,61,105,121,137,155,208); 77 cannot detect missing dispose.
- docs/doc_components_test: 7 semantics-label tests are distinct (OK); 433 subsumed by 553; 455 const ctor; 17 enum; accent-colour sub-blocks never read colour; 575/399 border isNotNull.
- modals/api_key_modal_test: 229/248 viewport tautological (248 dup 12); 289 dup 12+83; 269 Icon findsWidgets; 34 ~dup 12; 331 ctor round-trip.
- modals/demo_modal_test: 10/51/70 same arrangement; 319 dup 31; 91 IconButton findsWidgets; 233/255/304 tautological; overflow comment unverified.
- navigation/doc_page_scaffold_test: clean.
- navigation/shared_app_bar_test: 53 dup of 45+62.
- navigation/sub_page_shell_test: 94/99 tautological (no viewport branch); 136 pump() never rebuilds.
- sections/about_test: 8 pumps for one assert each; 79 "accessible" asserts text only.
- sections/contact_test: 386 dup 316; 407 dup 331; 1038 dup alert_test; 1076 "clears form" never asserted + W2 comment stale; 1132 misnamed (no fieldErrors); 906 tautological; 274/290/657/677 framework echo; 16 findsWidgets mostly knowable.
- sections/cta_test: 51/62/73/84 merge; 122/133 dup 73; 97/108/146/157/168 structure tautological; 35 never taps.
- sections/features_test: 35 asserts SectionTitle type; 48 `if (n>0) Column findsWidgets`; 93-115 viewport tautological.
- sections/footer_test: 32 vs 173 both count 17 HoverTextLinks; 88 dup 38; 154 Blog callback never tapped; 105/115/164 GestureDetector findsWidgets.
- sections/hero_test: 64 count knowable 2; 121 knowable 4; 153 dup 78+89; 166 dup 78; 180/194 tautological.
- sections/page_hero_test: clean (69 cannot fail but harmless).
- sections/pricing_test: 47 toggle asserts nothing; 82 `selectedTier isNull` no tap; 141 isNotNull on non-nullable + >=0; 181 ctor round-trip (dup models_test); 64 hand-rolled onError.
- sections/resources_test / services_test: fine; "accessible" tests assert text only; could assert GlassCard semanticLabel.
- sections/status_section_test: 0 widget tests; model round-trips dup models_test; fixture isNotEmpty checks; only 91 is real logic.
- sections/tabbed_features_test: good; hover preview untested.
- sections/social_proof.inactive: widget unmounted (landing_page.dart:122-127); history 3818202 -> c2244b7 -> bc7930d (.inactive, "dead code") -> 6af1b39/#123 header; 469-513 literal self-compares; many findsWidgets; delete.
- helpers: scrollUntilVisible, pumpSession, widgetWithText, loadRealContent, resetTestContent unused; FinderX wrappers are no-ops.


---
# Flutter widget test review — final report

Scope: 37 files read in full (36 active + `.inactive`), `test_helpers.dart`, and every `lib/widgets/**`/`lib/theme/**` source they exercise. 455 active tests (435 `testWidgets` + 20 `test`), 53 inactive.

## 1. Test counts (widget[+unit])
common/: alert 10 · base_action_button 21 · buttons 7 · cards 7 · chip_badge 14 · containers 6 · copyable_code_field 6 · dashboard_card 3 · form_fields 14+1 · gradient_pill_badge 8 · hover_text_link 10 · info_card 33 · status_badge 7 · status_icon 19 · trust_badge 4 · vertical_indicator_list 13
consent/cookie_banner 19+2 · decorative/animated_orb 14 · docs/doc_components 28+1 · modals/api_key_modal 15 · demo_modal 15 · navigation/doc_page_scaffold 10 · shared_app_bar 7 · sub_page_shell 14
sections/: about 9 · contact 40+3 · cta 13 · features 9 · footer 9 · hero 13 · page_hero 10 · pricing 4+2 · resources 9 · services 6 · status 0+11 · tabbed_features 9 · social_proof.inactive 48+5

## 2. Findings (by impact)

`common/base_action_button_test.dart:12–403` — TAUTOLOGICAL/UNNECESSARY, all 21 — 15 "exposes X via BaseActionButton.X" (68–137, 161–230, 254–327) read back constructor args; 3 `isA<BaseActionButton>` (12–60) test `extends`; 3 "does not fire callback when onPressed is null" (351–403) never wire `pressed`, so `expect(pressed, isFalse)` cannot fail. Delete the file; if the disabled contract matters, assert `Semantics.properties.enabled == false` / `GestureDetector.onTap == null` (buttons.dart:84,93) per subclass.

`sections/social_proof_section_test.dart.inactive` — STALE, 53 tests — `SocialProofSection` compiles but is mounted nowhere (landing_page.dart:122–127, commented out "hidden until we have real testimonials"). 3818202 commented out `_buildTestimonials`, c2244b7 skipped that group, bc7930d renamed the file `.inactive` as "dead code", 6af1b39/#123 added the header. `_TestimonialCard` (lib:233–384) is dead too. Inside: 469–513 compare literals to themselves; 449–466 conditional `expect` passes on zero iterations; 557/570/611/651/681/693/793 `findsWidgets` on Text/Container/Column/Row/Padding/SizedBox. Delete test and widget; do not reactivate.

`sections/status_section_test.dart` — STALE/TAUTOLOGICAL, all 11 — never imports or pumps `StatusSection`; no StatusSection widget test exists in test/. 54/80/102/68 are constructor round-trips already in test/config/models_test.dart; 8–50 (10× `isNotEmpty`) validate the fixture (test_content.dart:315), not content.yaml. Only 91 (`status == 'Operational'`, models.dart:224) is real — move to models_test. Replace with StatusSection widget tests.

`sections/contact_section_test.dart` — DUPLICATED/STALE — 386 duplicates 316 exactly; 407 duplicates 331; 1038 tests `Alert`, duplicated by alert_test.dart:38 — delete all three. 1076 "…and clears form" never asserts clearing, and the W2 comment (382–385) cites it as the test that does — STALE; `_formData.clear()` (contact_section.dart:524) cannot clear visible fields because FormTextField uses `initialValue` (form_fields.dart:118), so a real assertion would expose a latent bug. 1132 "server field errors are displayed on form fields" returns no `fieldErrors` and asserts only the generic alert — duplicates 1106; return `fieldErrors`, assert the field's errorText. 906 asserts only `ContactSection findsOneWidget` — assert `find.text('Test Title')`. 274/290/657/677 enter text and find it again (framework echo); 657/677 never read `keyboardType`. Knowable-count `findsWidgets`: 651 (4), 654 (2), 742/849/897 (1).

`sections/pricing_section_test.dart` — TAUTOLOGICAL — 47 taps the toggle, asserts only `PricingSection findsOneWidget`; assert `find.text(tier.monthlyPrice)` after tapping `monthlyLabel`. 82 `expect(selectedTier, isNull)` with no tap — tap 'Try Basic', expect `'Basic'`. 141: `isNotNull` on non-nullable String (165–166), `length >= 0` (172), fixture `isNotEmpty` — delete. 181 constructor round-trip duplicated by models_test — delete. 64 hand-rolls `FlutterError.onError` instead of `setUpOverflowErrorSuppression`.

Viewport "renders on X" family — TAUTOLOGICAL/DUPLICATED — api_key_modal 229/248 (248 duplicates 12), demo_modal 233/255/304, sub_page_shell 94/99 (no viewport branch), cta 122/133 (duplicate 73), hero 166 (duplicates 78), features 93–115, contact 968, pricing 64: each asserts only `find.byType(W), findsOneWidget`. `testResponsiveLayout` (test_helpers.dart:393–423) is the same weak pattern, so adopting it adds nothing. Delete, or keep one per widget asserting `tester.takeException()` isNull plus a layout-specific finder (api_key_modal 207 is the model). demo_modal 232's "known overflow" comment (a1f8a35) is backed by no assertion.

Modals — DUPLICATED — api_key_modal 289 re-asserts 12+83; 269 `Icon findsWidgets` (icon is `ExcludeSemantics`); 34 differs from 12 only by the `api-key-field` key — merge; 331 constructor round-trip. demo_modal 10/51/70 share one arrangement — merge; 319 duplicates 31; 91 `IconButton findsWidgets` (count 1) — fold into 111.

`decorative/animated_orb_test.dart` — 9 of 14 TAUTOLOGICAL/DUPLICATED — 8/25/105/121/155 assert only `findsOneWidget`; 45 repeats line 22; 61/137 `Container findsWidgets` never read `BoxShape.circle`; 208 Stack/Positioned `findsWidgets`; 77 cannot detect a missing `dispose()`. Keep 172/190/226/247.

`common/containers_test.dart` — 9 `findsWidgets`, values never read — 12: ConstrainedBox maxWidth 800 knowable; 78: colour/gradient via `Container findsWidgets`, `id` via `Semantics findsWidgets` (label `'features section'`, containers.dart:111); 155 `Semantics findsWidgets` (assert `header: true`); 221 showOrbs=false asserts nothing. Read the decoration/label/constraint.

"Structure" `findsWidgets` family — TAUTOLOGICAL — Scaffold/Material already supply Semantics, GestureDetector, MouseRegion, CustomPaint, Stack, Container: buttons 67/281; cards 39/51/121 (StatCard label `'Uptime: 99.9%'` never asserted); alert 146/177/201; cta 97/108/146/157/168; hero 121/180/194; footer 105/115/164; features 48. footer 154 "Blog link accepts onNavigateToBlog" never taps Blog. Assert the specific property (`liveRegion`, `header`, `cursor`, gradient) or delete.

`docs/doc_components_test.dart` — 433 subsumed by 553 — DUPLICATE; 455 const-constructor and 17 enum — UNNECESSARY; "Custom accent color works" blocks (56, 105, 250, 309) assert only text; 575/399 `border isNotNull` cannot distinguish full from left border — assert `Border.fromBorderSide(BorderSide(color: AppColors.warning))`; 171 count is 2.

`common/form_fields_test.dart` — 121 never reads `keyboardType`; 138 and 182 (4 pumps) assert only `TextFormField findsOneWidget`; 12 enum. Assert `keyboardType`, `maxLines/minLines`, `maxLength`, counter visibility.

`common/vertical_indicator_list_test.dart` — 147 (`>=1`) subsumed by 193 (`equals(1)`) — delete; 170 `>=1` → `equals(1)`; 122 duplicates 253; 13 captures `builtIndicatorIndices` and never asserts it; 300 tests `super.key`.

`consent/cookie_banner_test.dart` — 349 ends on the same assert as 147 — DUPLICATE; 377 "has SafeArea on mobile": SafeArea is unconditional (cookie_banner.dart:130); 369 is not accessibility; 45/71 duplicate test/unit/models/consent_preferences_test.dart.

Smaller — shared_app_bar 53 duplicates 45+62; sub_page_shell 136 `pump()` never rebuilds, so cannot separate initState from build tracking — re-`pumpWidget` with identical props; hero 153 duplicates 78+89; copyable_code_field 153 sets only desktop (a313c54) — STALE name, duplicates 8; chip_badge 73 covered by 54; info_card 526 and page_hero 69 cannot fail; status_icon 208 `isNotNull` → `BorderRadius.circular(40)`; about 79 / resources 85 / services 55 take `ensureSemantics()` then assert text — use `find.bySemanticsLabel('$title service card')`. test_helpers.dart: `scrollUntilVisible`, `pumpSection`, `widgetWithText`, `loadRealContent`, `resetTestContent` have 0 uses — STALE; `FinderX` wrappers are no-ops.

## 3. Verified not a problem
- doc_components 'has semantics label' ×7: seven distinct exact labels, load-bearing for Playwright.
- status_icon 'has correct semantic label' ×4: four distinct strings.
- form_fields same-named ×3/×2/×2, containers ×2, cookie_banner ×2 (main vs preferences view), 'renders label text' ×3, 'renders section title/subtitle' ×3: different widgets or views.
- contact W2 comment "callback path does not clear _formData": accurate (contact_section.dart:495–503 vs 524); Calendly 1188/1222 pair has a real negative control.
- hover_text_link, dashboard_card, tabbed_features tab switches, shared_app_bar boundary, api_key_modal barrier/escape/PopScope: assert specific values.
- vertical_indicator_list padding predicates (164/187/215/288): exact EdgeInsets equality.

## 4. Missing coverage
- StatusSection: zero widget tests (badge colour by `allOperational`, 4 vs 2 columns, `'$name: $status'` semantics, link hidden when url empty).
- CookieBanner: nothing asserts which ConsentLevel is saved — the four consent buttons are indistinguishable; mobile 'Accept All' (339) untested.
- PricingSection: price swap on toggle and `onSelectTier(name)` never asserted.
- MarketingHeroSection (4 pages) and TabbedFeaturesSection hover preview untested.
- FormTextField keyboardType/autofill/obscureText/helpText; StatusBadge overrides; TrustBadge default icon; StatusIcon `_getDefaultLabel`; GradientIconContainer/BulletPoint (containers.dart:371–675) have no direct tests.


---

<!-- source: review-flutter-integration.md -->

# Flutter test review: integration, e2e, routing, root-level

## 1. Counts and what CI runs

All in-scope files read in full (25 test/helper files, ci.yml, e2e.yml, pubspec.yaml; no dart_test.yaml). Executed tests: blog_contact 9, comparison_conversion 13, consent_flow 13, contact_flow 9, docs_navigation 16, landing_navigation 12, login_nav 5, mobile_navigation 17, pricing_signup 11, signup_flow 12 (117); e2e consent 15, contact_form 14, landing_page 5, navigation 13, smoke 1 (48); app_router 70 (52 literal; loops 10+4+7), cookie_shell 14, app_test 44, widget_test 8, landing_controller 40. Total 341.

CI: `ci.yml:47` `flutter test --coverage` runs `test/` only. `e2e.yml:71` runs Playwright `e2e/*.spec.ts`. Nothing in `.github/`, `scripts/`, or `package.json` references `integration_test/`, `flutter drive`, or `test_driver/` — the 48 integration_test/e2e tests never run.

## 2. Findings

1. `integration_test/e2e/` (48) — STALE+DUPLICATED — never runs. consent_flow/navigation/landing_page (31d4a65, 2026-01-18) are the originals test/integration/consent_flow and landing_navigation were cloned from (f6561e1, 2026-01-29: same helper, same group names minus "E2E", same soft checks). Those three plus smoke: 18 `MaterialApp findsOneWidget`-only tests, 3 `|| MaterialApp`, 5 `|| true`; navigation:72 seeks the `Team` tier (renamed Growth); smoke_test:9 pumps `Text('smoke')`, no app code. contact_form_test (rewritten 2026-03-01) is the one substantive file; its promises already run in CI via `test/widgets/sections/contact_section_test.dart:551-592`. Action: delete directory, `test_driver/`, README section — or add `flutter test integration_test/` to ci.yml and delete the four hollow files.

2. test/integration soft assertions — TAUTOLOGICAL — 50 tests end in `expect(find.byType(MaterialApp), findsOneWidget)` after pumping a MaterialApp (mobile_navigation 12, comparison 8, docs_navigation 8, landing_navigation 6, consent 5, blog 4, pricing 4, contact 2, signup 1); 9 `|| find.byType(MaterialApp).evaluate().isNotEmpty`; 3 `|| true` (contact_flow:246, docs_navigation:355, landing_navigation:176); 37 `if (x.evaluate().isNotEmpty) {` guards around the only real assertion. ~60 of 117 cannot fail short of a throw. Action: delete or tighten to concrete text/type assertions.

3. Fabricated flows — TAUTOLOGICAL — the test builds its own GoRouter with stub pages and a button whose onPressed sets a local, then asserts the local: landing_navigation:97, comparison:183, pricing_signup:144, blog_contact:217 and comparison:308 (`currentRoute` set by the builder), docs_navigation:259 (asserts the test's own `redirect`; real one at app_router_test:189). No real CTA is tapped; `createAppRouter` unused. Action: delete; keep the 'Growth Plan' check once (signup_flow:271).

4. app_test.dart vs app_router_test.dart — DUPLICATED — 24 route→page assertions in both (/blog, both comparisons, /sources, /about, /signup ×2, 4 legal, unknown→LandingPage, audit-trails, /pricing, /careers, /security, 5 docs, /docs/agents, /support, /reports/*). app_router_test:149/156 assert only `uri.path == initialLocation`. Action: merge into app_router_test, move /app→/login (app_test:492) there, delete app_test 'routing', 'all routes', 'redirects' (26 tests).

5. app_router_test.dart — STALE/TAUTOLOGICAL — :430 "22 routes total", asserts `>= 20`; router has 44 GoRoutes, 17 untested anywhere (/features, /status, /demo, /request_success, /request_failure, /login, /forgot-password, /provision, /checkout, /checkout-success, /dashboard, /health, /billing, /usage, /entitlements, /quota, /api/toolkit). :139 `'/support redirects to /contact'` — no such redirect; asserts non-nullable `isNotNull`. :386-400, :562 `expect(router, isNotNull)` (:573 asserts LandingPage). :460 named "is invoked", asserts `isFalse`. :493 asserts `Stack findsWidgets`. :258-280 five /signup tests all `byType(SignupPage)`, :276 identical to :252, tier never asserted. :540-552 path-only repeats of :208/:214; :554 repeats :173. :120/:404/app_test:285 'creates a GoRouter' ×3. :128 tests GoRouter's default. :101-117 back-button helper guards tap+assert in `if (isNotEmpty)` — vacuous pass; the loops at :437/:445/:453 are distinct lists (21 routes) but all exercise one `_goHome` closure (app_router.dart:47), and per-page `onBack` is covered by `testBackButtonCallback` in 25 test/pages files. Action: delete 14; drop the guard; tighten /signup to `?tier=GROWTH`→'Growth Plan', `?tier=bogus`→'Starter Plan'; tighten legal routes (:284-306, four identical `byType(LegalPage)`) to titles.

6. app_test.dart — STALE — `_checkConsent`/`_createRouter` (:259, :263, :683, :689, :696, :704-714) do not exist; app.dart has `_initializeTracking`, `_handleConsentGiven`, `_showCookieSettings`. :318-365, :563-593 assert `cookieBannerNotifier.value` equals what the test set; :595-680 pass lambdas that mutate the notifier then assert the notifier — the test's lambda, not app.dart. :211 `theme isNotNull` → `equals(AppTheme.darkTheme)`. Action: delete 5, fix names.

7. Presence-only and framework tests — UNNECESSARY — widget_test.dart (template filename, b22bee5): 7 of 8 assert only app/MaterialApp/Scaffold/Scrollable presence, :89 identical to :24; with app_test:61/:70/:246/:259/:271/:683 that is 13 "app pumps" tests. cookie_shell_test :50, :100, :119, :194, :213, :232, :245, :257, :261 test constructors, Stack, StatelessWidget-ness, ValueNotifier; :9-46 re-implements overflow helpers test_helpers exports. Action: delete widget_test.dart and those 9; keep app_test:61 and cookie_shell :62/:73/:87/:139/:168.

8. landing_controller_test.dart — TAUTOLOGICAL/STALE — :26 `controller isNotNull` (non-nullable), :30, :53, :72-86 (`isA<T>` on getters typed T), :117-126 asserts `isNotNull` twice, never compares. :401/:446 "requires AnalyticsService mock (see BACKLOG)" — `enableCallLog()` is used at :16 and :229-311; BACKLOG has no such item. :337/:361/:403/:448 assert `offset` equals the `jumpTo` argument; nothing asserts an `AnalyticsEvent.scrollDepth` entry. :263-301 four tests of a one-line pass-through. Action: delete 9, tighten 4 to `analyticsLog`, keep one tier test.

9. 'back button works' — DUPLICATED — blog_contact:132, comparison:95, contact_flow:192, docs_navigation:94/:116, mobile_navigation:255/:280, pricing_signup:261, signup_flow:244 repeat `testBackButtonCallback` in test/pages. Action: delete 9.

10. Stale headers/names — STALE — every test/integration header promises absent steps: blog "click CTA", comparison "conversion CTA", consent "verify consent saved/analytics", docs "breadcrumb", landing "Learn More", mobile "tap hamburger… menu closes" (only login_nav_test taps `LucideIcons.menu`), pricing "annual/monthly toggle" (none exists), signup "verify confirmation". contact_flow:95 `'Start Your Journey'` exists nowhere in lib/ or content.yaml, so the test never taps. mobile_navigation:316 claims overflow would fail; setUp suppresses it. signup_flow:154 types 'Acme Corp' into Password (Company renders only for enterprise, signup_page.dart:175). Action: rewrite or delete.

11. Dead helpers — STALE — mock_services.dart: every class 0 readers; `IntegrationMocks` only `resetAll()`'d (9 files). integration_test_helpers.dart :68-215: `dismissCookieBanner`, `pumpAppWithRoute`, `navigateTo`, `fillFormField`, `scrollToFind`, `findTextContaining`, `tapButton`, `isTextVisible` 0 callers; re-exports 20 names, 6 used. test_helpers.dart: `pumpApp`, `pumpSection`, `expectTextStyle`, `expectContainerDecoration`, `resetTestContent` 0 callers. Sync `loadRealContent` 0 callers. `pumpFrames` defined 6×. Action: delete.

12. test/README.md — STALE — :9 "~1978 tests" (root README says ~3,017); :19 `providers/` removed in 3a7a96e; `config/`, `utils/` unlisted; :31-36 lists 4 of 5 e2e files; :28 documents a command CI never runs; :68 convention for a no-op mock.

## 3. Verified not a problem

- coverage_setup.dart is live (flutter_test_config.dart:6,15).
- The three onBack loops are distinct lists, not copies; no `skip:` anywhere in scope.
- login_nav_test (5) is fully real; signup_flow validation strings match signup_page.dart:297-319.
- test_helpers core is heavily used (setDesktopSize 46 files, testTheme 33, testPageStructure 17).
- 'Accept All', 'AI Observability', 'Get in Touch', 'Growth Plan', docs headings all exist in lib/test_content.
- Contact validation UI and `validateForm` run in CI (contact_section_test, contact_service_test).

## 4. Missing coverage

- `state.extra` redirect guards (app_router.dart:176-270; login-CSRF rationale :177) for /provision, /checkout, /dashboard, /billing, /usage, /entitlements, /quota — untested via `createAppRouter`.
- `SignupTiers.normalize` through the real router (case, whitespace, unknown tier).
- app.dart `_handleConsentGiven`/`_showCookieSettings` via a real CookieBanner tap; `initState` seeding the notifier from `ConsentManager.hasConsent()`.
- LandingController scroll-depth analytics: fired once, dedup, reset, `maxScroll <= 0`.
- 17 of 44 routes have no route→page test; /api/toolkit `onBack` goes to /docs, not home.


---

<!-- source: review-workers-lib.md -->

# workers/lib vitest review — tautological / unnecessary / stale / duplicated

Scope: 20 test files under workers/lib (471 it() calls), their production sources, workers/*/wrangler.toml and package.json, and workers/constants.ts, cors-utils.ts, http-helpers.ts. All read in full from disk (not the repomix pack). No file edited.

## Per-file working notes (appended as each file was finished)

- http/cors.test.ts — 14 real tests; withCors/handleOptions have no worker consumer (only corsHeaders is imported, by api-gateway/sender-worker).
- http/errors.test.ts — 19; :36 content-type test duplicates responses.test.ts:5 (errorResponse delegates to json()); serviceUnavailable (used by api-gateway helpers) untested; withErrorHandling unconsumed.
- http/responses.test.ts — 16; redirect() unconsumed by any worker and its absolute-URL throw untested; 'accepts a custom status' 19/80 are different functions (not a dup).
- http/request.test.ts — 22; requireJson/getQueryParam/getRequiredQueryParam/getPathname/assertMethod unconsumed by workers; getSearchParams untested.
- validation/parse.test.ts — 8; :19,:28,:38 guard assertions with `if (!result.success)` and never assert failure first (zero-assertion pass possible); array-index path branch untested; requireValidJson/zodValidationError unconsumed by workers (only mentioned in a comment in request.ts).
- hex-utils.test.ts — 7; fine.
- crypto.test.ts — 9; sha256Hex and arrayBufferToBase64Url (both consumed) untested; no known-answer vector.
- billing.test.ts — 12 (32 runs); :72 implied by :78; :90 runtime assertion tautological (two spreads of one array); isTerminalSubscriptionStatus (used by stripe-webhook) untested.
- entitlements.test.ts — 9; :83 expected value computed by the code under test.
- supabase.test.ts — 6; only insert/update/one query-filter case; single/select/order/limit/upsert/insertOrIgnore/deleteRows/rpc/throw path untested.
- api-keys.test.ts — 25 (31 runs); legacy rejection tests assert only ok===false; db-error path untested.
- auth.test.ts — 46; 7 near-identical positive tests; 427 & 451 duplicate earlier tests; second key pair/stub in the 'ES256 via JWKS' describe; Supabase-era comment + JWKS_URL stale (production = Auth0 RS256); no RS256 test in file; :487 toBeGreaterThan(1) with "exactly one refetch" comment; :488 resetJwksCache defeats the rotation claim; :596 not.toThrow on a template literal; :592 subsumed by :577 toEqual.
- deploy-environments.test.ts — 15 (60 runs); :226 comment-presence assertion; :216 vacuous today; :331 toBeTruthy on crons; :312 dev observability weaker than :300; STUB_WORKERS intentional. Stale comments in sender-worker/wrangler.toml :50-56, :109-113, :138-143.
- types/handler-options.test.ts — 22; no worker imports any of the four schemas (only `Env`/`AuthResult` types); EnvSchema's own comment says delete it if it drifts; :44 rationale wrong (JWKS URL derives from AUTH0_DOMAIN, not supabaseUrl).
- types/audit.test.ts — 33; zero consumers; AuditActionSchema vocabulary contradicts what api-gateway writeAuditLog actually writes (`api_key.created`, `api_key.revoked`, `billing_portal.accessed`, `checkout_session.created`).
- types/provisioning.test.ts — 34; zero consumers of schemas or types; inlines role/status enums instead of reusing OrgRoleSchema/OrgMembershipStatusSchema.
- types/request-bodies.test.ts — 25; CreateApiKeyBodySchema never run — api-gateway api-keys route uses a local interface and `request.json() as` with no validation; StripeEventBodySchema byte-identical to schemas.ts StripeEventSchema.
- types/schemas.test.ts — 62; same-commit sibling of the per-type files (2d56198), not a superseded monolith; BillingStatusSchema block tests 4 of 9 values; UsageBucketSchema duplicated in usage.ts with a different shape; many enum-through-composition and required-field tests.
- types/supabase.test.ts — 36; Query/RpcResult schemas model supabase-js `{data,error}` which this client never returns; RpcOptionsSchema has no counterpart in rpc(); Insert/UpdateOptions identical and tested twice.
- types/usage.test.ts — 51; UsageEventIngestionSchema (0 consumers) duplicates IngestEventRequestSchema; :59 named "negative" but tests 0.
- Stray root files: NOT dead — constants.ts imported by stripe-webhook/contact-form/receiver-worker, http-helpers.ts by api-gateway/contact-form, cors-utils.ts by contact-form.

## Final report

### 1. Test counts observed (it() calls; it.each expansions in parentheses)

| file | it() |
|---|---|
| api-keys | 25 (31) |
| auth | 46 |
| billing | 12 (32) |
| crypto | 9 |
| deploy-environments | 15 (60) |
| entitlements | 9 (10) |
| hex-utils | 7 |
| http/cors | 14 |
| http/errors | 19 |
| http/request | 22 |
| http/responses | 16 |
| supabase | 6 |
| types/audit | 33 |
| types/handler-options | 22 |
| types/provisioning | 34 |
| types/request-bodies | 25 |
| types/schemas | 62 |
| types/supabase | 36 |
| types/usage | 51 |
| validation/parse | 8 |
| total | 471 |

### 2. Findings (ordered by impact)

1. `workers/lib/types/audit.test.ts:19-37` — STALE — `AuditActionSchema` pins 17 snake_case actions; the only writer (`api-gateway/src/lib/helpers.ts:21 writeAuditLog`, called from routes/api-keys.ts:123,190 and routes/orgs.ts:276,400) emits `api_key.created`, `api_key.revoked`, `billing_portal.accessed`, `checkout_session.created`, none of which the enum accepts, and no worker imports the schema. The test certifies a vocabulary production contradicts. Action: validate `writeAuditLog` entries with the enum (add the four dotted names) or delete the enum and both tests.

2. `workers/lib/types/request-bodies.test.ts:13-44` — STALE — `CreateApiKeyBodySchema` (strict, name 1–255, ISO `expires_at`) runs nowhere: `api-gateway/src/routes/api-keys.ts:16-82` declares a local `interface CreateApiKeyBody` and casts `request.json()` with no validation. Seven tests certify limits production never enforces. Same status for `OrgIdParamSchema`, `ApiKeyIdParamSchema`, `PaginationParamsSchema` (0 consumers). Action: route through `requireValidJson(CreateApiKeyBodySchema)` or delete schema + tests.

3. Unconsumed schema families — STALE per the brief (no worker imports the schema; mostly not the inferred type either): all of types/provisioning (34 tests), types/audit (33), types/request-bodies (25), types/supabase (36; only inferred types feed lib/supabase.ts), types/handler-options (22; only `Env`/`AuthResult` types are used — handler-options.ts:27 already says "nothing imports this schema … should be deleted"), and 20 of 27 schemas in types/schemas.ts (consumed: `ApiKeyTierSchema`, `BillingStatusSchema`, `QuotaCheckRequest/Response`, `QuotaFlushResult`, `QuotaStatusResponse`). About 150 tests exercise validators no request passes through. Action: per family, wire in (audit, request-bodies), or keep one round-trip test per schema as contract documentation, or delete; do not keep per-field suites on unrun validators.

4. Source duplicates producing duplicated tests — DUPLICATED:
   - `schemas.ts:66 StripeEventSchema` ≡ `request-bodies.ts:34 StripeEventBodySchema` (byte-identical); tests `schemas.test.ts:204-218` ≡ `request-bodies.test.ts:124-141`. Delete one schema and its tests.
   - `UsageBucketSchema` defined twice with different shapes (`schemas.ts:123`, 6 fields; `usage.ts:77`, 7 fields + date regex) plus the hand-written `UsageBucket` interface (`types/index.ts:124`) — only the interface is consumed. Tests `schemas.test.ts:333-339` vs `usage.test.ts:159-169`. Delete the schemas.ts copy; derive the interface from usage.ts.
   - `provisioning.ts:83-84` inlines the role and membership-status enums instead of reusing `OrgRoleSchema`/`OrgMembershipStatusSchema` (it already imports `ApiKeyTierSchema`); `provisioning.test.ts:173-193` re-pins the lists tested at `schemas.test.ts:33-65`. Reuse; drop provisioning's enum tests.
   - `usage.ts:35 UsageEventIngestionSchema` (0 consumers) is `IngestEventRequestSchema` minus `org_id`/`source`; `usage.test.ts:83-105` duplicates `:107-135` ('defaults quantity to 1' ×2, metric_key bounds). Delete or `.extend`.
   - `InsertOptionsSchema` ≡ `UpdateOptionsSchema`; `types/supabase.test.ts:160-190` tests each twice while `SupabaseReturningSchema` itself is untested. Test the enum once.

5. `workers/lib/types/schemas.test.ts:44-54` — STALE + DUPLICATED — `BillingStatusSchema` "accepts all valid statuses" checks 4 of 9 values (pre-CR27 list); `billing.test.ts:78` pins the exact nine. Delete; also merge `billing.test.ts:72` into `:78`, which implies it.

6. `workers/lib/auth.test.ts` — DUPLICATED/STALE family — lines 119, 140, 159, 210, 252, 326, 419 build the same `{sub, exp, iat}` ES256 token with the shared key and assert `ok: true`; keep 159 (labelled positive control) and 419 (checks payload), delete five. `:427` re-asserts exp/iss/aud rejection already at 134/192/277 ("asymmetric tokens" is every token now); `:451` ≡ `:112`; the describe at 390-417 regenerates a second key pair and fetch stub duplicating `beforeAll`/`useSharedJwks`. STALE: comment 344-350 and `JWKS_URL` (354) describe Supabase-issued ES256; production verifies Auth0 RS256 (`api-gateway/src/lib/helpers.ts:64`) and this file has no RS256 test (the `ASYMMETRIC_ALGS` RS256 branch is reached only by api-gateway route tests via `test-helpers/auth0-jwt-stub.ts`). `:592` is subsumed by `:577` `toEqual`. Tighten: `:487` `toBeGreaterThan(1)` beside "initial fetch + one refetch" → `toBe(2)`; `:488` `resetJwksCache()` sidesteps the 30 s cooldown, so rotation pickup is not actually shown — use fake timers; `:596` `not.toThrow()` on a template literal cannot fail — assert `verifyJwt` rejects with the empty-domain key. Describe name at 188 carries ticket noise ("V-02, already done").

7. TAUTOLOGICAL / weak:
   - `entitlements.test.ts:83` — expected value is `projectPlanEntitlements(GROWTH)`, the code under test; use the literal from `:34`.
   - `billing.test.ts:90` — runtime `toHaveLength` compares two spreads of one array; only the annotation works. Use `expectTypeOf` or mark compile-only.
   - `deploy-environments.test.ts:226` — asserts the word "INHERITABLE" appears in api-gateway/wrangler.toml (comment presence, not behaviour); delete. `:216` asserts nothing today (no `[env.dev]` sets `preview_urls`); `:331` `toBeTruthy` on crons → pin `["*/15 * * * *"]`; `:312` checks dev observability `enabled` only, unlike `:300` for prod — add logs/invocation_logs.
   - `validation/parse.test.ts:19,28,38` — assertions sit inside `if (!result.success)` with no prior failure assertion; a passing parse yields a zero-assertion pass. Add `expect(result.success).toBe(false)` as `:11` does.
   - Per-field "accepts null/optional X" positive controls (~20): audit 60,64,116,166,264,268,272; schemas 258,284,337; provisioning 99,107,120,151; usage 71,167; request-bodies 18,22; handler-options 19,83. Collapse to one round-trip per schema.
   - `api-keys.test.ts:133,148,168,188` — assert only `ok === false`; the four legacy rejection paths differ only by message, so a mis-ordered guard passes. Assert the message (the obtk block at 282-297 is the better pattern).

8. UNNECESSARY (Zod behaviour, ~30): enum re-tested through composition — schemas 106,110,132,136,381,385,448; audit 178,280; usage 133,252. Required-field omission — schemas 114,186,215; request-bodies 55,73; provisioning 135. Bare type checks — schemas 162; audit 186; request-bodies 147. `z.unknown`/`z.record` acceptance — types/supabase 18-24, 53-63. `.url()/.email()/.uuid()` rejections — handler-options 26,30,87; schemas 239,266; provisioning 128. Keep at most one per schema.

9. `workers/lib/types/supabase.test.ts:27-71, 192-202` — STALE design — `SupabaseQueryResultSchema`/`SupabaseRpcResultSchema` model supabase-js `{data, error}`; this client returns `{ok, data} | {ok, error}` (supabase.ts:26-27), so nine tests describe a shape nothing produces. `RpcOptionsSchema` has no counterpart: `rpc()` takes `args` directly. Delete.

10. `workers/lib/http/errors.test.ts:36` — DUPLICATED — same promise as `responses.test.ts:5` (errorResponse delegates to `json()`). Delete.

11. Stale comments in inspected configs — `sender-worker/wrangler.toml:50-56` says RECEIVER still binds production and no dev receiver exists (contradicted by `:60-69`); `:109-113` and `:138-143` say `SHARED_SECRET` is still bound and dev's fix is pending (CR29 closed, dev receiver stood up). Fix the prose.

### 3. Suspected but verified NOT a problem
- `workers/constants.ts`, `cors-utils.ts`, `http-helpers.ts` are live: imported by stripe-webhook, contact-form, receiver-worker (constants), api-gateway and contact-form (http-helpers), contact-form (cors-utils).
- `schemas.test.ts` and the per-type files were created in one commit (2d56198, 2026-04-03); neither is a superseded monolith, and the shared test names refer to different schema objects.
- `http/cors.test.ts` has 14 real tests including the credentials+wildcard throw; the pack merely compressed it.
- `deploy-environments.test.ts` STUB_WORKERS assertion is intentional; `:133-134` toBeDefined/toBeTruthy are load-bearing (undefined would otherwise satisfy `not.toBe(config.name)`); TOML mini-parser handles every construct the five configs use.
- `auth.test.ts:549-573` deliberately uses type-forbidden shapes; each guards a different re-introduction path. Keep.
- No `skip`/`only`/`todo` tests in scope; `SHARED_SECRET` appears in no lib test.
- 'defaults metadata to {}' (audit 88,124 / usage 75), 'rejects ok: false' (supabase 81 / usage 328), 'rejects unknown action' (audit 34 / provisioning 195), 'accepts all valid sources' (provisioning 39 / usage 23) target different schemas — not duplicates.
- `responses.test.ts` 'accepts a custom status' 19/80 exercise `json()` and `redirect()` respectively.

### 4. Notable missing coverage
- `crypto.ts`: `sha256Hex` (the obtk digest) and `arrayBufferToBase64Url` (contact-form CSRF) have no direct test; no known-answer vector (RFC 4231) — HMAC tests only round-trip the code under test.
- `auth.ts`: RS256 branch, JWKS TTL expiry, unknown-kid refetch cooldown, keep-stale-cache-on-fetch-failure (`:133-141`), response without `keys` array.
- `supabase.ts`: `single`/`select`/`order`/`limit` serialisation, array and non-string filter values, `upsert`, `insertOrIgnore`, `deleteRows`, `rpc`, network-throw path — six tests cover insert, update and one filter case.
- `errors.ts serviceUnavailable` (used by api-gateway), `responses.ts redirect` absolute-URL rejection, `billing.ts isTerminalSubscriptionStatus` (used by stripe-webhook), `api-keys.ts verifyApiKey` when `sb.query` returns `{ok: false}`.
- `validation/parse.ts formatZodPath` array-index `[n]` branch.


---

<!-- source: review-api-gateway.md -->

# api-gateway vitest review — 2026-09-27

## 1. Counts (248 `it()` read in full; paths under `workers/api-gateway/src/` unless noted)

| File | it() |
|---|---|
| workers/tests/org-quota-do.test.ts | 26 |
| index.test.ts | 18 |
| aggregation.test.ts | 20 |
| durable-objects/quota.test.ts | 30 |
| lib/rate-limit.test.ts | 8 |
| lib/usage-ledger.test.ts | 3 |
| routes/health.test.ts | 5 |
| routes/ingest.test.ts | 26 |
| routes/api-keys.test.ts | 22 |
| routes/bootstrap.test.ts | 26 |
| routes/me.test.ts | 11 |
| routes/orgs.test.ts | 34 (it.each → 35 cases) |
| routes/usage.test.ts | 19 |

**Verdict on `workers/tests/org-quota-do.test.ts`: DELETE.** Its only import is vitest; every "endpoint" is an inline `simulate*` helper (lines 732–912) and all 26 tests assert those helpers against themselves. The routes it drives (`/check`, `/commit`, `/sync`, `/snapshot`, `/release-concurrent`) and its state shape (`entitlements`/`counters`/`concurrentJobs`) exist nowhere in `QuotaDurableObject` (`quota.ts:98-110` serves `/check-and-reserve`, `/flush-usage`, `/status` over `minuteUsed`/`monthlyUsed`/`seenRequestIds`); grep of src and lib for those paths: 0 hits; `OrgQuotaDO` appears nowhere else. It sits outside every vitest and tsconfig `include`; no package script or workflow names `workers/tests`. Standalone (`vitest run --root workers/tests`): 26/26 pass in 157 ms — self-consistency only. `tsc --strict` with workers-types: 19 errors (18× TS18046 `result` is `unknown`; line 794 `number | null` vs `satisfies QuotaCheckResponse`). It does not compile, exercises no production code, and does not duplicate `quota.test.ts` (a different system). Nothing to relocate; if the two-phase/entitlements design is still wanted, record it in `docs/BACKLOG.md`. It was still maintained (9230278 renamed free→starter inside it) while testing nothing.

## 2. Findings (impact order)

1. `workers/tests/org-quota-do.test.ts:1-912` — TAUTOLOGICAL (26/26) — see verdict — **delete**.

2. `routes/usage.test.ts:174` — TAUTOLOGICAL — asserts `bucket_date === gte.${body.period_start}`; both sides derive from the same `monthStart`, so it cannot fail. `usage.ts:101` still uses `new Date(now.getFullYear(), now.getMonth(), 1).toISOString()`, the local-time bug `bootstrap.ts:113` fixed and `bootstrap.test.ts:492` pins under `Asia/Tokyo`; the tautology hides it here. **Tighten**: assert `gte.<UTC yyyy-mm-01>` as bootstrap.test.ts does (and file the src bug).

3. `index.test.ts:228` — TAUTOLOGICAL — "fail-open when quota DO is unavailable" mocks `enforceOrgQuota` to `{ok:true}` and asserts not-429; the fail-open lives in `lib/quota.ts:140` (catch), which no test reaches (`enforceOrgQuota` appears only as a spy; `ingest.test.ts:360` runs the real one but only the allowed path). **Delete**; add `lib/quota.test.ts` with a throwing DO namespace. Sibling `:212` asserts status ∈ `[200,401,403,404,500,503]` (real value: 401 from `resolveUserId` on the 503 stub) — keep only the `enforceOrgQuota` called-with assertion or stub `GET users`.

4. `me.test.ts:83`, `bootstrap.test.ts:89` — STALE label — "401 for expired jwt" uses `header.body.badsig` with no `kid`; `verifyJwt` rejects at `auth.ts:204` before reading `exp`, so expiry is never tested (covered in `lib/auth.test.ts:134`). **Rename** to "rejects an unsigned token before any DB call" (the `stub.requests` length-0 assertion is the value) or delete.

5. `orgs.test.ts` portal vs checkout — DUPLICATED ×4 — both routes call one gate, `authorizeBillingRequest` (`orgs.ts:41`): pairs 295/458 (401), 302/468 (API-key 403), 311/480 (not member), 331/491 (role); the message assertions check only the shared suffix. **Merge**: keep the portal set, replace the checkout copies with one `it.each` wiring row per gate.

6. `api-keys.test.ts` create vs revoke — DUPLICATED ×4 — 151/343, 160/353, 179/361, 189/371 all exercise the shared `assertOrgMembership` + `API_KEY_ROLES` (`api-keys.ts:21,75,159`); viewer and billing_admin are the same branch. **Merge** to ~3 (`it.each(['viewer','billing_admin'])` on create, one wiring test on revoke).

7. `bootstrap.test.ts:114` ⊂ `:135` — DUPLICATED — 135 asserts 429 and zero DB calls; 114 asserts 429 only; each loops 121 RS256 verifications. **Delete 114.** `:552` (`id` matches `/^in\./`) ⊂ `:335` (`toBe('in.(org-1)')`) — **delete 552**. `:535` `not.toHaveProperty('current_minute_remaining')` is a regression guard, not stale, but redundant with `:536`'s keys equality.

8. `durable-objects/quota.test.ts:176/184/197` — DUPLICATED — 197 seeds `minuteUsed:60, units:1`, the same boundary 184 reaches after 60 calls; 176 is 184's first half without its assertion. **Merge** into one (60× 200, 61st 429). `:397` vs `:408` — 397's name claims the reset only 408 asserts; **merge**. `:146/:165` say "free plan" but seed `starter` — STALE naming after 9230278; the `DEFAULT_QUOTAS.free` alias (`quota.ts:63`) has no test.

9. `aggregation.test.ts:119` — DUPLICATED — conflict-column string already asserted at 68-79; **delete**. `:293` — UNNECESSARY — echoes inputs and `typeof string`; every monthly test already passes the Zod parse; **delete**. `:305` — tests `MonthlyUsageSummarySchema` from `workers/lib`; `lib/types/usage.test.ts:176` lacks the non-UUID/negative cases, so **move** it there.

10. `ingest.test.ts:192/320` — UNNECESSARY as written — `expect.any(Promise)` cannot distinguish the rollup from any promise. **Tighten**: await the captured promise, assert `stub.find('GET','usage_events')`. `:360` leaves `GET organizations` unstubbed (501, unasserted).

11. `index.test.ts:31` (GET /health) — UNNECESSARY/fragile — that describe stubs no fetch, so it performs a real fetch to `https://test.supabase.co` (47 ms here because DNS fails fast; up to `DB_CHECK_TIMEOUT_MS` 5 s elsewhere) and asserts only that fields exist. **Tighten**: stub fetch, assert 503/`unhealthy`.

**Auth-gate structure.** `requireBearerToken` and `verifyJwt` are shared and unit-tested in `workers/lib` (`http/request.test.ts:92`, `auth.test.ts`). The membership check is **not** shared: four copies (`ingest.ts:54`, `usage.ts:57`, `api-keys.ts:21`, `orgs.ts:74` via `loadUserMemberships`, plus bootstrap's own). Cross-file 401/403 tests are therefore legitimate per copy; the true duplicates are within-file (items 5, 6). `lib/helpers.ts` (`resolveJwt`, `resolveJwtRateLimited`, `resolveUserId`, `preVerifyToken`, `requireHmacSecret`, `loadPlan`, `loadOrgPlan`) has no direct test. Tests also pin an inconsistency: a missing `users` row is 401 on bootstrap but 404 on me and api-keys.

## 3. Suspected, verified not a problem

- `index.test.ts:45` vs `quota.test.ts:114` "404 for unknown path": worker router vs DO fetch — different objects.
- `ingest.test.ts` 107/254 and 185/309: `handleIngestOtel` calls `requireBearerToken` and inserts separately (`ingest.ts:156,196`) — distinct paths.
- `ingest:141` / `api-keys:199` "scopes the membership lookup": two different functions; the duplication is in src.
- Legacy `int_live_` fixtures: still valid (`lib/api-keys.ts:40`, minted by `api-keys.ts:93`) — not stale.
- `SUPABASE_JWT_SECRET`: no api-gateway test references it; the fixture is RS256/JWKS.
- `health.test.ts:45`: asserts src's PagerDuty URL constant, not a test-built URL.
- `me.test.ts:41` `USER_SELECT` is a test-side copy, so a select change fails it.
- `quota.test.ts:449` seeds after constructing `do1`: flush loads via `initialize()`; it verifies persistence.

## 4. Missing coverage

- `lib/quota.ts`: `enforceOrgQuota` fail-open, 429 mapping, header derivation; `checkAndReserve` non-429 throw; `flushUsage`/`getQuotaStatus`.
- `preVerifyToken` API-key branch (`index.ts:205`): index.test.ts sends only JWTs, so router-level 503-without-HMAC and key-verified org routes are untested; `obtk_` keys never hit `/v1/ingest/*`.
- `handleHealthCheck` `degraded` branch and the 5 s timeout race (health.test.ts mocks `query` ok:true always).
- `rollupDailyBucket` invalid date (`aggregation.ts:40`) and both `MAX_*` limit warnings.
- `QuotaDurableObject`: `free` alias, the cold-start race `blockConcurrencyWhile` guards, `minuteWindowExpiresIn`.


---

<!-- source: review-sender-receiver.md -->

# Review: sender-worker + receiver-worker vitest suites (2026-09-27)

Working notes, appended per file. Final report at the end.

## Files read in full
- sender-worker: index.test.ts (2629), index.e2e.test.ts (967), supabase.test.ts (445), utils.test.ts (258), env-validation.test.ts (170), auth0.live.test.ts (251); vitest.config.ts, vitest.e2e.config.mts, vitest.live.config.ts; src/index.ts, supabase.ts, utils.ts, types.ts, stripe.ts, crypto.ts, version.ts, e2e-fetch-mock.ts, test-helpers/fetch-mock.ts, test-helpers/fixtures.ts; wrangler.toml
- receiver-worker: src/index.test.ts (437), src/index.ts (144), vitest.config.ts, wrangler.toml
- workers/lib/crypto.ts, lib/crypto.test.ts (head), lib/http/responses.ts, constants.ts

## Suite membership (from configs)
- unit (`npm test`, vitest.config.ts): src/**/*.test.ts minus *.e2e.test.ts and *.live.test.ts -> index.test.ts, supabase.test.ts, utils.test.ts, env-validation.test.ts
- e2e (`npm run test:e2e`, vitest.e2e.config.mts, workerd via @cloudflare/vitest-pool-workers, outbound fetch stubbed by src/e2e-fetch-mock.ts, RECEIVER = inline echo stub): index.e2e.test.ts
- live (`npm run test:live`, vitest.live.config.ts, Doppler prd, real Auth0): auth0.live.test.ts
- receiver-worker `npm test`: src/index.test.ts

## Per-file working notes (all files finished)

### Evidence gathered
- `npm test` (sender-worker) = 203 tests / 4 files, all pass; receiver-worker = 33 / 1 file.
- Verbose run of `-t "Stripe"` with `--disableConsoleIntercept`:
  - index.test.ts:1569 'returns 500 when Stripe API fails': worker logged `[checkout] org lookup failed: Supabase user lookup failed: 401` (the once-mock was eaten by the Supabase lookup) and then `[stripe] checkout session creation failed: 401 { "error": { "message": "Invalid API Key provided: sk_test_**c123", "type": "invalid_request_error" } }` — a real reply from api.stripe.com; test took 231 ms vs 0-3 ms for its mocked siblings.
  - three `[checkout] org lookup failed: fetch failed` lines = tests 1526, 1829, 1846 have no fetch spy and make a real `fetch("https://supabase.test/...")`.
- `corsPreflightResponse` is referenced nowhere in src outside its definition (utils.ts:193).
- fixtures.ts helpers SendScenarioBuilder, CreateCheckoutSessionScenarioBuilder, whenError, resetTokenCounter, auth0TokenExchangeFails, supabaseOrgCreationFails, FetchMock.getCalls: zero references outside test-helpers/.
- `auth.verified_legacy_key`: no test references it (only a comment in index.ts:201 mentions key_unresolved).
- lib/http/responses.test.ts:5 already asserts json() content-type.

## FINAL REPORT

Paths under /Users/alyshialedlie/code/is-public-sites/IntegrityLandingPage/workers/; S = sender-worker/src, R = receiver-worker/src.

### 1. Test counts observed

| File | Suite | it() | runtime |
|---|---|---|---|
| S/index.test.ts | unit (`npm test`) | 122 | 122 |
| S/index.e2e.test.ts | e2e (`npm run test:e2e`, workerd, opt-in) | 49 | 49 |
| S/supabase.test.ts | unit | 48 | 48 |
| S/utils.test.ts | unit | 19 (one loop x9) | 27 |
| S/env-validation.test.ts | unit | 6 | 6 |
| S/auth0.live.test.ts | live (`npm run test:live`, Doppler prd) | 12 | 9 + 3 `skipIf` |
| R/index.test.ts | unit | 33 | 33 |

Unit total 203 (matches vitest). 289 tests read.

### 2. Findings (by impact)

1. `S/index.test.ts:1569` — ORDER-DEPENDENT MOCK — 'returns 500 when Stripe API fails' uses `mockResolvedValueOnce(401)`; the Supabase lookup consumes it and `vi.spyOn` call-through sends the Stripe request to the real network. Measured: `Supabase user lookup failed: 401`, then `[stripe] ... 401 "Invalid API Key provided: sk_test_**c123"`, 231 ms. Only status 500 is asserted, which both branches yield: `npm test` hits api.stripe.com and never tests the named branch. Action: route by URL as 1867 does. e2e:766 is currently the only test of Stripe's non-2xx path.
2. `S/index.test.ts:1526, 1829, 1846` — UNMOCKED NETWORK — no fetch spy; the org lookup really fetches `https://supabase.test` (three `fetch failed` logs); they pass only because the lookup is best-effort. Action: URL-routed mock, or a suite-level stub throwing on unmatched URLs.
3. `S/index.test.ts:923, 1912, 1943, 1976, 2012, 2051, 2066, 2087, 2110, 2149` — UNDER-ASSERTED — ten signup-error tests assert only `error === 'signup failed'`, never `code`; the classifier (index.ts:172-183) is covered only by the opt-in e2e block 807-967. Action: assert `code`; e2e 808/832/857/887/914/946 then become DUPLICATED.
4. `S/utils.test.ts:124-146` — STALE — 4 tests on `corsPreflightResponse()`, an export nothing calls (index.ts:549-555 builds OPTIONS inline). Delete, or wire index.ts to it.
5. `S/index.test.ts:2414-2464` — TAUTOLOGICAL — 4 tests assert literal values of the test-local `mockEnv`; 2440's fixture invariant is already enforced by 206's `not.toBe(sharedSecretSig)`. Delete.
6. `S/index.test.ts:2240-2300` — DUPLICATED — 2247/2282 repeat 726; 2264 repeats 1198; "No Global Spies" is false (`FetchMock.activate()` is `vi.spyOn`). Seven fixtures.ts helpers (`SendScenarioBuilder` ... `getCalls`) are unreferenced. Delete the 3 tests and dead helpers.
7. `S/index.e2e.test.ts:255,267,279,291,423,435,521,532,542,553,564,575,589,600,614,716,728,740,752` — DUPLICATED — 19 e2e validation/CORS tests of Zod and header logic with no workerd-specific failure mode. Keep one smoke per route. 508 (x-key-id over a real binding) earns its keep.
8. `e2e:485, 495` — UNNECESSARY as written — assert only 200 though the stub echoes `received`. Assert `received.tier` / `received.org_name`, or delete (unit 234/286).
9. `e2e:169, 808, 946` (and 211 vs 832) — DUPLICATED — one branch each; keep 808, 832. 857's narrative is fiction (invalid tier is coerced to `starter`); 914's `.optional()` rollback mocks assert nothing (the helpers swallow errors).
10. `e2e:652-802` — SILENT PATH — no `/rest/v1/users` interceptor, so every e2e checkout passes on the swallowed lookup-failure path; `metadata[org_id]` is never exercised in workerd. Add the interceptor and one attribution assertion.
11. `S/index.test.ts:909, 1292` — UNNECESSARY as written — `toContain('email')` matches both MISSING_FIELDS and INVALID_EMAIL messages, so the typeof check is indistinguishable from 867/1264; 2540 does it right. Assert `code`.
12. WEAK — `S/index.test.ts:1817` (`toBeTruthy`; `atob` throws on `.`, assert `toBe(rawJwt)`), `2223` (fallback is exactly `application/json; charset=utf-8`), `2228` (assert `'api-provisioning-sender'`, then e2e:451 is redundant), `e2e:690/693/694` (unit 1425 asserts exact values). Tighten.
13. `S/index.test.ts:411, 1699, 1712, 1725, 2588` (+426) — DUPLICATED structure — one `parseJsonBody`; one `it.each` over routes, fold 426 in. R:267 is another worker.
14. `S/supabase.test.ts` — 28-49 (regex constants) UNNECESSARY; 181/189/195 subsumed by 201; 131 and 240 subsumed by 73; 164 is unreachable input (EMAIL_REGEX rejects `user@@`) and hides the `user--<hash>` output; 395/421 'calls DELETE' never assert `method`; 364's title claims "swallows errors" but nothing errors (385 does).
15. `S/utils.test.ts:156` subsumed by 183; 163 adds only `retryAfterSeconds > 0` — fold in. 223 is a worker-route test in utils.test.ts overlapping index.test.ts:2601: one `it.each` over the three limited routes asserting 429, `code`, `Retry-After`.
16. `S/env-validation.test.ts:82, 133` — DUPLICATED/UNNECESSARY — 82's positives are weaker than 65's regex; all `not.toContain('AUTHO_CLI_*')` are subsumed by 147; 133 asserts comment prose. Keep 65, 98, 114, 147.
17. `R/index.test.ts` — TESTING THE DOUBLE — 100 (`apiKey` `/^sk-/` and `received` echo; production returns `obtk_`/keyId/prefix/tier), 111 (unique apiKey = `randomUUID`), 293 (title says stub), 73/83 (stub name; `json()` content-type is covered by lib/http/responses.test.ts:5). DUPLICATED: 90 = 73; 346 = 100 and 382's positive control; 175 subsumed by 237. Reduce 100/293 to status-only; delete 111, 90, 346, 83, 175.
18. `S/auth0.live.test.ts` — exercises no sender-worker code; a tenant probe. 123 repeats `beforeAll`; 175 repeats 166 inside the skipped block; 223 accepts 200/401/403 alike so cannot pin CR25's "My App keeps `password`". Tighten 223 if `AUTH0_CLIENT_ID` is that client; delete 123/175.
19. Minor: index.test.ts:350 reads `mock.calls[0]` with no reset in its describe; unused types index.test.ts:13-23, R:14.

### 3. Verified not a problem
- No stale legacy-path tests: every keyless/SHARED_SECRET test asserts rejection (S/index 464-548, utils 50-121, R 377-424); `auth.verified_legacy_key` appears in no test.
- `/forgot-password` + `auth0ForgotPassword` exist (index.ts:310-330, 501-519; supabase.ts:339): 2466-2627 are current.
- Rate limiter is wired (index.ts:462-518); e2e `withUniqueClientIp` is required.
- All other `mockResolvedValueOnce` sites sit on single-call paths; 1569 is the only violator.
- 776/2486 build expected URLs from env constants, not the code under test.
- SHARED_SECRET fixtures differ from the active key in both workers; 206 asserts `toBe(v2Sig)` and `not.toBe(sharedSig)`.
- 275/304/318 and 385/411/437 are three functions each; supabase:57 vs lib/crypto.test.ts:33 are different functions.
- env-validation covers all 15 non-binding Env keys.

### 4. Missing coverage
- `enrichReceiverErrorBody` (index.ts:257-273): enrichment branch untested; 322 covers only "code absent".
- `checkAuthRateLimit` KV happy path: no working-KV test where the stored count exceeds MAX while in-memory is fresh; only the failing-KV degrade (utils 206).
- `/signin` 429 never asserted at HTTP level.
- `getClientIp` X-Forwarded-For fallback (utils.ts:16-22) untested; only CF-Connecting-IP (171).
- e2e rollback: deletes are `.optional()` and 914's rollback token interceptor is consumed by the ROPC step, so the Auth0 user delete is never verified in workerd.


---

<!-- source: review-stripe-contact.md -->

# Test-suite review: stripe-webhook + contact-form (2026-09-27)

Status: all files read in full (contact-form index.test.ts in ranges 1-950 / 951-1896); findings verified against src and by grep; counts from `vitest run --reporter=verbose`.

Paths are under /Users/alyshialedlie/code/is-public-sites/IntegrityLandingPage/workers/. 267 tests checked: stripe-webhook `npm test` 181 green, live suite 5 (skipped without secret), contact-form 81 green.

## 1. Test counts observed

| File | Tests |
|---|---|
| stripe-webhook/src/handlers/checkout.test.ts | 9 |
| stripe-webhook/src/handlers/invoice.test.ts | 16 |
| stripe-webhook/src/handlers/subscription.test.ts | 38 (28 `it` + 10 via `it.each`) |
| stripe-webhook/src/index.test.ts | 46 |
| stripe-webhook/src/supabase.test.ts | 54 (47 + 7 via `it.each`) |
| stripe-webhook/src/stripe-schemas.test.ts | 18 |
| stripe-webhook/src/webhook-signature.live.test.ts | 5 (opt-in, `describe.skipIf`) |
| contact-form/src/index.test.ts | 81 |

## 2. Findings (impact order)

1. `stripe-webhook/src/index.test.ts:700,727,777` — DUPLICATED/weak (cron path, CR20) — titled "handleX called" but never assert the handler; they assert claimEvent/resolveDeadLetter, which pass only because sibling handler mocks retain `mockResolvedValue({ok:true})` from earlier tests (`vi.clearAllMocks` keeps implementations). Mis-routing would pass. Stale comment at :711. Action: replace 700/727/752/777 with one `it.each` over the five event types asserting the exact handler called and siblings not.
2. `index.test.ts:211` vs `:293` — DUPLICATED — identical arrangement; 293 is a superset. Delete 211. `:339` — handlers are mocked, so processEvent cannot see *why* ok:false; adds nothing over 293. Delete.
3. `index.test.ts:75-146` (7 rejection tests) — weak — each asserts only `result.ok === false`, never the reason; each would pass for the wrong reason. Assert `result.error` body text (the live suite does). `:148` — TAUTOLOGICAL — the signature is wrong anyway, so ok:false is reached without the mocked importKey rejection. Sign validly then mock the reject, or delete (lib/crypto.test.ts owns hmacVerify's catch).
4. `contact-form/src/index.test.ts:857-1007` ('Email Routing Verification', 6 tests) — DUPLICATED — src has one `to: [env.RECIPIENT_EMAIL]`, no routing; to/from/replyTo are all asserted at :383. Delete the describe.
5. `contact-form:771` — TAUTOLOGICAL — `expect(headers.get(...)).toBeDefined()`: `get()` returns null, which is defined. The real promise (evil origin not echoed, no credentials) is untested. Tighten to `toBe('https://integritystudio.ai')` and `Allow-Credentials` null.
6. `contact-form:641` — weak — asserts `not.toBe(500)`; the actual response is 504 because `send` is unmocked (stderr: `resend_timeout: Cannot read properties of undefined`). Mock send, assert 200.
7. `invoice.test.ts:46,137; subscription.test.ts:80,216` — DUPLICATED — "customer absent" is the schema case (invoice:49 says so), tested one case above and in stripe-schemas.test.ts:59/109; asserts only ok:false. Delete four.
8. `invoice.test.ts:129-167` (5 tests) — DUPLICATED — paid/payment_failed share `resolveOrgId`+`setBillingStatus`; these re-run the same helper lines. Keep :169 (past_due wiring); `describe.each` the shared family over both handlers. (updated/deleted are separate functions with distinct literals and error strings; their families are legitimate — the duplication there is in src.)
9. `invoice.test.ts:71` — TAUTOLOGICAL — "prefers parent over legacy" is unobservable through the handler (truthiness only); ok:true either way. `getInvoiceSubscriptionId` has no direct test (grep). Move to stripe-schemas.test.ts asserting the returned id.
10. `supabase.test.ts:234` — STALE+UNNECESSARY — comment cites a `?? 'Unknown error'` fallback absent from supabase.ts; the `HTTP 500: ` prefix is lib/supabase.ts behaviour, covered in lib/supabase.test.ts. Delete. `:804` (200 DELETE = ok) — lib behaviour; delete. `:488` vs `:456` — `false` and omitted hit the same `if (bumpQuotaVersion)`; merge as it.each.
11. `webhook-signature.live.test.ts:54` — STALE premise — `VERIFIED_STATUSES=[200,500]` assumes dev has no DB binding; stripe-webhook-dev has held dev credentials since 2026-08-03, so a broken Supabase binding now passes as "signature accepted". Tighten to 200 (or 500 only with body 'Failed to check idempotency'). Guard `describe.skipIf(!WEBHOOK_SECRET)` is present (:119), but a missing Doppler slot yields "5 skipped, exit 0", indistinguishable from a pass; fail when `CI`/`LIVE_TESTS` is set and the secret is absent.
12. `stripe-schemas.test.ts:30,84,126` — TAUTOLOGICAL x3 — :33-35 asserts Zod copies the field; collapse to one it.each asserting `success` only. `:20` subsumed by `:15` (`{}` passes); `:114` duplicates `:109`. Delete both.
13. `checkout.test.ts:110`, `subscription.test.ts:199,289` — DUPLICATED — "fully successful path" asserts only ok:true on inputs already used at :69/:141/:274, which do not assert result. Add `expect(result.ok).toBe(true)` there; delete these three.
14. contact-form status-only success tests — UNNECESSARY — :288 (subsumed by :453), :363 (by :409), :1241 and :1363 (mockEnv has no KV, so every 200 test is this path), :1495 (by :1538), :161 (identical to :1762), :1724 (no boundary; magic 200/20000 instead of MAX_REQUEST_BODY_BYTES). Delete seven.
15. contact-form parameterize — :189/202/216 (name), :305-361 (max length; hard-coded '100'/'200'/'5000' though constants are imported), :1011-1095 (escapeHtml x4), :737/813/1381/1401/1420 (exact-match origin x5), :1441-1491 (unicode x3), :173/180 (405). Loose: :1794/:1814 `toContain('CSRF')` matches any CSRF error; :515 titled "network timeout" but arranges a generic rejection.
16. `contact-form:1636` — fragile — `vi.useRealTimers()` not in finally; a failure leaks fake timers into later tests. `:1128/:1201/:1299` assert `put` called or 200 but not what was written (count, resetAt, `expirationTtl`, cached-body equality; `expirationTtl` appears nowhere in the file). Tighten.
17. Cosmetic stale: `contact-form:66` `mockEnvWithCsrf = mockEnv` "back-compat" alias; `:21` `ApiResponse` unused; `:49` "new fail-closed guard".

## 3. Suspected, verified not a problem

- supabase.test.ts 'DB failure' x10: each function maps its own `sb.<verb>` over a distinct `METHOD table` stub route — genuine per-function wiring. Keep.
- subscription.updated vs .deleted: separate functions, distinct literals and error strings; both families legitimate.
- checkout.ts:24: both branches plus the absent case are tested (:69, :82, :60).
- Five subscribed events: every tested type is one of the five (plus `payment_intent.created` as the deliberate unhandled probe).
- `STRIPE_PRICE_TO_PLAN_JSON` matches src `Env`; `STRIPE_PLAN_TO_PRICE_JSON` is sender-worker's, not a rename.
- `makeMockCtx().flush()` asserts status before flushing waitUntil, so CR21 is genuinely tested.
- Live file is excluded from `npm test` and run only by vitest.live.config.ts.
- The 429 test omits the CSRF header; rate limiting precedes CSRF in src — correct.
- `_resetRateLimitState()` in beforeEach isolates module-global circuit state.
- No `it.skip/todo/only` anywhere in scope.

## 4. Missing coverage

- contact-form in-memory denial: no test sends more than RATE_LIMIT_MAX from one IP without KV expecting 429; degraded/kv_unavailable logs and map eviction untested.
- contact-form: idempotency KV get/put throwing (both src catches), TTL; subject CRLF `sanitizeHeader` (no `\r` in the file); `organization` escape; `Cache-Control: no-store`; same-length wrong CSRF signature and non-numeric timestamp; email/organization max length.
- stripe-webhook cron: `claimEvent` returning `claimed:false` still resolves; `abandonDeadLetter` failure (src ignores the result); `fetchPendingDeadLetters(50)` asserted.
- `getInvoiceSubscriptionId` direct tests; `InvoiceSchema` with `parent: null`.
- `processEvent` unhandled type: assert `addDeadLetter` not called (:911 asserts only 200).
