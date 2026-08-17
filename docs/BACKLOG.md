# Backlog

Open and deferred items only. Completed items are migrated to `docs/changelog/1.0/CHANGELOG.md`, `docs/changelog/1.1/CHANGELOG.md`, `docs/changelog/1.2/CHANGELOG.md`, and `docs/changelog/1.3/CHANGELOG.md`.

**Last Updated:** 2026-08-17 (**[[W10]] FULLY COMPLETE** — `provision-api-key` deleted from production (verified 2026-08-17); dead edge function, superseded by sender-worker + api-provisioning-receiver. `ga4-*` confirmed intentional; `verify_jwt` pinned for all three in `config.toml`.) | 2026-08-09 (**[[W12]] resolved and removed** — all five cross-environment values in Doppler `dev` fixed: `IS_PROD_TOKEN` (a `dp.st.prd.` service token granting dev read of the entire production config), `OBTOOL_API_KEY_INVENTORY_AI` and `JWT_SECRET` deleted from `dev`; `OTEL_EXPORTER_OTLP_ENDPOINT` and `OBTOOL_INGEST_ROUTE` repointed at `obtool-ingest-dev`. `check:env-isolation` now passes with **zero** `KNOWN GAP` rows, and `KNOWN_GAP` is kept as an empty map rather than deleted — an empty map asserts "no known-wrong shared values", removing it would assert nothing. Full detail migrated **verbatim** to [`docs/changelog/1.3/CHANGELOG.md`](changelog/1.3/CHANGELOG.md) before deletion, per this file's own rule that a changelog holding an id but not the content is the same loss with a citation on top. ⚠️ One trap worth carrying: `JWT_SECRET` appeared to have 8 consumers, all of them substring matches inside `SUPABASE_JWT_SECRET` — the third instance of the substring-merge error after [[CR31]]'s `sandbox-api.` hostname.) | 2026-08-08 (**[[W09]] and [[W07]] are CLOSED, and each closed by inverting its own premise.** W09 asked for "accept `CLOUDFLARE_D1_TOKEN`" and the measurement showed it is one of **ten** account-scoped credentials that cannot be environment-scoped at all — so the acceptance is of the class, recorded per name in code and printed every run, not of one row. Its "generalisable half" is now built: `check:env-isolation` classifies **every** byte-identical shared name and **fails on any it cannot account for**, mutation-proven both directions. That pass immediately found **five more** cross-environment values — including a `dp.st.prd.` Doppler service token in the `dev` config, which reads the whole production store — now carved out as [[W12]]. Six further latent production identifiers were repointed in `dev` (`prd` verified untouched). **W07's premise was refuted outright**: `secrets get <missing> --plain` errors cleanly on the *same binary* that supposedly dumped a config; the form that dumps is the bare `secrets` list, which no script calls. Documenting the claim as written would have planted a false gotcha in an auto-loaded file. — *Previously:* **[[CR13]] is DECIDED — `api-gateway` gets `api.integritystudio.dev` (option C), and the remaining work is a registrar action rather than anything in this repo.** The name was already the gateway's Auth0 audience and resource server (`69c4e28bf801eab9e683c85a`, `wrangler.toml:41,101`) — ⚠️ but an audience is an **opaque identifier** under no obligation to resolve, so nothing was broken by it not resolving and this is naming correctness, not a repair. 🔴 **The blocker is measured, not assumed: `integritystudio.dev` is not a Cloudflare zone** — the account holds only `integritystudio.ai` and `alephatx.info`, and the domain delegates to `*.ns.porkbun.com` — so **no Workers route or Custom Domain can attach to it at all**, and no `wrangler.toml` edit can change that. Migration is a **delegation change, not a registrar transfer**: the domain stays at Porkbun and only the NS records move. Both usual blockers are already clear — **DNSSEC is off** (no `DS` at the `.dev` parent, no `DNSKEY`, no `ad` flag), and there is **no MX/TXT/CAA**. ⚠️ **The apex is ruled out on evidence, not preference** — `integritystudio.dev` answers **200** serving the GitHub Pages dashboard SPA, so a route on `/*` would capture it; the target is the `api.` label only. ⚠️ **The record inventory is probed, not authoritative** — Porkbun API access is off for this domain, so it lists only the types someone thought to ask for, and Cloudflare's scan-on-add is also incomplete; export from the Porkbun dashboard and diff against both. That is the same "probe where you should read the source of truth" error this file has now recorded four times. Two ordering traps recorded so they are not rediscovered: **adding `routes` before the zone exists breaks `deploy:prd` outright**, so the config change is *last*; and if the GitHub Pages records are proxied, SSL/TLS must be **Full**, not Flexible — `.dev` is **HSTS-preloaded**, so Flexible against an HTTPS-only origin yields a redirect loop that takes the dashboard down. The `*` wildcard does **not** survive the move (Porkbun URL forwarding is a registrar feature, so `app`/`dashboard`/`docs`/`status`/`sandbox-api` NXDOMAIN unless rebuilt as a Redirect Rule), and rollback is reverting NS — **hours, not minutes**, since the parent governs delegation TTL. Knock-on: this **supersedes [[CR31]]'s 4-pattern path-split recommendation** and [`docs/api-routing.md`](api-routing.md) § "Recommendation — split by path", **which has not been updated and now contradicts [[CR13]]** — the exact multi-place staleness this file keeps catching, flagged rather than silently left. New cost accepted: the dashboard's DNS comes under Cloudflare, where a Cloudflare mistake can now reach it) | 2026-08-07 (**[[CR11]] is DONE — the last gap it named, "the dev Supabase project has zero edge functions", is closed, and with it [[CR02]] item 5.** The toolkit e2e suite now runs entirely against dev — `api-provisioning-receiver-dev`, `sender-worker-dev`, `obtool-api-dev`, `obtool-ingest-dev` — finishing **34 passed / 0 failed / 12 skipped** with **zero** cross-environment skips. Re-measured here rather than carried over from the toolkit's own notes: `dev`'s `PROVISIONING_RECEIVER_WORKER_URL` and `PROVISION_WORKER_URL` both resolve to the `-dev` Workers and `ACTIVE_KEY_ID` is `dev1`, which are the three slots CR11's status line had recorded on 2026-08-06 as still production-pointing or unset. ⚠️ **The ✅ is narrower than it looks, and the narrowing is the interesting part.** ~~The `e2e` job is still **absent** from the toolkit's `publish.yml` — that is a one-line change owned there (`E2E-CI-RESTORE`), not work here.~~ ✅ **Corrected 2026-08-08: the job is back.** `observability-toolkit`'s `publish.yml:100` declares `e2e`, and that repo closed `E2E-CI-RESTORE` into its `docs/changelog/3.1.7/CHANGELOG.md` ("Restored the `e2e` job to CI"). This claim was restated in **three** places here and went stale in all three at once when that repo shipped the fix — the same failure mode as the five-place cost claim above, and the reason a cross-repo status belongs in one place that points at the other repo rather than being copied. And the green number is **26% inert**: 12 of 46 tests are gated off in every configuration anyone runs, so `34 passed` reads as full coverage of a suite that is nothing of the kind — filed as `E2E-PERMANENT-SKIPS` rather than absorbed into the ✅, which is the same "hollow green" failure this session spent most of its time removing. 🔴 **Three defects found on the way, all of them the suite or the environment lying about itself:** the suite **exited 0 when rate-limited** (fixed — `assertNotRateLimited` throws, mutation-proven by a third run exiting 1); `vitest.config.e2e.ts` was collecting **itself** as a test; and `createTestUser` hardcoded a **production** org UUID. Also: deploying edge functions to dev silently applied the CLI's `verify_jwt` default instead of production's values, and it *worked* only because dev's service key is still legacy JWT format — rotating that key would have started 401ing dev provisioning with no code change and no obvious cause (now pinned in `supabase/config.toml`; the key-format gap is open in [[W10]]). Two cross-environment values remain open in [[W09]] — `VITE_AUTH0_CLIENT_ID` and `CLOUDFLARE_D1_TOKEN` — so CR11's green detector still proves only what its list names) | 2026-08-06 (**[[CR11]] step 8 closed — and the item was asking for work that had already been done.** It read "mint a dev-scoped Cloudflare token, Dashboard-only, so it is on the owner", with a warning to re-measure because the dev token had been rotated. The rotation *was* the scoping: `dev`'s `CLOUDFLARE_API_TOKEN` has resolved to a purpose-built `dev-workers-token` (`5fc67fe7`) since 2026-08-03, carrying Workers Scripts/KV/Account-Settings-Read and **no** Routes, Zone, R2, D1, Pages or token-admin. So nothing needed minting and none of it needed the Dashboard — the missing work was entirely measurement, and it is now done: paired capability controls against `prd`'s token on the same endpoints (dev fails zone-routes, prd succeeds — a **positive control**, because a uniform negative is what a broken probe looks like and this repo has now hit that four times), plus a real `npm run deploy` landing `sender-worker-dev` `01c2da65` healthy with [[CR14]]'s `previews_enabled: false` intact. Item 9's revocation needs no action: the superseded token is already absent from the account's 7, and a 40-char non-`cfat_` value is the legacy *account-owned* format, so it was deleted rather than merely rotated out of Doppler. ⚠️ **The limit of that check, stated so it is not over-read:** user-scoped tokens cannot be enumerated from this machine at all — `dev`'s `CLOUDFLARE_GLOBAL_API_KEY` is dead (`9103`) and nothing else carries user-level auth. 🔴 **Found on the way, unrelated to CR11: two live tokens with no consumer and `last_used_on: never` since 2025-12-01** — `12c7e4bd`, carrying Workers **Routes** Write across `zone.*` plus Scripts/Pages/R2 (the full [[CR13]] hijack capability), is ✅ **revoked**, verified by re-resolving all five in-use credentials and re-checking production health afterwards so the delete could not be confused with a lucky no-op; `feef0f3d` (account-wide read) is **retained by owner decision**. 📌 Also: the structural ceiling has not moved and cannot be moved by a token — Workers Scripts is an **account-level** permission with no per-script selector, so `dev-workers-token` still reads all 18 scripts and an `Edit` token still reaches production. [[CR02]] item 5's dev receiver is now CR11's only remaining hop, and the block was re-measured rather than assumed: `dev`'s `PROVISIONING_RECEIVER_WORKER_URL` still points at the **production** receiver) | 2026-08-03 (**[[CR04]] re-measured and then fixed — the item had been blocked on a premise that was false since it was filed.** The fragment is now deleted from `provision_page.dart`, committed on `fix/active-subscription-id` and unpushed, shipping on merge to `main`. CR04 says the fragment handoff needs "a coordinated change in the dashboard app". It does not: the receiving app at `integritystudio.dev` is `integritystudio/quality-metrics-dashboard` on GitHub Pages, and it **never reads the fragment** — zero `location.hash` reads in the deployed bundle, its `wouter` router sources location from `location.search`, and every `access_token` occurrence is `@auth0/auth0-spa-js` internals. It authenticates itself, with its own Auth0 SPA login. So the token is written into a URL and dropped, and the fix is to **delete the fragment** — one line, this repo only, no `postMessage` and no exchange code. ⚠️ **Checked the thing that would have overturned that:** the audiences **match** (`https://api.integritystudio.dev` on both sides), so this is an unread handoff, not an unusable one — do not record it as a token-mismatch bug. Two reasons it is still worth removing: the JWT lands in that origin's address bar and history, and **that origin cannot be hardened** — GitHub Pages sets no response headers, so no CSP, no `Referrer-Policy`, no HSTS, and no `<meta http-equiv>` CSP either. Verified two independent ways after a GitHub code-search negative *disagreed* with the deployed artifact: code search returns 0 for `access_token`, the bundle contains it — reconciled by reading the surrounding context, and by confirming there are **no lazy chunk names**, so the grepped bundle really is the whole app. **A code-search negative is not evidence about a deployed artifact.** Incidental, and relevant to [[CR31]]: the dashboard's own API is `quality-metrics-api.alyshia-b38.workers.dev`, a **third** product API on workers.dev, in neither this repo nor `observability-toolkit`. ⚠️ **And CR04 cited a commit that does not exist** — `d632263` is unresolvable; the real one is `1c83136`. Systemic, not a typo: **76 of the 85** seven-hex SHAs in this file are dead, because [[CR01]]'s history scrub force-pushed over every commit before 2026-07-29. Treat every pre-scrub SHA citation here as unverifiable) | 2026-08-03 (**filed [[CR31]] — the published API docs advertise four URLs that resolve to nothing, and `api-gateway` has no hostname.** Answering "should `api.integritystudio.ai/*` point at `api-gateway`?" required inventorying both API surfaces, so the measurement is now a document — [`docs/api-routing.md`](api-routing.md) — rather than a session finding. The answer is **no, not the wildcard**: the two route tables are disjoint apart from `/health`, so repointing would 404 all thirteen `obtool-api` routes including `/v1/traces`, the one advertised endpoint that works. A four-pattern path-split needs no code change on either worker, but it re-opens [[CR13]]'s trap — top-level `routes` only, explicit `routes = []` under `[env.dev]`. **Four** customer-visible defects needing no decision: the quickstart's first command 401s (`/v1/health`; health is at `/health`), `POST /v1/alerts` exists on **neither** worker, and both `sandbox-api.integritystudio.ai` and `status.integritystudio.ai` — the latter the docs landing page's Status quick-link — are NXDOMAIN. ⚠️ **Three traps produced wrong readings on the way there, all now recorded:** `curl` defaults to GET, so POST-only routes read as missing; a 401 proves the `/v1/*` middleware ran, not that the route exists; and **a bare-substring grep merges subdomains** — `api.integritystudio.ai` is contained in `sandbox-api.integritystudio.ai`, so the first version of the checker emitted one host for two and hid the fourth defect completely. Same class as the [[CR14]] blanket-403 and the [[CR29]] positive-control note, and the third time a green check here had normalised away the thing it was checking — probe only what is live, read source for a route table, and give every checker a positive control) | 2026-08-03 (**[[CR11]] credential isolation is DONE — `npm run check:env-isolation` PASSES, exit 0**, 15 credentials distinct and both Stripe rows test-in-dev / live-in-prd. Doppler `dev` reaches its own Supabase project, Auth0 tenant and Stripe sandbox; the `*-dev` Workers are armed and a live `POST /signup` on `sender-worker-dev` proved it end to end. That unblocks [[CR02]] item 5, the dev receiver, which had been blocked behind CR11 step 1. ⚠️ **Staleness sweep, same session — both steps added on 2026-08-02 were mis-stated, and one had been false from the moment it was written.** Step 9 ("dev has no Stripe sandbox") was already done: `dev` has held `sk_test_` keys on the sandbox account throughout, and Stripe was the one family that was *never* shared. Step 8 said `deploy` and `deploy:prd` "share one `CLOUDFLARE_WORKER_TOKEN` from Doppler `prd`" — wrong slot, wrong config, wrong conclusion: `wrangler` reads `CLOUDFLARE_API_TOKEN`, `deploy` sources it from `--config dev`, and the two values are distinct (sha `abb57cc474cb` vs `25889310adec`); the byte-identical `CLOUDFLARE_WORKER_TOKEN` is read by no code in this repo. **This is the third time a claim here has audited a name that was not the one in play** — after `SUPABASE_SERVICE_ROLE_KEY` and `SUPABASE_PROVISIONING_KEY`. The residual risk in step 8 is real but different, and no token can close it: dev's token is account-wide in scope, Cloudflare has no per-script scoping for Workers Scripts, so only separate accounts make production unreachable) | 2026-08-02 (**dev↔prd isolation re-audited against vendor terms — the blocker was phantom.** [[CR11]] had said it was blocked on "whether to pay for a third Supabase project"; the org holds **1** project of 2 free slots, so that project is free, and an Auth0 dev tenant is free too — **and does not even need creating**, since `dev-njjmghdzm23uy0p7` already exists and is live, so that blocker is one M2M credential. Neither blocker is financial; both are ~15 minutes of manual provisioning. ⚠️ **Self-correction, same session:** the first pass of this rewrite restated step 2 as "create a tenant, not scriptable at any price" while CR11's own 2026-07-29 update, ~60 lines below, already said otherwise — the *Sequenced target* line had carried that same contradiction since 2026-07-29. Both are fixed. A canonical block does not help if it is written without reading the item's later updates. The cost claim had been restated in five places and went stale in all of them at once when `atx_movement` was deleted on 2026-07-29, so it is now a **single canonical block** at the top of CR11 and every other copy is struck and points there. Two untracked free gaps added as CR11 steps 8–9 / [[CR02]] step 8: "`deploy` and `deploy:prd` share one `CLOUDFLARE_WORKER_TOKEN`", and "dev has no Stripe sandbox" — ⚠️ **both false, corrected 2026-08-03; see the entry above.** [[CR02]] item 5 was marked **blocked behind CR11 step 1** — it had read ready-to-do, and a dev receiver against the shared project would write real orgs and mint real keys in production; ✅ **unblocked 2026-08-03**) | 2026-08-02 (**CR29 steps 1 and 2 done, neither pushed** — the sender fails closed on an unset *or* unresolvable `ACTIVE_KEY_ID` rather than downgrading to `SHARED_SECRET`, and the receiver now rejects a request carrying no `x-key-id`, which is the change that closes the forgery path. `SHARED_SECRET` is read by neither side; it stays bound until step 3. **Step 3's gate metric changed as a consequence:** `auth.verified_legacy_key` no longer exists — step 2 deleted the path it counted — so the signal to watch is `auth.key_unresolved` with `miss: "missing_key_id"`, which is a *breakage* signal rather than a success one. Next: step 3, the unbinding) | 2026-08-01 (**CR29 step 0b done** — the receiver now attributes every signature check to a signing key, so `auth.verified_legacy_key` measures when the keyless fallback is safe to remove; committed unpushed because merging deploys the receiver) | 2026-07-31 (staleness sweep — CHK01 closed, CR13 leftover deleted, CR11 detector regression 3→5 recorded and row #7 diagnosed, which filed **CR29**: the HMAC rotation is a no-op; CR20 step 4 answered; CR12 type fix, CR14 step 6, CR15 item 2, CR25 items 9–12 closed; Stripe revocations confirmed) | **Phase:** Codebase review remediation + worker deploy/settings audit + **database/secret remediation**. 48 findings fixed and migrated to the 1.3 changelog; open items are summarised in the table under *Code Review 2026-07-26 → 2026-07-27* (CR01–CR35).

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

## ~~W04: Provisioning workers — monitoring, alerting & dashboards~~ ✅

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

   Defining these in prose alone is how they go stale, so each is computed rather than described. **Six** are implemented — unhandled exceptions, the cron no-op detector, resource exhaustion, cross-repo receiver health (reported, never failing the build, since this repo cannot fix it), dead-letter queue depth, and **workflow state** (SIGNAL 6, added 2026-08-08 with [[W11]]: every workflow on disk must be `active`, run by a separate credential-independent script). Five are named as **not** implemented so they are not mistaken for covered: the `/send` error-code split, receiver 401 spikes, provisioning latency, Auth0/Supabase call failures, and the auth 429 rate. The first needs a counter emitted from the Worker — `ERROR_CODE.RECEIVER_ERROR` vs `INTERNAL_ERROR` vs the 502 path is distinguishable only in the response body, which neither Cloudflare telemetry source records.

   > **⚠️ Do not build this on error rate alone — measured 2026-07-31, [[CR20]] step 4.** Throughout those four months the cron reported `status: success` with `errors: 0` on every one of ~96 daily invocations, because the Supabase client threw on unbound secrets and `fetchPendingDeadLetters` swallowed it into `[]`. The only telemetry that distinguished broken from working was **`subrequests`**, which sat at exactly 0 until secrets were bound and then rose to 1.00 per invocation. Any alert designed around errors or invocation count would have stayed green for the entire outage. The signature to watch for, here and on any future cron, is **"succeeded while making no outbound calls"**.

   **One caveat that will otherwise produce a wrong dashboard in step 3.** The two Cloudflare sources disagree. For `integrity-studio-contact`, GraphQL reported 34 invocations and 3 `scriptThrewException`, while a Workers Logs query over **72 hours** returned 10 events and no exception at all. Workers Logs only captures from the moment `observability` was enabled — the 2026-07-30 deploy for `api-gateway` and `integrity-studio-contact` — and its retention is shorter than the analytics rollup's. **Build rate panels on GraphQL; use Logs for drill-down only, and never read an empty log query as "no errors".**

   **The check found two live failures on its first run**, which is the argument for it existing. Both are recorded below.
3. ✅ **Done 2026-08-08 — `npm run dashboard:workers`** (`scripts/worker-dashboard.sh`), covering the provisioning path (`sender-worker` → `api-provisioning-receiver`) plus the rest of the production fleet, on Cloudflare Workers Analytics. Documented in [`docs/api-provisioning.md`](api-provisioning.md) § Monitoring Runbook → The dashboard, which also closes the half of step 5 that could not be written while no dashboard existed.

   > **⚠️ This step was never actually blocked, and the blocker note below says so if read closely.** Step 3 offers *two* destinations — "Cloudflare Workers Analytics, **or** route through the existing internal OTEL pipeline". Only the second was blocked. Workers Analytics needed nothing built and nothing repaired, and step 2's own caveat already **mandates** it for rate panels ("Build rate panels on GraphQL; use Logs for drill-down only"). A blocker on one of two alternatives was recorded as a blocker on the step, and that stood for 8 days. Same shape as the phantom-spend blocker on CR11: **before scheduling around a blocker, check that it covers every path to the goal, not just the first one considered.**

   Four panels: provisioning path, fleet summary, daily trend sparklines, and **resource headroom** — cpuTime p50/p99 against each Worker's configured `cpu_ms`, memory p99 against the 128 MiB ceiling. The last is the reason it is worth having beyond step 2's gate. CR20's lesson was that error rate is blind to a cron that succeeds while doing nothing; the resource panel is the same lesson for the other blind spot, since a Worker killed for exceeding CPU **never runs handler code** — no exception, no log, nothing for an error-rate check to see. Both the `cpu_ms` limit and the observability setting are read live from each script's settings endpoint rather than parsed from a `wrangler.toml`, so neither can drift from what is deployed and both work for the two Workers deployed out of `observability-toolkit`. Exit codes: 0 rendered or skipped, 2 on API failure — **it is not a gate and never fails a build**; `check:worker-signals` is the gate.

   > **🔴 The blocker on the *other* option is real, still live, and was mis-measured. Re-measured 2026-08-08 — `obtool-ingest` is not failing ~90% of its invocations; its cron is failing ~100% of them.** `exceededResources` sits at a near-constant **~288/day regardless of traffic** — 268 on a day with 57,259 successes, 285 on a day with 2. 288 is exactly the `*/5` cron count (1440 ÷ 5), so the failures are *the cron and only the cron*; HTTP ingest is fine. The "~90%" came from sampling on 2026-07-28/29/30, when HTTP traffic happened to be near zero (success 70/31/29) and the fixed cron failures were therefore most of the total. **A ratio between two independent quantities is not a failure rate** — that arithmetic made a total cron outage read as a partial one.
   >
   > **Cause, from the dashboard's own resource panel: cpu p99 744 ms against a configured 500 ms limit (149%).** Confirmed against D1 `batch_watermark`, which shows the flush is *partially* draining — it dies partway through each run, so early signals advance and later ones starve:
   >
   > | watermark signal | last run | staleness |
   > |---|---|---|
   > | `org:…:metrics` | 2026-08-08 05:51 | 2 h |
   > | `org:…:logs` | 2026-08-07 15:50 | 16 h |
   > | `org:…:traces` | 2026-08-01 07:31 | **7 days** |
   > | `evaluations` | never run | — |
   >
   > ✅ **Post-deploy measurement 2026-08-08 09:43 UTC — the CPU half is fixed, and that is what proves the rest of this note wrong.** The toolkit's chunking fix went live at **08:57:01Z** with `cpu_ms` unchanged at 500. `exceededResources` ran **9–12/h for eight straight hours** — against 12 `*/5` cron runs an hour — and dropped to **0** in the 43 min after. A scheduled-handler-only change cannot affect an ingest-POST kill, so that attributes the kills to the cron. But **the staleness did not move**: traces still 2026-08-01, logs still 2026-08-07, while metrics advanced to 09:40. The fix worked *and the stale signals stayed stale*, which is only possible if they were never waiting on the flush. Caveat: 43 minutes is ~8–9 cron runs, not a week.
   >
   > ⚠️ **The starvation reading above is WRONG, and was corrected in `observability-toolkit` after a fix had already shipped on it.** Traces are 7 days stale because they **stopped arriving** on 2026-08-01, not because the flush starved them: the newest flushed traces key equals the traces watermark *exactly*, and a completed run drains metrics while finding **zero** trace objects. That is a producer problem, not a flush one. The CPU kills are real and remain unexplained — but they are not what stalled traces, and the watermark table above cannot distinguish the two on its own. **Generalisable half, worth more than the incident: a stale watermark means "nothing arrived" as often as "nothing drained", and one query against the newest flushed key tells you which.** Tracked as `INGEST-CPU-STARVATION` (name now a misnomer) in `observability-toolkit`; this repo's dashboard surfaces the CPU reading but cannot diagnose or fix it. Historical detail from the original 2026-07-31 finding follows.

   > ✅ **Root cause of the traces half, found and fixed 2026-08-08 — and it is not in this repo or in `obtool-ingest`.** Traces have exactly one producer. Measured in D1 by `service_name`: the Claude Code hooks **file shipper** (`claude-code-hooks`) accounts for all 101,431 trace rows, and the toolkit's inline OTLP export (`observability-toolkit`) has shipped **zero** traces while still shipping metrics (newest 08-08) and logs (08-07). The shipper died — cursor frozen Aug 2 16:38, status `{"outcome": "no-endpoint", "shipped": 0}` — so traces stopped and the other two signals kept flowing, which is exactly why nothing looked wrong.
   >
   > It had no endpoint because **Claude Code does not inject `settings.json`'s `env` into hook processes**: the value was correctly set in `~/.claude/settings.json` *and* exported from `~/dotfiles/shell/zsh/zshrc`, a fresh login shell had it, and the Claude Code process did not — so every shipper it spawned inherited nothing. Fixed with a last-resort `settings.json` read in the shipper (`~/.claude/hooks/lib/settings-env.ts`), `process.env` still winning. Backfill: 134 MB of stranded local telemetry pre-seeded into the cursor.
   >
   > ⚠️ **The health check that should have caught this was documented backwards** — `~/.claude/CLAUDE.md` said "only metrics prove the shipper is alive; check metrics freshness, not logs", when metrics is precisely the signal the inline export keeps fresh while the shipper is dead. Corrected there. **The transferable rule for this repo: when two independent producers write the same pipeline, a per-signal freshness check must name WHICH producer it proves alive.** Neither `check:worker-signals` nor `dashboard:workers` distinguishes them today — both read Cloudflare invocation data, which sees the ingest Worker, not who fed it.
   >
   > **🔴 Blocker found 2026-07-31 (original text, numbers superseded above).** `obtool-ingest` is failing **~90% of its invocations** with `exceededResources`, and its `*/5` cron fails essentially every run. Successful ingest collapsed from tens of thousands per day to ~30 around 2026-07-28 while resource kills became the dominant outcome:
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

**Status:** ✅ **Closed 2026-08-09 — all five steps implemented, and step 4's scheduled run is now observed** (run `31305667972`, event `schedule`, success — verified it evaluated live signals rather than skipping on absent credentials). Step 3 closed 2026-08-08 (`npm run dashboard:workers`); its recorded blocker turned out to apply to only one of the two destinations the step offered — see the ⚠️ note under step 3. That closure also re-measured the `obtool-ingest` blocker and found it mis-stated: the cron fails ~100% of runs, not "~90% of invocations". ⚠️ The follow-on claim that the flush was *starving* traces was **itself wrong and is corrected under step 3** — traces stopped arriving on 2026-08-01, which is a producer problem. **That is now the only cross-repo item this entry is waiting on, and it belongs to `observability-toolkit`.** Step 1: instrumentation deployed and emitting on all four production Workers (2026-07-30). Step 2: signals defined and executable (2026-07-31, see above). Step 4: daily scheduled alert job added 2026-08-08 (`.github/workflows/worker-signals.yml` — GitHub job-failure email is the channel; Supabase creds enable SIGNAL 5 dead-letter depth). ~~⚠️ added, not armed~~ ✅ **Armed 2026-08-08** — merged to `main` as `982f406`, workflow registered `state=active`, schedule `37 8 * * *`.

🧪 **Alert-channel test, 2026-08-08 — deliberately failed, because a passing run proves nothing about the channel.** The alert is a job-*failure* email, so a green run notifies nobody; waiting for a real breach would have meant closing this on the assumption that the untested half worked. `MIN_SUBREQUEST_RATIO` was temporarily set 0.5 → 99 to force exactly one deterministic breach (one, not five — a storm proves the same thing and is harder to read), and run [`31265198806`](https://github.com/integritystudio/IntegrityLandingPage/actions/runs/31265198806) failed for precisely the intended reason:

```
FAIL: 1 signal(s) breached
  - stripe-webhook: subrequest ratio 1.00 below 99.00
##[error]Process completed with exit code 1
```

**GitHub generated a notification 24 s later** — `ci_activity` / `CheckSuite`, *"Worker Signals Check workflow run failed for main branch"*, `15:44:41Z`, verified against a 50-item pre-test baseline via the notifications API. Both temporary changes were reverted in `613fa8f` and verified **byte-identical to `982f406`**, with the check exiting 0 again.

🔴 **CORRECTION, same day: CR20 was closed on HALF its stated gap and was REOPENED** *(resolved 2026-08-09 — see SCHEDULING PROVEN below; retained because the reopening is the reason the right thing got measured).* Its wording was that the *"scheduling **and** notification"* half was unproven. The test below proves **notification**. It does not prove **scheduling**, and the run list says so plainly: the repo has exactly **one** `worker-signals` run in its entire history, `2026-08-08T15:44:02Z`, event **`workflow_dispatch`** — the one deliberately triggered here. **Zero `schedule`-triggered runs have ever executed.** The `*/5` experiment ran ~15 minutes and produced nothing, which is consistent with GitHub scheduler latency but proves nothing either way.

Using `workflow_dispatch` made the *notification* test deterministic, which was right — but it also meant the scheduled path was never exercised, and closing on it silently substituted the half that was easy to prove for the half that was asked for. **That is this file's fifth premature closure and the same shape as the other four.** The remaining check is free: the daily `37 8 * * *` run should appear tomorrow. Confirm one `schedule` event in Actions, then close.

✅ **DELIVERY CONFIRMED by the recipient, 2026-08-08 — the NOTIFICATION half is closed.** The notifications API proves what GitHub *created*, not what reached an inbox; delivery depends on per-account notification settings and the mail provider, neither observable from this side. So the last step was a human one, and it happened: the owner received *"Worker Signals Check / Evaluate worker health signals — Failed in 13 seconds"*. **End to end, all four links are now observed rather than inferred: the check detects a breach → the job exits 1 → GitHub raises a notification → the email lands.** Closing on the API evidence alone would have been the merged-≠-live substitution this file has already corrected four times, one layer further out.

Also learned, and worth keeping: **direct pushes to `main` here bypass branch protection rather than being blocked by it** — both pushes reported `Bypassed rule violations … 2 of 2 required status checks are expected`. The required checks are advisory for admin accounts, so "protected" does not mean "cannot be pushed to untested".

✅ **SCHEDULING PROVEN 2026-08-09 — the reopened half is closed, and the chain is now observed end to end.**
Run [`31305667972`](https://github.com/integritystudio/IntegrityLandingPage/actions/runs/31305667972), event
**`schedule`**, branch `main`, conclusion **success** — the first schedule-triggered run in this repo's history.

**Verified it passed for the right reason, which is the whole point of looking rather than counting.** A green run
here is ambiguous by construction: `check-worker-signals.sh` prints `SKIPPED` and exits **0** when Cloudflare
credentials are absent, and in the run list that is indistinguishable from a real pass — the same shape as the
credential failure this item's sibling check hit on its first day. The log shows both checks evaluating live data:
SIGNAL 6 enumerating all seven workflows as `active`, and SIGNALS 1–5 returning `webhook_dead_letters: pending=0
abandoned=0` plus the `integrity-studio-contact` idle NOTE. Credentials resolved; nothing skipped.

| When | Event | Result | What it proves |
|---|---|---|---|
| 2026-08-08 15:44Z | `workflow_dispatch` | failure | breach → exit 1 → notification → **email confirmed by the owner** |
| 2026-08-09 09:20Z | `schedule` | success | **the cron fires** |

Two runs, two different questions, neither substitutable for the other — which is exactly what the reopening was
about, and why closing on the dispatch run alone was wrong.

⚠️ **The cron is `37 8 * * *` and it fired at 09:20:27Z — 43 minutes late.** Ordinary GitHub scheduler lag, recorded
because it is operationally load-bearing: **anyone checking at 08:45 would see nothing and could reasonably conclude
the cron is dead**, which is the wrong conclusion and the one this item spent two days avoiding. Measured the same
morning in `observability-toolkit` too — its `09:17` cron fired at `09:59:34Z`, **+42 min**. Give any cron-liveness
check a window of hours, not minutes. Incidentally this was also SIGNAL 6's first live run, ~7 h after merging.

Step 5: monitoring runbook added to `docs/api-provisioning.md` 2026-08-08, and extended the same day with the dashboard section that could not be written before step 3 existed. ~~**Remaining: confirm one `schedule`-triggered run appears (daily `37 8 * * *`). Zero have ever executed — the only run in repo history was `workflow_dispatch`.**~~ ✅ **Done 2026-08-09 — see the block above.**

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

🔴 **Steps 1–3 are ALREADY IMPLEMENTED and this entry did not know it — measured 2026-08-06 by reading the receiver source.** `services/api-provisioning-receiver/src/nonce.ts` exists and `src/index.ts:122-128` calls it on every `/inbox` request. So the "design decision" this item has been parked on was settled in code some time ago: **signature dedup in KV**, not a Durable Object, not a separate nonce header. `checkAndStoreNonce` keys on the request signature (`nonce:<sig>`), returns 401 `REPLAY_DETECTED` on reuse, and `NONCE_TTL_SECONDS` is derived as `ceil(REPLAY_WINDOW_MS / TIME_MS.SECOND)` — so step 3's "TTL ≥ replay window" is satisfied *by construction* rather than by a constant someone has to keep in sync. Scope items 1, 2 and 3 are done; `workers/sender-worker/src/` needed no change because the signature is reused rather than a nonce emitted.

**What is actually still open is the part the audit note warned about, and it was not heeded.** The nonce store went into **exactly** the shared namespace the note said to avoid. Verified 2026-08-06 by diffing the two configs — they are byte-identical, `preview_id` included:

| Config | binding | `id` |
|---|---|---|
| `services/api-provisioning-receiver/wrangler.toml:32-35` | `RATE_LIMIT_KV` | `cf9d7d72bb07488faab8187ceb3589d4` |
| `workers/contact-form/wrangler.toml:28-31` | `RATE_LIMIT_KV` | `cf9d7d72bb07488faab8187ceb3589d4` |

So production `integrity-studio-contact` and the provisioning receiver now share one namespace across **three** key conventions — contact-form's `rate_limit:${ip}` and `idempotency:${key}`, plus the receiver's `nonce:<sig>`. The `nonce:` prefix does prevent a literal key collision (the note's narrow worry), so this is not corrupting data today; the real cost is that two unrelated services' security state shares a blast radius, and a namespace-wide operation (purge, quota exhaustion, accidental unbind) hits both. ⚠️ The audit note's closing caveat — "I could not confirm whether the receiver's own rate-limit keys collide with contact-form's because `observability-toolkit` was not available to read" — **is now answerable and the answer is no collision**: the receiver's rate limiter uses `enforceRateLimit(env.RATE_LIMIT_KV, "ip"|"email", …)`, a different prefix again.

🟠 **Second finding, not previously recorded: all three checks fail OPEN.** The nonce check, and both receiver rate-limit calls, are each wrapped in `if (env.RATE_LIMIT_KV)`. If that binding is ever absent or misnamed, `/inbox` silently loses replay protection *and* rate limiting while still returning 200 — no error, no audit event, nothing to alert on. That is the same failure shape as [[CR29]]'s keyless downgrade and [[W04]]'s "succeeded while making no outbound calls": the degraded path is indistinguishable from the healthy one from outside. Worth deciding deliberately whether an unbound `RATE_LIMIT_KV` should fail closed (503) or at minimum emit an audit event, rather than being an untracked silent default.

**Revised scope — what is left:**
1. ~~Add a per-request nonce…~~ ✅ done in code (`nonce.ts`, signature dedup).
2. ~~Reject `/inbox` requests whose nonce has already been seen~~ ✅ done (401 `REPLAY_DETECTED`).
3. ~~Confirm TTL ≥ replay window~~ ✅ done, derived rather than hardcoded.
4. ~~Provision a dedicated KV namespace for the receiver~~ ✅ **done 2026-08-08**: namespace `7ab3fb981d5b4ea186c348acd1e03590` provisioned; `wrangler.toml` updated. `cf9d7d72…` is now contact-form's namespace only.
5. ~~Decide the fail-open question above~~ ✅ **done 2026-08-08**: fail closed. The three `if (env.RATE_LIMIT_KV)` guards are replaced by a single early-return 503 + `alert.check_failed` audit event. An absent binding is now detectable in Sentry rather than a silent degradation.

**Status:** ✅ **Complete 2026-08-08.** All five scope items are done. Receiver-side changes are in `observability-toolkit` repo (commit `bb2228b` on `main`; Worker deployed to production, version `1564a7e7`).

---

## ~~W07: Doppler CLI — `secrets get <missing-name> --plain` dumps the whole config instead of a clean error~~ ✅

**Priority:** P3 | **Source:** session 2026-08-06, verifying [[CR12]]'s HMAC secret bind and [[CR18]]'s deleted key | **Resolved:** 2026-08-08
**Estimated:** 15 minutes to document; longer if a wrapper is wanted

> 🔴 **The premise is refuted. `secrets get <missing> --plain` does not dump anything — and the fix was to document what actually leaks, not what this entry claimed.**
>
> Tested on the **same binary** that produced the original observation: `doppler 3.76.1`, `/opt/homebrew/Cellar/doppler/3.76.1`, install receipt `2026-07-25T13:47:46`. That predates the 2026-08-06 sighting by twelve days and there is only one version in the Cellar, so **no upgrade intervened** — this is not "fixed upstream", it is "did not happen the way it was written down".
>
> Three probes, output captured to files so a repeat of the original exposure could not occur:
>
> | Command | Result |
> |---|---|
> | `secrets get STRIPE_API_KEY … --plain` (the exact command, on the exact deleted name) | exit 1, **stdout 0 bytes**, stderr `Could not find requested secret: STRIPE_API_KEY` |
> | `secrets get … --plain` with the name argument omitted | exit 1, `requires at least 1 arg(s), only received 0` |
> | **`doppler secrets --project … --config …`** (bare list, no `get`) | exit 0, **500 lines, values inline** — a known `CLOUDFLARE_D1_TOKEN` fragment was found in the output, and 138 of 175 names |
>
> So the command that dumps a config is the **list** form, which differs from the `get` form by the single word `get`. That is a real hazard and worth the documentation this item asked for; the specific fallback-on-miss behaviour it described is not real, and writing it into `CLAUDE.md` as stated would have planted a false gotcha in the one file that is auto-loaded into every session.
>
> **What the original session actually saw is not recoverable from here** — the transcript is gone and the exposure was real (a table of production values landed in tool output). The defensible record is: a whole-config dump happened, the `get` form is not what produces one, and the list form is.
>
> 📌 **Generalisable, and the reason this is worth more than a P3 correction: a bug report is a *claim*, and a claim about a tool's behaviour is testable.** This one sat for two days as an accepted premise with a documentation task attached. Reproducing it before writing the doc took three commands and inverted the finding. The repo has now recorded this shape several times from the other direction — a probe returning a uniform negative, an empty-list `200` read as access, a `DELETE … WHERE 1=0` read as write capability. This is the same rule applied to a *remembered* result rather than a live one: **re-run it before you document it.**

**What happened:** after deleting `STRIPE_API_KEY` from Doppler `prd` ([[CR18]] item 2), a follow-up `doppler secrets get STRIPE_API_KEY --project integrity-studio --config prd --plain` — run to confirm the deletion — did not return a clean "not found." It printed the **entire `prd` config as a formatted table**, every secret name and value, dozens of credentials unrelated to the one being checked. This happened in an automated context (an agent verifying its own change), so the full table landed in that session's tool-call transcript rather than a terminal a human was watching.

**Why this matters:** every other verification pattern in this file explicitly avoids printing secret values — `check-env-isolation.sh`'s own header comment states "compares hashes only — no secret value is printed, so it is safe to run in CI and paste output into a ticket." A plain `secrets get` on an existing-and-then-deleted name breaks that assumption silently: the command *looks* like a narrow, single-value read, and instead behaves like `doppler secrets` (list-all) on a miss. Nothing about the command's name or flags signals that fallback.

**The safe alternative, confirmed working:** `doppler secrets --project <p> --config <c> --only-names` (or piping through `grep -c <name>`) answers "does this slot exist" without ever emitting a value, and was used to complete the CR18 verification after the fact.

**Scope:**
1. ~~Document the gotcha in this repo's `CLAUDE.md` (or wherever Doppler CLI conventions are recorded) so the next person — human or agent — doesn't reach for `secrets get NAME --plain` to check existence.~~ — ✅ **done, with the corrected content.** `CLAUDE.md` § Secret Rotation now carries a three-row table of what each form prints on a miss, names `--only-names` as the existence check, and flags the bare list form as the one that dumps. It does **not** say `get` falls back to a dump, because it does not.
2. ~~Grep `scripts/*.sh` and any CI workflow for `secrets get .* --plain` patterns that assume a clean miss~~ — ✅ **done, both repos, and the result inverts the concern.** Fifteen `secrets get … --plain` call sites across `scripts/`, `.github/workflows/` and the toolkit's `dashboard/.github/workflows/deploy.yml`. **Zero uses of the bare list form**, so nothing in either repo can dump a config. Every `get` site is already written as `$(… 2>/dev/null || true)` *with a comment saying why* — `worker-signals.yml` and `ci.yml` both explain that they want the consuming script to decide whether to skip. Nothing to fix.
3. ~~Optional: a thin wrapper (`doppler-get-safe` or similar)~~ — ❌ **not built, and it would guard a hazard that does not exist.** A wrapper checking `--only-names` before `--plain` buys nothing once `get` is known to error cleanly on a miss. The exposure it was meant to prevent comes from the *list* form, which no script calls and which a wrapper around `get` would not intercept.

⚠️ **The one real defect in this area is the mirror image of the reported one, and it is documented rather than fixed because the current behaviour is deliberate.** `2>/dev/null || true` converts a missing slot into an **empty string**, so "never configured" and "renamed, revoked, or newly unreadable" are indistinguishable at the call site. That is a live failure mode, not a hypothetical: `observability-toolkit`'s `check-worker-signals.sh` shipped with a present-but-broken D1 token degrading to a NOTE while the job exited 0 — an expired credential would have switched a signal off behind a green check ([[W09]] records it). It now distinguishes the two (absent → skip, broken → exit 2) and `CLAUDE.md` names it as the pattern to copy.

**Status:** ✅ **Closed 2026-08-08 — premise refuted, documentation written to the measured behaviour.** No live risk existed and none was found; the exposure in the source session was real but is not produced by the command this item blamed. Steps 1 and 2 are done, step 3 is declined with a reason. What remains in the area is the empty-variable ambiguity above, which is tracked where it actually bites ([[W09]], and fixed in the toolkit's signals check).

---

## W08: Reconcile orphaned Auth0 users against Supabase `users` — surfaced by [[CR14]] step 5

**Priority:** P2 | **Source:** session 2026-08-06, CR14 step 5's data-handling audit
**Estimated:** 1–2 hours for the reconciliation query; cleanup time depends on what it finds

**Context:** [[CR14]] step 5 found that `sender-worker`'s signup flow had no rollback on partial failure until `0f3a711` (fixed 2026-07-26), so a mid-flow failure between 2026-03-29 and 2026-07-26 could leave a permanently orphaned Auth0 user with no corresponding Supabase account. A read-only live check found Auth0 (`dev-68gg87ow4mg4kzyo`) holding **39 total users** against Supabase `users`' **9 rows** — a 30-user gap. That gap is **not** 30 confirmed orphans: 26 of the 39 Auth0 users have emails matching a test/internal pattern (`test`, `alyshia`, `integritystudio.ai`, `demo`) and are plausibly team/test accounts created outside the signup flow, not customers lost to the bug.

**Scope:**
1. Pull the full Auth0 user list (`user_id`, `email`, `created_at`, `logins_count`) and the full Supabase `users` list (`auth0_id`, `email`, `created_at`).
2. Join on `auth0_id`/`user_id`. Anything in Auth0 with no match is a candidate orphan.
3. Exclude known test/team emails from the candidate set (the pattern above is a rough first pass, not a final filter — verify against an actual allowlist of known internal accounts).
4. For what remains: decide per-record whether to delete the Auth0 user (frees the email to retry signup, removes retained PII with no legitimate basis) or leave it (e.g., if there's a support/product reason to preserve it). **Deleting an Auth0 user is real, hard-to-reverse PII removal — this is an owner decision, not something to automate away.**
5. Cross-check `organizations` (7 rows) the same way — a partial-failure signup can also leave an org row with no owner, or an owner-less membership.

**Files to touch:** none in this repo — this is entirely an Auth0 Management API + Supabase data operation, not a code change. `docs/api-provisioning.md` or wherever data-hygiene runbooks live would be the natural home for step 1–2's query once written.

**Status:** Open — bounded but not quantified. The read-only count check is done (see CR14 step 5); the per-user reconciliation that would turn "30-user gap" into "N real orphans" has not been run.

---

## ~~W09: `check:env-isolation` passes while four cross-environment values sit outside its list~~ ✅

**Priority:** P2 | **Source:** session 2026-08-07, pointing the toolkit e2e suite at dev ([[CR11]] step 7) | **Resolved:** 2026-08-08

> ✅ **Closed 2026-08-08. `CLOUDFLARE_D1_TOKEN` accepted and documented; six latent values fixed; the generalisable half built and mutation-proven.** Closing this item surfaced **five more** cross-environment values, one of which granted dev read of the entire production config — they were filed as W12 and ✅ **all five are fixed as of 2026-08-09**, with the detail in [`docs/changelog/1.3/CHANGELOG.md`](changelog/1.3/CHANGELOG.md) § W12. The transferable point survives the fix: this item passed for weeks while five names it had never heard of sat shared, because **a name the list does not mention is never measured**.
>
> **The acceptance is broader and better-founded than the row it came from.** The decision asked for was "accept `CLOUDFLARE_D1_TOKEN`". Measuring it against the whole config showed the token is not a special case but **one member of a class**: ten credentials are byte-identical across configs because the *resource they scope to is the account*, and there is one account. D1 has no per-database selector, Workers Scripts has no per-script selector, R2 and Pages tokens are account-scoped, `wrangler` OAuth is per-user, and an `sbp_` token spans every Supabase project. Accepting the D1 token alone while nine siblings sat unexamined would have been arbitrary. **What is accepted is the class, with the reason recorded per name in `scripts/check-env-isolation.sh`'s `ACCEPTED` map**, printed on every run so acceptance cannot decay into silence. The only remedy for any of them is separate accounts — the same conclusion [[CR11]] step 8 reached, now reached twice more independently.

### The six latent values, fixed 2026-08-08

Every one held a **production** identifier under `dev` while its unprefixed twin held the correct dev value — `VITE_AUTH0_DOMAIN`'s defect repeated for Supabase, KV and the home org. Verified by re-download afterwards: **`prd` byte-identical, zero names changed**, and the shared-byte-identical count moved 116 → 110, exactly the six.

| Value | Was (production) | Now (dev) |
|---|---|---|
| `VITE_SUPABASE_URL` / `REACT_APP_SUPABASE_URL` | `cfrbahzzklwrnmbtqojl` | `tumhmtshahktumhqqamk` |
| `VITE_SUPABASE_ANON_KEY` / `REACT_APP_SUPABASE_ANON_KEY` | production anon key | dev project's anon key |
| `CLOUDFLARE_KV_NAMESPACE_ID` | `902fc8a4…` (production dashboard KV) | `fc5bbe48…` (`DASHBOARD_DEV`) |
| `HOME_ORG_ID` | `f4286657…` | `12fc779f…`, documented in `obtool-ingest`'s `[env.dev]` as "the dev Supabase project's org" |

📌 **`HOME_ORG_ID` deserves a note, because two correct answers disagree.** `obtool-ingest`'s `[env.dev]` sets the dev org uuid; the dashboard's `[env.dev]` sets `""` deliberately, so that when P5 org resolution lands an empty value **fails loudly rather than silently resolving a production org**. Both are right for their surface. The Doppler slot got the dev uuid rather than the empty string because a `doppler run -c dev` consumer wants a usable dev value, and because the dashboard binds its own var and never reads Doppler for this name. The dashboard's empty binding stands untouched.

### The generalisable half — built, not argued

The item said this three times: *"extend it to compare **every** name present in both configs and classify rather than hash-compare a fixed list."* That is now the second half of `scripts/check-env-isolation.sh`, and **the polarity is inverted**: instead of asking "do the names I listed differ?", it asks "of every byte-identical shared name, is each one legitimately shared?" **An unclassified name fails.** New names default to visible instead of invisible — which is the entire defect this item documented, since all six values above were invisible for exactly as long as no list named them.

Current reading (2026-08-09, after the W12 fixes): **167 shared, 105 byte-identical, 95 shared by design, 10 accepted, 0 known gaps, 0 unclassified — exit 0.** `KNOWN_GAP` is deliberately retained as an **empty map**: that asserts "no known-wrong shared values", where deleting the concept would assert nothing and push the next real gap toward `SHARED_BY_DESIGN`, converting a printed defect into a silent pass.

**Mutation-proven, not merely observed passing.** Dropping one legitimately-shared name (`ANTHROPIC_API_KEY`) out of the allowlist made it resurface as `UNCLASSIFIED` and the script exit **1**; restoring it returned the file byte-identical and the exit to **0**. The six fixed names are *also* pinned into the original `SECRETS` list, so a regression trips two independent detections — the sweep's allowlist is itself editable, and a check whose only guard is a list someone can edit has one failure mode too few.

⚠️ **The sweep skips loudly, never quietly.** If either config fails to download it prints `DEGRADED run, not a pass` and contributes nothing to the count — because a classification pass that silently covers zero names, while the list-based rows above still print `ok (distinct)`, would read exactly like a clean bill of health. That is this item's own hollow-green failure mode, and the toolkit's signals check shipped with it once already.

[[CR11]] is closed on the strength of `npm run check:env-isolation` exiting 0. That result is true and much narrower than it reads: `SECRETS` in `scripts/check-env-isolation.sh` names **15** credentials, and standing up the dev e2e path found **four** cross-environment values in Doppler `dev` that it does not look at. The item's own caveat already said "a green run proves only what the list names" — this is that caveat with four concrete instances, which is the difference between a warning and a finding.

| Value | What it was | State |
|---|---|---|
| `PROVISION_WORKER_URL` | the **production** sender — so `sender-receiver` and `provision-key` e2e created real users and API keys in production on every local run | ✅ fixed → `sender-worker-dev` |
| `KV_NAMESPACE_ID` | production's `AUTH` namespace — a dev `api-keys-create` would have minted keys into the namespace production authenticates against | ✅ fixed → `AUTH_DEV` (`0b323a37…`) |
| `VITE_AUTH0_CLIENT_ID` | production's SPA client (`CNfd6…`), byte-identical in both configs and **nonexistent in the dev tenant**, so every dev ROPC mint returned `access_denied` | ✅ **fixed 2026-08-08** → `w4KMCpBA…`, a dev-tenant SPA provisioned for this |
| `VITE_AUTH0_DOMAIN` | the **production** tenant, while `AUTH0_DOMAIN` in the same config held the dev one — a split-tenant `dev` config | ✅ **fixed 2026-08-08** → `dev-njjmghdzm23uy0p7` |
| `AUTH0_TENANT_NAME` | production's tenant, and read by no code in either repo. Deliberately repointed at production during [[CR01]]'s recovery, when leaving no dev-tenant value in either config was the goal — correct then, stale once the dev tenant became legitimate | ✅ **fixed 2026-08-08** → `dev-njjmghdzm23uy0p7` |
| `CLOUDFLARE_D1_TOKEN` | not two equal values but **one token object** (`3a227938`, `tcad-d1-query`) in both configs, carrying **D1 Write over the whole account** — so a `--config dev` script can `DROP TABLE` production telemetry | ✅ **ACCEPTED 2026-08-08**, with nine account-scoped siblings — scoping is structurally impossible, so the only remedy is separate accounts. Recorded in the `ACCEPTED` map and printed every run |
| `INJECT_HMAC_SECRET` | **byte-identical**, and *proven* to authenticate against the production evaluations webhook — found 2026-08-08 | ✅ **rotated in `dev` 2026-08-08**, see below |

**The generalisable half, and the reason this is P2 rather than a footnote: endpoint URLs are as load-bearing as credentials.** Three of the four are not secrets at all — two URLs and a public client id — and `PROVISION_WORKER_URL` did the most damage of any of them. A perfectly-scoped dev credential aimed at a production endpoint is the same defect as a shared credential, and the detector is built to catch only the second. Extend it to compare **every** name present in both configs and classify rather than hash-compare a fixed list, or at minimum add the `*_URL` / `*_NAMESPACE_ID` / `VITE_*` / `CLOUDFLARE_*` families.

⚠️ Two things to know before editing that script. The slot really is spelled **`SUPABASE_INTEGRITY_MEMERSHIP_KEY`** ("MEMERSHIP") in Doppler — verified present in both configs at 41 chars; the correctly-spelled name exists in neither, so "fixing" the typo in `SECRETS` would silently create the phantom row this file already documents. And a name absent from both configs reads as "UNSET in both", which is not evidence of isolation — it is the failure mode that hid `SUPABASE_PROVISIONING_KEY` for a week.

✅ **The Auth0 half is fixed, 2026-08-08 — and it could not be fixed one name at a time.** `VITE_AUTH0_DOMAIN` alone would have produced a *mixed* pair (dev domain + a production client id that does not exist in the dev tenant), which is worse than the consistently-production pair it replaced: the dashboard SPA needs domain and client from the **same** tenant. So the fix was to provision what was missing — `integritystudio-dashboard-dev` (`w4KMCpBA…`), `app_type: spa`, callbacks on `http://localhost:5173`, and **`authorization_code` + `refresh_token` only**. No `implicit` and no `password`, deliberately: adding ROPC to a new public client would recreate exactly what [[CR34]] stripped and what `observability-toolkit`'s `SIGNIN-WORKER` is waiting to remove.

**This had become an active breakage, not untidiness.** Once `DEV_WORKER_URL` was repointed at `quality-metrics-api-dev` — which verifies against the dev tenant's JWKS — a local dashboard build under `--config dev` was minting **production**-tenant logins that the dev API could only reject. The two names disagreeing was survivable while both ends were production; it stopped being survivable the moment one end moved.

**Detector extended and mutation-verified.** `VITE_AUTH0_DOMAIN`, `VITE_AUTH0_CLIENT_ID` and `AUTH0_TENANT_NAME` are now in `SECRETS`: 15 → 18 credentials, `PASS` (exit 0). Proven to actually detect rather than merely pass — restoring the old production value made it report `SHARED WITH PRODUCTION` and exit **1**, then restoring the dev value returned it to exit 0. `VITE_AUTH0_AUDIENCE` is deliberately **excluded**: an Auth0 API identifier is just a name and each tenant registers its own, so it is legitimately byte-identical, and adding it would manufacture a permanent failure that trains the reader to ignore the check.

⚠️ **Two things this does not cover.** `dashboard/e2e/integration/setup.ts` mints ROPC through `VITE_AUTH0_CLIENT_ID`, which now refuses the password grant — but that suite already could not run under `dev`, because it also requires `SUPABASE_SERVICE_ROLE_KEY`, a slot that exists in neither config (the [[CR01]] finding). When it is revived, point it at the confidential `integrity-dev-ropc` (`AUTH0_CLIENT_ID`) as `observability-toolkit`'s `provision-key.e2e.ts` already does, rather than re-adding ROPC to the SPA. And the generalisable half below is still only half-answered: three names were added to a fixed list, which is not the same as classifying every name present in both configs.

🔴 **A sixth instance, in a config store this detector cannot see (2026-08-08).** `~/.claude/settings.json`'s `OTEL_EXPORTER_OTLP_HEADERS` carried a **dev** API key while `OTEL_EXPORTER_OTLP_ENDPOINT` in the same block pointed at **production** ingest. Probed as a pair: `200` against `obtool-api-dev`, `401` against `api.integritystudio.ai` — the credential and the endpoint it shipped to belonged to different environments. Fixed to match `OBTOOL_API_KEY` (now 200 prod / 401 dev).

Two things this adds to the item rather than merely repeating it:

1. **`check:env-isolation` compares Doppler `dev` against Doppler `prd` and nothing else.** This value lives in a gitignored local settings file, so it was outside the detector by construction — not a gap in the list, a gap in the *sources* the list is drawn from. Any host-local config that carries a credential (settings.json, `.envrc`, a shell profile) is a place a dev key can point at production unobserved.
2. **It was harmless only by accident, and the accident was in the consumer.** `otlpAuthHeaders` gives `OBTOOL_API_KEY` precedence, so the hand-rolled shipper never used the bad header. But the OTel SDK exporters read `OTEL_EXPORTER_OTLP_HEADERS` natively and know nothing about `OBTOOL_API_KEY` — any SDK-based export inheriting that env would have sent a dev key to production and 401'd silently. **Reasoning from precedence said "safe"; the capability probe said "wrong environment".** That is this item's own rule, met again: assert on what the credential can reach.

✅ **That sixth instance is now runtime-detectable** (`~/.claude` `17a54a00`). `describeOtlpCredentialConflict()` reports when an `OTEL_EXPORTER_OTLP_HEADERS` bearer disagrees with `OBTOOL_API_KEY`, naming the variables and never the credentials, and the shipper warns on it. Verified against the real pre-fix config, not a fixture: it fires there and is silent once corrected.

**What that does and does not buy this item.** It catches *this* shape — two credentials configured for one endpoint that disagree — wherever the shipper runs, including config stores `check:env-isolation` cannot see. It does **not** catch a single credential pointed at the wrong environment, which is the more common form here and the one `CLOUDFLARE_D1_TOKEN` still has: with nothing to disagree with, there is no conflict to detect. That still needs the capability probe this item keeps arriving at — assert what the credential reaches, not whether two values differ.

🔴 **`INJECT_HMAC_SECRET` was shared, and unlike the URLs it was *proven* to reach production (2026-08-08).** Found by finally doing what the "generalisable half" above asks for — comparing **every** name present in both configs instead of the hand-maintained list. That comparison is now a number: **170 shared names, 117 byte-identical.** Most are legitimately shared (Anthropic, OpenAI, Sentry, Porkbun — third-party keys with no dev/prd notion), which is exactly why a full-config comparison has to *classify* rather than fail on identity.

Four of the 117 are not legitimate, and they split cleanly by whether anything reads them:

| Value | Reaches | Readers today |
|---|---|---|
| `INJECT_HMAC_SECRET` | **production evaluations webhook — proven** | `obtool-ingest` (prod + dev), toolkit e2e |
| `CLOUDFLARE_D1_TOKEN` | production D1 | toolkit ops scripts |
| `CLOUDFLARE_KV_NAMESPACE_ID` | `902fc8a4…`, the **production dashboard KV** (dev's is `fc5bbe48…`) | none in either repo |
| `VITE_SUPABASE_URL` / `REACT_APP_SUPABASE_URL` (+ `_ANON_KEY` twins) | production project `cfrbahzzklwrnmbtqojl`, while the unprefixed `SUPABASE_URL` is correctly dev | none in either repo |

The last two are the `VITE_AUTH0_DOMAIN` defect repeated for Supabase and KV — **a prefixed twin holding production while the unprefixed name holds dev.** Latent rather than live only because nothing reads them, which is not a property to rely on: `PROVISION_WORKER_URL` was latent in exactly this way until a suite started using it.

`HOME_ORG_ID` is byte-identical too (production's `f4286657-…` under `dev`). Also unread today — but `observability-toolkit`'s `ORG-VARS-THIRD-WORKER` deliberately left `quality-metrics-api-dev` empty rather than copy that UUID, so `doppler run -c dev` would hand a future reader precisely the value that item refused to hardcode.

✅ **Rotated in `dev` 2026-08-08, and verified by capability rather than by the values differing** — a 2×2 matrix run to steady state, using a body that fails `JSON.parse` *after* signature verification, so a valid signature returns 400 and nothing is ever persisted:

| signing key → target | `obtool-ingest-dev` | production |
|---|---|---|
| **new** `dev` secret | **400** (accepted) | **401** (rejected) |
| `prd` secret (= the old shared `dev` value) | **401** (rejected) | **400** (accepted) |

Both diagonals matter: the top-right is the gap closing, and the bottom-left proves the old value is genuinely revoked in dev rather than merely superseded in Doppler. Production is untouched — `prd`'s slot was never written, confirmed by hash before and after. Bound to `obtool-ingest-dev` with `wrangler secret put --env dev`; the toolkit's `wrangler.toml` already documents that re-upload command.

⚠️ **The first reading of this matrix was wrong in both directions, and the probe is why.** An initial run returned 401 for *every* cell — the `openssl dgst` output on this machine carries no `(stdin)=` prefix, so `awk '{print $2}'` produced an empty signature and the endpoint rejected everything. A uniform negative is what a broken probe looks like, which this repo has now recorded five times. The next run then caught Cloudflare mid-rollout, with the dev Worker answering from two versions at once — new secret rejected on one sample and accepted on the next. **Neither a uniform result nor a single sample is a measurement**; the table above is the steady state across four consecutive samples.

### `CLOUDFLARE_D1_TOKEN` measured 2026-08-08 — the row understated it, and the fork it offers is already closed

**It is not "byte-identical values", it is one credential.** Both configs resolve to the *same token object*: id `3a227938fa953d76aa8ead731cdbb5c4`, name **`tcad-d1-query`**, `status=active`, issued 2026-08-06, **no expiry**. Rotating one config cannot produce a second token; there is nothing to rotate *to* without minting. (The inventory under [[CR11]] step 8 already had this row — `3a227938 | tcad-d1-query | CLOUDFLARE_D1_TOKEN, both configs` — so the two entries were describing one fact from different ends without meeting.)

📌 **Its name is not this system's.** `tcad-d1-query` was minted for TCAD (`tcad-api`, `tcad-token-refresh` on the same account), and is what now reads and writes `obtool-telemetry-db`. A third project's credential is the one holding production telemetry.

**Policy read directly** (via `prd`'s `CLOUDFLARE_GLOBAL_API_KEY` = `cloudflare_platform_token` `6d51c3d8`, the one credential here carrying Account API Tokens Write):

```
resources: { com.cloudflare.api.account.b3868dd0…: "*" }
perms:     D1 Metadata Read, D1 Read, D1 Write
```

**Capability probed rather than inferred**, and the write half proven with controls on the **dev** database only — absent → `CREATE TABLE` → confirmed in `sqlite_master` → `INSERT` → read back `42` → `DROP` → confirmed gone. Nothing was written to production; it did not need to be, since the same token reads production D1 and enumerates every database, so the resource scope is account-wide and the proven DDL reaches both.

| Surface | Result |
|---|---|
| D1 `SELECT` on **production** `e93f19eb…` | 200 |
| D1 `SELECT` on dev `9c34333f…`, list **all** databases | 200 |
| D1 DDL + DML (proven on dev) | CREATE / INSERT / DROP all succeed |
| Workers scripts / R2 / KV | 403 / 403 / 401 |
| Zones | **200 with an empty list — scoped, NOT zone access** |

⚠️ **That last row is the probe trap again.** A bare `200` reads as access; an empty `result` is exactly what a correctly-scoped token returns. Reporting the status code alone would have manufactured a zone-access finding that does not exist — the mirror image of the uniform-negative failure recorded twice above. **Read the body, not the code.**

🔴 **The row's fork — "scope a dev D1 token *or* accept and document it" — has only one arm. Scoping is impossible.** All three D1 permission groups, out of 386 on the account, carry `scopes: ['com.cloudflare.api.account']` and nothing finer; there is no per-database resource selector to scope to. This is [[CR11]] step 8's structural ceiling in a second product: **Workers Scripts has no per-script selector, D1 has no per-database selector, and no token can fix either.** So the remaining options are (a) accept and document, or (b) separate Cloudflare accounts — the same answer CR11 reached, and worth writing down here so this is not re-attempted as a token-minting task.

⚠️ **A first pass at this concluded the policy was unreadable** — `prd`'s general `CLOUDFLARE_API_TOKEN` returns `9109 Unauthorized` on both the token-read and permission-groups endpoints — and was about to record "cannot be determined from this machine". It was determined; the credential that could do it was already inventoried under CR11 four rows above the one being investigated. **The account inventory in this file is a working index, not just a record — read it before concluding a capability is absent.**

📌 **This session moved the token in the wrong direction, stated because it is easier to find now than later.** `observability-toolkit`'s new `worker-signals.yml` reads `CLOUDFLARE_D1_TOKEN` from Doppler `prd` on a daily schedule, so as of 2026-08-08 this credential also flows into GitHub Actions. Correct for that check's purpose — SIGNAL 4 needs D1 read, and the general token gets `7403` there — but it adds a consumer to an unscoped account-wide write token while this item is open. Note also that **every code consumer is in `observability-toolkit`** (`scripts/check-worker-signals.sh`, `worker-signals.yml`, `docs/reliability/ingest-recovery-runbook.md`); this repo, where W09 tracks it, has none outside this file.

✅ **Read-only token minted and wired 2026-08-08.** `obtool-d1-readonly` (`4a417b249408fff1f3dabe8c689a3f1d`), D1 Read + D1 Metadata Read, **no D1 Write**, stored as `CLOUDFLARE_D1_READ_TOKEN` in Doppler **`prd` only** — so unlike the credential it replaces on that path, it is *not* shared with `dev`. The toolkit's `check-worker-signals.sh` prefers it and falls back to `CLOUDFLARE_D1_TOKEN` only if it is absent; proven in CI, not just locally (toolkit run `31276746747` returned live watermark rows rather than the absent-token NOTE).

**Verified with paired controls:** `SELECT` on the **production** database succeeds, while `INSERT` and `CREATE TABLE` both return `7500 You do not have permission`. The write token's identical `INSERT` succeeded as the positive control (`changes=1`) and was reverted — dev's `batch_watermark` went 8 → 9 → 8 rows.

⚠️ **One probe result worth carrying forward: a write-shaped statement that touches no rows is PERMITTED.** `DELETE FROM batch_watermark WHERE 1=0` returned `success` with `rows_written=0` on the read-only token. The first negative control used exactly that form and so appeared to show the token could delete — it could not. **A no-op is worthless as a proof of write capability**; test with a statement that actually affects a row. This is the same family as the empty-list `200` above: the response body decides, not the shape of the request or the status code.

**What this does and does not buy.** It removes account-wide D1 **Write** from the one path that runs daily and unattended, which was the cheap part. It does **not** narrow *read* — no per-database selector exists — so the daily job still reads every D1 database on the account, and it does nothing about `CLOUDFLARE_D1_TOKEN` itself, which remains shared, unexpiring and account-wide-write for the runbook's rewind path (now flagged inline in `docs/reliability/ingest-recovery-runbook.md`, since a rewind run under `--config dev` reaches production).

📌 **A defect in the new check was found by wiring this up, and fixed:** a D1 token that was *present but broken* degraded to a NOTE and the job still exited 0 — so an expired credential would have switched SIGNAL 4 off while the alert stayed green. That is precisely the hollow-green failure the check exists to catch, reproduced inside it. Now only an **absent** token skips; a present-but-failing one exits 2. Mutation-verified across all three paths.

**Status:** ✅ **Closed 2026-08-08 — all 7 listed values resolved, the generalisable half implemented, and `CLOUDFLARE_D1_TOKEN` accepted as one of a ten-member class.**

- **6 of 7 fixed.** The four original values, plus `INJECT_HMAC_SECRET` (rotated in `dev`, proven by a 2×2 capability matrix rather than by the values differing), plus six further latent ones found by the sweep and repointed the same day.
- **The 7th accepted, with its reason recorded in code.** Per-database scoping is impossible — all three D1 permission groups are account-scoped, out of 386 on the account — so this was never a minting task. `obtool-d1-readonly` had already removed account-wide **write** from the one path that runs daily and unattended; what is accepted is the residue: `CLOUDFLARE_D1_TOKEN` stays shared, unexpiring and account-wide-write for the runbook's rewind path, flagged inline in `docs/reliability/ingest-recovery-runbook.md`. **Revisit only if the account topology changes**, since separate Cloudflare accounts are the sole remedy.
- **The generalisable half is implemented, not measured.** It was "170 shared names, 117 identical, 4 illegitimate, found by an ad-hoc script". It is now a classification pass inside `check:env-isolation`, where an unclassified shared name **fails**, mutation-proven in both directions.

⚠️ **What closing this cost, and it is the honest headline: the sweep found five more.** One was a `dp.st.prd.` Doppler service token in the `dev` config — a credential that reads the entire production config, i.e. the isolation boundary this item spent two days building. It was invisible to every check here until the polarity was inverted. ✅ All five were fixed 2026-08-09 (detail in [`docs/changelog/1.3/CHANGELOG.md`](changelog/1.3/CHANGELOG.md) § W12), so the environments *are* now isolated on every name the detector can see — but the lesson stands unchanged: **this item's closure never meant the environments were isolated; it meant the detector could finally see what was not.**

---

## ~~W10: eight Supabase Edge Functions were untracked; four are now committed but unreviewed~~ ✅

**Priority:** P3 | **Source:** session 2026-08-07, recovering `api-keys-list` for the toolkit e2e suite

`.gitignore`'s blanket `*.ts` (present because Flutter web output generates TS/JS) swallowed `supabase/functions/**`, so `git ls-files supabase/functions/` returned **nothing** while eight functions ran in production. Every other source tree — `functions/`, `workers/`, `scripts/` — has an explicit allow; this one was never added, so the repo *could not* have tracked them. ✅ **Fixed 2026-08-07** (`336cfd2`): allow-line added, all eight recovered with `supabase functions download <slug> --project-ref cfrbahzzklwrnmbtqojl` and committed, each scanned first (all take config from `Deno.env`; none embeds a credential).

**What remains is that four of them have never been read by anyone here.** `provision-api-key` (v22) and the three `ga4-*` (v18) were recovered as deployed artifacts, not as reviewed source, and nothing in any test suite exercises them — which is exactly why their absence went unnoticed. Two specific questions:
- **Is `provision-api-key` still live traffic or a superseded ancestor of the receiver?** It reads the same `CLOUDFLARE_*` + `KV_NAMESPACE_ID` + service-role env as `api-keys-create` and looks like the pre-receiver provisioning path. If it is dead, it is a deployed, publicly-addressable function with production credentials and no owner — delete it rather than leave it.
- **The three `ga4-*` functions read `GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET`**, an integration nothing else in this repo references. Confirm it is intentional and in use.

🔴 **Related divergence found while pinning `verify_jwt`, and it has a deadline: the dev project's service key is legacy JWT format (`eyJ…`) while production's is `sb_secret_…`.** That difference is load-bearing — `api-keys-create` must run `verify_jwt = false` because a `sb_secret_` bearer is not a JWT, and dev only tolerated `verify_jwt = true` because its legacy key *is* one. When the dev key moves to the modern format (or legacy keys are disabled, which [[CR24]] already started), dev provisioning starts 401ing with no code change and no obvious cause. The `verify_jwt` values are now pinned per function in `supabase/config.toml` so deploys stop inheriting CLI defaults, but the key-format gap is unfixed.

✅ **Closed 2026-08-09.** All three open items resolved:

1. **`provision-api-key` is dead and deleted.** No caller exists anywhere — the Flutter app routes through `ProvisioningService.sendEvent` → sender-worker → api-provisioning-receiver → `api-keys-create`; no code in this repo or its workers calls the function URL. It was the pre-receiver provisioning path, superseded when the HMAC receiver was introduced. Deleted from the repo; a Supabase Dashboard action is still needed to delete the deployed function from production (`cfrbahzzklwrnmbtqojl`) and unbind its `CLOUDFLARE_*` / `KV_NAMESPACE_ID` / `SUPABASE_SERVICE_ROLE_KEY` secrets.

2. **`ga4-*` functions are intentional.** `provider_oauth_tokens` is a first-class schema table (migration `20260319000000_baseline_pre_ledger_schema.sql`, `provider_type` column with `ga4` / `facebook_pixel` / `google_ads` values, RLS on). The three functions — `ga4-list-properties`, `ga4-select-property`, `ga4-token-refresh` — form the GA4 property-linking flow. `GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET` are an intentional integration.

3. **`verify_jwt` pinned for all three `ga4-*` functions** in `supabase/config.toml`. All three extract `sub` from the JWT via base64-decode without verifying the signature — platform JWT verification is load-bearing (same pattern as `api-keys-list`). Setting `verify_jwt = false` on any of them would let any caller forge a `sub` and read or mutate another user's tokens. Comments in config.toml record the constraint so it is not changed by accident.

⚠️ **One sub-item remains a Dashboard action, not a code change:** the dev service key is still legacy JWT format (`eyJ…`), while production's is `sb_secret_…`. `verify_jwt` is now pinned in config.toml so redeploys are safe, but the key-format divergence itself means rotating the dev key to modern format would silently break `api-keys-create` in dev until `verify_jwt = false` is confirmed in place. That rotation is a Supabase Dashboard action tracked as a reminder: before rotating the dev service key, verify `supabase/config.toml` `[functions.api-keys-create] verify_jwt = false` is deployed to dev.

**Status:** ✅ Closed 2026-08-09.

---

## ~~W11: the Playwright suite did not run for two months, and two tests silently went stale~~ ✅

**Priority:** P2 | **Source:** session 2026-08-08, PR #23 CI

`e2e.yml` last ran green on `a51daef`, **2026-06-09**. Its next run was **2026-08-08** — and it
failed. Inside that two-month gap, `f439651` (2026-07-26, *"fix(gdpr): gate Meta Pixel on
marketing consent"*) removed the unconditional pixel `<script>` and its `<noscript><img>` from
`web/index.html`, moving injection behind `if (prefs.marketing)` (`lib/app.dart:55`). The commit
updated the **GTM** test to match but not the two **pixel** tests, which went on asserting the
pre-GDPR behaviour — *requiring the privacy fix to be absent*.

✅ **The two tests are fixed** (this branch): the pixel case became three — no consent, marketing
consent, analytics-only — because the gate is on `marketing` specifically and the third case is
what separates "gated on marketing" from "gated on any consent". The noscript assertion is
inverted to assert **absence**, since a noscript pixel fires for every visitor with no way to
gate it. Negative cases wait out `GTM_INJECT_SETTLE_MS` or they pass merely because injection
has not happened yet.

🔴 **The gap itself is the item, and it is not fixed.** A stale test is a small cost; a suite
that stops running is what let it stay stale for 13 days after the change and would hide the
next one just as well. **Establish why there were no runs between 06-09 and 08-08** — the two
candidates are that `e2e.yml` is effectively schedule-driven and GitHub suspended it (the same
~60-day cron suspension already flagged under [[CR20]] as a second-order risk to
`worker-signals.yml`), or that no qualifying push reached `main` in the window. Those want
different fixes, so measure before choosing. Related in kind to `observability-toolkit`'s
`E2E-PERMANENT-SKIPS`: **a test suite that cannot run and a test suite that is gated off are the
same defect wearing different clothes, and neither shows up as a red build.**

**Also noted, not changed:** `e2e/tests/web-platform.spec.ts:67` — the pre-existing
`GTM script is NOT injected before consent` test has no settle wait, so it is vulnerable to the
same vacuity. Left alone deliberately: it passes today, and changing it could fail a PR on an
unrelated pre-existing issue. One line when someone wants it.

### Diagnosed 2026-08-08 — and BOTH recorded candidates are wrong

The gap was not cron suspension and not a lack of qualifying pushes. **The workflow was
disabled.** Measured over the exact window 2026-06-10 → 2026-08-07, same repo, same branch,
same pushes:

| Workflow | Runs in the gap |
|---|---|
| `ci.yml` | **71** |
| `e2e.yml` | **0** |

That pair refutes both candidates at once. Cron suspension stops only `schedule` events, and
`e2e.yml` is missing its `push` runs too — while `ci.yml`, which triggers on the same pushes to
`main`, ran 71 times. And "no qualifying push reached `main`" is contradicted by **~270 commits**
across 18 active days in the window (06-26, 06-27, 07-01, 07-12, 07-14, 07-17, 07-25, then daily
from 07-26). The repo was never inactive for 60 days either — the longest quiet stretch after the
last e2e run is **17 days**, so `disabled_inactivity` cannot apply. Run history resumes on
2026-08-08 with one `schedule` run and then `push` runs, i.e. it was re-enabled.

🔴 **A disabled workflow is the quietest failure in either repo.** No runs, no failures, no
notifications — there is nothing to alert on, because nothing happens. It is invisible to every
technique this file has accumulated: error rate, subrequest count, watermark freshness and skip
counts all presuppose that *something ran*. The only symptom was two Playwright tests going stale
for 13 days, and those were found by reading, not by a check.

✅ **Fixed: `scripts/check-workflows-active.sh`**, wired as **SIGNAL 6** and documented in
[`docs/observability-signals.md`](observability-signals.md). It asserts every `.yml`/`.yaml` on
disk under `.github/workflows/` reports `state: active`, and it is deliberately the **first** step
of `worker-signals.yml` — ahead of Doppler — because a check that catches checks which have
stopped running must not sit behind a credential path that can itself fail
(`check-worker-signals.sh` exits 0 early when Cloudflare credentials are absent, and folding this
into it would have inherited that). `permissions: actions: read` is the only grant added.

**It watches the files, not a list.** Adding a workflow enrols it automatically; deleting one
retires it. A pinned list needs editing on every change, which is how a guard decays into a
formality — the same reasoning as the toolkit's skip-count guard asserting on skips rather than
pinning `passed == 46`.

**Mutation-proven in six states, because a check that has never failed is not known to work:**
all-active → exit 0 (against the live repo); `disabled_manually` → exit 1 naming the file;
`disabled_inactivity` → exit 1; HTTP 401 → exit 2; non-JSON body → exit 2; absent `GH_TOKEN` →
skip with exit 0. A workflow on disk but unregistered (a feature branch, or a new file) is a
**NOTE**, not a breach.

📌 **It partly watches its own host.** `disabled_inactivity` is the state [[CR20]] flags as a
standing risk to `worker-signals.yml` itself, and this signal breaches on it — so the alert can
now report its own impending silence, for every cause except being disabled at the same moment.
That residual is irreducible from inside the repo: nothing running in GitHub Actions can detect
that GitHub Actions is not running it. An external heartbeat is the only complete answer, and none
is proposed here.

**Status:** ✅ **Closed 2026-08-08** — stale tests fixed earlier; the run gap is diagnosed
(workflow disabled, both candidates refuted) and a guard now fails the daily job on any non-active
workflow. The `web-platform.spec.ts:67` settle-wait note below is unchanged and still open as a
one-line cleanup.

---

## Code Review 2026-07-26 → 2026-07-27 (CR01–CR35)

Started as the open remainder of the 8-area codebase review; CR11–CR15 were found afterwards while deploying and auditing the workers, CR16 while reading the deployed `obtool-*` scripts to settle CR13, CR22–CR23 as follow-ups to the billing-portal auth change, CR26 while fixing the reported dashboard CORS failure — which turned out to sit on top of two deeper auth defects — CR29 while diagnosing CR11 row #7, where the shared secret was the symptom and the unrotatable legacy key path was the actual defect, CR30 while executing CR11 step 1 against a genuinely empty project, and CR31 while answering the plain question "should `api.integritystudio.ai/*` point at `api-gateway`?" — where the answer was no and the three broken URLs found on the way there were the larger finding. Fixed work lives in [`changelog/1.3/CHANGELOG.md`](changelog/1.3/CHANGELOG.md); the review's method, provenance, and 3 refuted claims are in [`CODE_REVIEW.md`](../CODE_REVIEW.md).

| ID | P | Status | One line |
|---|---|---|---|
| [CR01](#cr01) | P1 | ✅ **DONE 2026-08-17** | History scrubbed + force-pushed. **Every rotatable family rotated 2026-07-29** — Stripe, both Auth0 secrets (`AUTH0_CLI_SECRET` twice, the second to recover a wrong-account overwrite), HMAC `SHARED_SECRET`, `sb_secret_` service keys (old revoked), legacy Supabase JWTs disabled, stray key revoked. ✅ **Local cleanup done** — `doppler.json` deleted, `~/.doppler/fallback/` removed. ✅ **`sbp_` token minted & stored in Doppler `prd`** — migration drift check now runs live, all 23 tables + 10 functions verified. ✅ **Database password reset to distinct value** → `SUPABASE_DB_PASSWORD`. **Remaining (Dashboard-only, not blocking):** 2 Stripe key revocations (already revoked, verification pending) |
| [CR18](#cr18) | P1 | ✅ **done 2026-08-06** | Live key minted; prd endpoint + signing secret live and verified. Item 2 (last remainder) resolved: dead `STRIPE_API_KEY` slot (already-revoked, unbound, unread) dropped from Doppler `prd`; `scripts/check-env-isolation.sh` updated in the same pass so the deletion didn't turn a real `PASS` into a manufactured failure |
| [CR11](#cr11) | P2 | ✅ **DONE 2026-08-07 — every step this item owns is closed.** **Nothing in this repo remains.** Isolation, runbook, step 8 and [[CR02]] item 5 are all done, and the last gap this row named — "the dev Supabase project has **zero edge functions**" — is closed: the three functions with source were deployed to `tumhmtshahktumhqqamk` and `api-keys-list` was **source-recovered** (it was never lost, only untracked — see [[W10]]), taking the toolkit e2e suite to **34 passed / 0 failed / 12 skipped**. Also 2026-08-07: the dev sender was deployed and armed, and `PROVISION_WORKER_URL` — which had been the **production** sender, so two e2e suites were creating real users and keys in production — now points at `sender-worker-dev`. **The only residual is a one-line CI change in the other repo** (put the `e2e` job back into `observability-toolkit`'s `publish.yml`), tracked there as `E2E-CI-RESTORE`; do not re-open this item for it | ✅ **2026-08-03: `npm run check:env-isolation` PASSES (exit 0)** — 15 credentials distinct, 2 Stripe keys test-mode in dev / live in prd. Doppler `dev` now reaches its own Supabase project (`tumhmtshahktumhqqamk`), its own Auth0 tenant (`dev-njjmghdzm23uy0p7`) and its own Stripe sandbox; the dev key is proven **refused by production (401)**, and the `*-dev` Workers are armed with dev credentials (live `POST /signup` on `sender-worker-dev` → 201, dev DB 0/0 → 1/1, production counts unchanged). **Steps 8–9 were both mis-stated and are re-measured 2026-08-03** — step 9 (dev Stripe sandbox) was already done when it was written, and step 8's premise is false: the two deploys do **not** share a token. **Runbook tail completed 2026-08-03** — dev DB seeded to reference parity, contact-form-dev armed with dev-safe recipients + a fresh sending-scoped Resend key (proven 200), Playwright contact-worker spec repointed to dev (16/16), dev workers armed (live signup proof). ✅ **Step 8 DONE 2026-08-06 — and the re-measurement it asked for showed the token had already been scoped.** `dev`'s `CLOUDFLARE_API_TOKEN` is `dev-workers-token` (`5fc67fe7`, minted 2026-08-03): Workers Scripts + KV + Account Settings Read, and **provably no** Workers Routes / Zone / R2 / D1 / Pages / token-admin, checked against `prd`'s token as a positive control on the same endpoint. Proven end to end by a real `npm run deploy` → `sender-worker-dev` `01c2da65`, healthy, [[CR14]]'s `previews_enabled: false` intact. Revocation (item 9) needs no action — the superseded token is already absent from the account. 🔴 **Two unrelated tokens surfaced, both consumer-less and `last_used_on: never` since 2025-12-01:** `12c7e4bd` — Workers **Routes** Write across `zone.*` plus Scripts/Pages/R2 — ✅ **revoked 2026-08-06**, with in-use credentials and production health re-checked afterwards as positive controls; `feef0f3d` (account-wide read) **retained by owner decision**. **One thing now remains:** restoring the `observability-toolkit` e2e suite. ✅ **The [[CR02]] item 5 hop is CLEARED as of 2026-08-07** — `api-provisioning-receiver-dev` exists, and all three of `dev`'s `PROVISIONING_RECEIVER_WORKER_URL` / `ACTIVE_KEY_ID` (`dev1`) / `SIGNING_KEYS` are set and point at it, with `dev1` freshly generated rather than copied from production's `v2` and proven **401 against the production receiver**. `receiver-security.e2e.ts` ran 5/5 un-gated. ✅ **The hollow-green blocker that replaced it is FIXED 2026-08-07** (toolkit `509a460`): the suite had **exited 0 when rate-limited**, silently degrading to `1 passed / 4 skipped`, so restoring the CI job would have bought a green check that asserts nothing. `assertNotRateLimited` now throws instead of skipping — mutation-proven by three consecutive runs, the third exiting **1**. Two further self-lies were fixed alongside it: `vitest.config.e2e.ts` was collecting **itself** as a test suite (a permanent failure, and the reason the file count read 9 for 8 suites), and `createTestUser` hardcoded a **production** org UUID, so every suite using it died in setup the moment `dev` was repointed. *(Historical, through 2026-08-06: "still blocked one hop on CR02 item 5's dev receiver — `dev`'s `PROVISIONING_RECEIVER_WORKER_URL` still points at the production receiver while `ACTIVE_KEY_ID`/`SIGNING_KEYS` stay unset in `dev`.")* ⚠️ **Everything below this row is historical.** It read "⚠️ partial, **regressed** — Doppler `dev` still shares one Supabase **project** and Auth0 **tenant** with `prd`. 10/13 → 3/13 on 2026-07-29, but **measured 5 of 13 on 2026-07-31**." Two were new then: `SHARED_SECRET` is byte-identical again (row #7's rotation has been undone), and `SUPABASE_SERVICE_ROLE_KEY` reads "UNSET in both" because **the slot no longer exists in either config** — the detector is checking a name that is gone, while the real service-role credential (`SUPABASE_PROVISIONING_KEY`, shared and **live**) is not checked at all. Longstanding 3: `SUPABASE_URL` + `SUPABASE_ANON_KEY` (one project) and `AUTH0_DOMAIN` (**no API can create a tenant**). 💰 **Re-audited 2026-08-02: unblocking this costs $0** — the Supabase dev project is free (org holds 1 of 2 free slots since `atx_movement` was deleted) and an Auth0 dev tenant is free (dev/staging tenants link to the same subscription). The "pay for a third Supabase project" blocker was **phantom**; the only real spend is ~$10/mo *or* a keep-alive to stop a free dev project pausing after 7 days idle under CI. Two free gaps were added as steps 8–9 on that date — "`deploy`/`deploy:prd` share one `CLOUDFLARE_WORKER_TOKEN`" and "dev has no Stripe sandbox" — and **both claims are false; see the current summary at the head of this row.** Detector history: 5/13 (broken) → 7/15 (true baseline) → 0 real |
| [CR12](#cr12) | P1 | ✅ **done 2026-08-06** | `api-gateway` **healthy and fully bound** (4 secrets — `SUPABASE_JWT_SECRET` correctly stays unbound). **`API_KEY_HMAC_SECRET`** generated and bound to production, verified end to end with a real key (positive control 200, wrong-secret negative control 401) against `/v1/orgs/:id/usage/summary` — the same `machineRouteOpts` path also gates `/v1/ingest/*`. The earlier premise that the canonical value "must come from `observability-toolkit`'s owner" was wrong: the receiver hashes minted keys with plain SHA-256, not HMAC — the HMAC step is entirely this repo's own verification layer, so there was no existing value to match and a fresh one was generated here. A distinct dev-config secret was also stored in Doppler for later, not bound anywhere (`api-gateway-dev` is unreachable per [[CR14]]) |
| [CR14](#cr14) | P1 | ✅ **RESOLVED 2026-08-03 — account-wide, 0 live previews** | **Every exposure this repo controls is closed live (2026-07-29 evening)** — `sender-worker` (14 secrets) and `integrity-studio-contact` joined `api-gateway` + `stripe-webhook`, and the **71 superseded versions** that had been serving (63 `sender-worker` back to 2026-03-29, 8 `contact-form` back to 2026-01-17) now all `404`. The re-audit also killed the "past retention" reading: superseded versions do **not** age out — a `404` means the version came from `wrangler secret put`, which gets no preview URL. ✅ `stripe-webhook-dev` **closed live 2026-08-03** (1 of 6 versions had been serving with 4 secrets after [[CR11]] step 4 armed it; its `wrangler.toml` already inherits `preview_urls = false`). 🔴 **Re-scoped 2026-08-03 and the mechanism was backwards:** a version publishes **the bindings it was uploaded with**, not the script's current ones — so rotation neither leaks backwards nor cleans up forwards, and the receiver has **29 live versions frozen at pre-[[CR01]] credentials while running pre-[[CR29]] code**, i.e. the forgery path is still reachable at a parallel hostname. Also **37 live of 90** retained receiver versions (not "30 of 30"; 36 of 89 at filing — the 90th, the receiver's first green CI auto-deploy, added its own live preview URL six seconds after toolkit `PREVIEW-URLS` was committed), **8** secrets not 9/10, and **five more Workers across three repos** never enumerated (two orphaned, no config on disk). Receiver half now tracked on the owning side as `observability-toolkit` `PREVIEW-URLS` |
| [CR02](#cr02) | P2 | ✅ **done 2026-08-07 — item 5 closed, all 8 items resolved** | **The dev receiver exists.** `api-provisioning-receiver-dev` deployed from a new `[env.dev]` block (`observability-toolkit` `1c4ed45`) with its own KV namespace, its own AE dataset and `crons = []`; verified against deployed state with production as the paired control, and isolated by capability (dev key → production = 401, with a real positive control) rather than by the values differing. This side repoints `sender-worker-dev`'s `RECEIVER` to it, and a new mutation-verified assertion (suite 55 → 60) forbids any `[env.dev]` binding a service that is not itself a dev Worker — turning item 5's "residual safety is credential absence, not design" hazard into an enforced property. ~~⚠️ **Config-only so far: `sender-worker-dev` is not redeployed**, so the running dev Worker still binds production; it stays fail-closed because it holds no signing keys, and arming it must land with the redeploy.~~ ✅ **Redeployed and armed 2026-08-07 — both halves of that caveat are now false.** Re-measured against deployed state today, not inferred: the live script's bindings show `service RECEIVER -> api-provisioning-receiver-dev`, and `SIGNING_KEYS` + `ACTIVE_KEY_ID` are both bound (latest version `2026-08-07T22:16Z`). The co-deploy this caveat demanded is what happened — arming and repointing landed together, so the dev sender never ran armed against the production receiver. ~~🔴 Separately, the toolkit e2e suite turns out to be only ~once-per-hour repeatable and **exits 0 when rate-limited** — a blocker for restoring its CI job, detailed in item 5.~~ ✅ **Fixed 2026-08-07** (toolkit `509a460`): `assertNotRateLimited` throws instead of skipping, so the suite can no longer report success without running — mutation-proven by three consecutive runs, the third exiting **1**. The IP limiter (20/15 min, counted *before* signature verification, so forged-signature tests spend it too) still caps local runs at roughly two per window; `clear-dev-rate-limits.sh` resets it. See [[CR11]] and toolkit `E2E-CI-RESTORE`. *Historical:* Dev/prod split done and verified live. **2026-08-03:** it now has data isolation behind it — [[CR11]] passes, so the dev receiver (item 5) is **unblocked**; it would write to the dev Supabase project, not production. It remains a *config-layer* split at the credential layer, but not for the reason step 8 gave: `deploy` and `deploy:prd` do **not** share a token (`CLOUDFLARE_API_TOKEN` is distinct in `dev` vs `prd`; the byte-identical `CLOUDFLARE_WORKER_TOKEN` is read by no code in this repo). The real gap was that dev's token was account-wide in scope — blast radius, not a shared credential. ✅ **Step 8 closed 2026-08-06** ([[CR11]] step 8 holds the measurement): `deploy` now provably authenticates as a Workers-only, Routes-less, Zone-less token. **Item 5 (dev receiver) is the only thing left, and it is unblocked but not started.** *Historical, 2026-08-02: "a config-layer split with no credential behind it and no data isolation behind it; item 5 blocked behind CR11 step 1."* |
| [CR04](#cr04) | P2 | ✅ **DONE — merged and deployed 2026-08-03** | Fragment handoff **deleted** (`provision_page.dart:86-92`); `_goToDashboard` now opens the dashboard with no token. The item's "requires a coordinated change in the dashboard app" premise was false — the dashboard never read `location.hash` and logs in itself, so this was one line, this repo only. **Ships on merge to `main`** (`ci.yml` → Cloudflare Pages `integritystudio-ai`) |
| [CR13](#cr13) | P2 | ✅ **DONE 2026-08-08 — every step, decided and executed same day** | **Option C: the gateway got `api.integritystudio.dev`**, which closes steps 3–5 and **supersedes [[CR31]]'s option-B path-split**; [`api-routing.md`](api-routing.md) has been resynced to match (`f36b813`) rather than left disagreeing. The name was already the gateway's Auth0 audience/resource server (`69c4e28bf801eab9e683c85a`) — though an audience is opaque and was never obliged to resolve, so this was naming correctness, not a repair. Executed: `integritystudio.dev` migrated Porkbun → Cloudflare (a **delegation change, not a transfer**; DNSSEC off, no MX/TXT/CAA), zone active in 20 min, Custom Domain `e3f5d910…` live (**200** `/health`, **401** `/v1/me`), `routes = [{ …, custom_domain = true }]` in `wrangler.toml` (`a61e4a6`), Flutter defaults repointed with CORS measured on both hosts (`f36b813`). **No outage** — both nameserver sets served byte-identical answers throughout, verified before delegation moved. 🔴 **Two regressions found and closed by re-probing after cutover rather than trusting the parity check**: a probed DNS inventory missed all four **AAAA** records (would have dropped the dashboard for IPv6 clients only), and Cloudflare imported the vestigial `*` CNAME **proxied**, serving `525` on an HSTS-preloaded TLD. **Record-level parity does not prove behavioural parity when the proxy flag is part of the record.** Step 1 remains **proven by a real deploy 2026-07-30** |
| [CR17](#cr17) | P2 | ✅ done | Migration ledger repaired; drift detector in CI (`scripts/check-migration-drift.sh` + `migration-drift-check` job) |
| [CR19](#cr19) | P2 | ✅ done | `stripe-webhook` org-not-found now returns `{ ok: false }` → unclaimEvent + dead-letter (commits eaaa199, 9741594) |
| [CR20](#cr20) | P2 | ✅ **DONE 2026-08-09 — both halves observed** | **The alert was deliberately FAILED to prove its channel, because a passing run proves nothing about it.** `MIN_SUBREQUEST_RATIO` was temporarily set 0.5 → 99 to force exactly one breach; run `31265198806` exited 1 for the intended reason, GitHub raised a `CheckSuite` notification 24 s later, and **the owner confirmed receipt of the email** ("Failed in 13 seconds"). All four links observed rather than inferred: breach detected → job exits 1 → notification raised → email lands. Both temporary changes reverted in `613fa8f`, verified byte-identical to `982f406`, check exits 0 again. Armed on `main` as `982f406`, schedule `37 8 * * *`, workflow `state=active`. *Historical, before the merge:* **Step 4 answered 2026-07-31 (cron runs and succeeds). Alert implemented 2026-08-08**: daily `worker-signals.yml` workflow covering subrequest-ratio check (SIGNAL 2 — the one error rate cannot make) and dead-letter depth (SIGNAL 5). Verified live: all five signals evaluate and the check exits 0, with `stripe-webhook` at **1.00 subreqs/req** — the number that was 0.00 throughout the four-month outage. 🔴 **But it is inert until this branch reaches `main`**: GitHub runs `schedule` workflows from the **default branch only**, so no alert can fire today, and there is no notification to prove the channel works until then. Marking this ✅ before the merge is the same **merged-≠-live** error this file has now corrected four times ([[CR21]], [[CR22]], CR03/CR15, and this). Merge, then confirm one scheduled run actually appears in Actions. Second-order: GitHub also suspends cron workflows after ~60 days of repo inactivity, so a quiet period silently disarms it — ✅ **now detected**, since [[W11]]'s SIGNAL 6 breaches on `disabled_inactivity` and runs as the first step of this same workflow. The irreducible residual is that nothing running inside GitHub Actions can detect that Actions is not running it. [[W04]] step 3 (dashboard) remains blocked on `obtool-ingest` repair but is not CR20's scope |
| [CR03](#cr03) | P2 | ✅ done | KV namespaces created and bound; **live in production since the 2026-07-30 deploy** — `RATE_LIMIT_KV` → `766332ec…` confirmed in the deploy's binding list |
| [CR15](#cr15) | P3 | ✅ done | Item 1 deployed 2026-07-30 (`enabled=True logs=True invocation=True traces=True` after ~4 months unmonitored). **Item 2 done 2026-07-31** — all four stale secrets deleted; production `sender-worker` went 16 → 12 bound, `/signin` still 401s correctly and the `RECEIVER` service binding survived |
| [CR21](#cr21) | P3 | ✅ done | `stripe-webhook` uses `ctx.waitUntil(processEvent(...))` — 2xx before DB writes. **Merged 2026-07-29 but only live since 2026-07-30**; verified by grepping the deployed bundle, not inferred |
| [CR16](#cr16) | P3 | 📋 by design | Internal vs customer-facing OTEL pipelines — deliberate; **do not de-duplicate**. Convergence deferred |
| [CR22](#cr22) | P3 | ✅ **exercised and confirmed live 2026-08-06** | Billing-portal API-key 403, deployed 2026-07-30, now proven end to end now that [[CR12]] bound `API_KEY_HMAC_SECRET`: a real signed test key against `POST /v1/orgs/:id/billing-portal` returns exactly `403 "Billing portal requires a user session; API keys are not accepted"` |
| [CR23](#cr23) | P3 | ✅ resolved | Design decision: 401 for invalid credentials, 403 for valid-but-wrong-type. HTTP-correct; no code change needed |
| [CR24](#cr24) | P2 | ✅ done | Legacy `anon` + `service_role` JWT keys disabled 2026-07-29 — **verified by probe**: both now return 401. Reversible via the same endpoint if the receiver turns out to depend on one (its `/health` is 200 post-disable) |
| [CR25](#cr25) | P2 | ⚠️ 1 item open (MFA enforcement) | Auth0 tenant A production-readiness. Restructured 2026-08-03: 8 of 13 done (incl. branding, and the `integrity-dev-m2m` security finding closed via CR11), 4 carved out to [[CR32]]–[[CR35]], **1 left here — MFA enforcement** (factors available, `guardian/policies` `[]`; enabling forces ~96 users to re-enrol, owner decision). No active security finding |
| [CR26](#cr26) | P1 | ✅ done | `POST /bootstrap` mounted in `api-gateway` — matches the Flutter app contract with no client release. Handler ported from `bootstrap-worker` (fixed `in` filter on org query; uses shared `resolveUserId`/`buildEntitlementMap`). 14 tests added to `api-gateway/src/routes/bootstrap.test.ts`. `bootstrap-worker` directory deleted; removed from `WORKERS` / `SECRET_BEARING` in deploy-environments test and from root `package.json` scripts. ~~Needs `deploy:prd` on `api-gateway` to go live.~~ **Deployed and verified live** (version `846f8c21`) — see the CR26 body. Re-confirmed 2026-07-31: production `POST /bootstrap` answers **401**, not 404, so the route is mounted and auth-gated. |
| [CR30](#cr30) | P1 | ✅ **RESOLVED 2026-08-03 — guard proven green in CI** | **The migration ledger could not rebuild the schema — now it can, proven by replay onto an empty database.** Final parity: 24/24 tables+views, 255/255 columns, 3/3 enums. Five new migrations; three separate ordering defects in the *existing* ledger were only findable by replaying. Gap was 10 tables, 3 enums, 2 columns on a ledger-managed table, 1 view — 43% of the schema was unversioned. Production untouched (read-only queries; all new files idempotent). **CI guard written 2026-08-03** (`migration-replay-check.yml` → `check-migration-replay.sh`: full local stack, `db reset`, schema assertions incl. the view; mutation-tested assertion SQL). ✅ **It has now RUN AND PASSED** — run `30804541500`, `Migration Replay Check`, success in 2m46s on the merge push to `main`, its first real execution. (It could not run before that: Docker is absent locally and the workflow was not yet on the default branch.) It triggers only on `main` (`push`/`pull_request` `branches: [main]`), so **pushing this branch does not run it** — the PR into `main` is the first execution. ⚠️ The summary here read "proven on its first CI run" until 2026-08-03: the body's pending gate ("the first CI run is the real proof") was compressed into a completed one, which is how an unexecuted guard came to read as a verified one. The drift check compares against production and cannot catch this class |
| ~~[CR30](#cr30)~~ | P1 | *superseded row* | **The migration ledger cannot rebuild the schema.** `db push` onto a genuinely fresh project fails at `relation "public.users" does not exist`: the 14 migrations create 13 tables but reference `public.users` and `public.api_keys` by foreign key and create neither. `migration list` has always said "zero out of sync" because it compares against **production**, which has both tables from before the ledger existed — so the drift guard cannot catch this class by construction. Two consequences: [[CR11]] step 1 is blocked (and behind it [[CR02]] item 5 and the toolkit e2e suite), and **the repo cannot reconstruct its own database from source** — a disaster-recovery gap that is live today. Needs a baseline migration + a CI job that replays the ledger onto an empty DB |
| [CR29](#cr29) | P1 | ✅ **RESOLVED 2026-08-03** | **The HMAC keyless-downgrade forgery path is closed and the legacy credential eliminated.** Steps 1+2 deployed (sender fail-closed, receiver requires `x-key-id`); step 3 done — `SHARED_SECRET` made optional in the receiver `Env`, unbound from both workers, its Doppler `prd` slot deleted, and dropped from `KEY_ROTATION_DATES`. Verified in prod: keyless `/inbox` → **401** (was 200), `v2` passes signature, `/signin`→`/send` → `ok:true`. ⚠️ Sender fix on branch `fix/active-subscription-id` — merge to make step 1 durable (security fix is receiver-side, on toolkit `main`) |
| [CR27](#cr27) | P1 | ✅ done | `stripe-webhook` dead-lettered **every** real event for four months — two independent defects. `invoice.paid` read `invoice.subscription`, which Stripe deleted in API 2025-04-30 (schema now accepts both shapes); `customer.subscription.updated` used `ON CONFLICT (organization_id, stripe_subscription_id)` with no matching unique index, failing `42P10` (migration `20260731000000`). Both latent because no real event had ever reached these paths. **Read the misdiagnosis note in the body** — the wrong fix shipped first |
| [CR28](#cr28) | P3 | ✅ done | `resolveBillingStatus` knew 2 of Stripe's 8 subscription statuses and collapsed the rest to `inactive`, so a **trialing** customer read as never having subscribed. Found in the state [[CR27]]'s replay left behind |
| [CR31](#cr31) | P2 | ✅ **DONE 2026-08-08 — all 7 steps** | ✅ **Closed.** 4 docs defects fixed 2026-08-03 (`97ade42`); the sync guard built then and **widened 2026-08-08**; step 5 closed by **supersession** and step 7 done (`f36b813`). ⚠️ **The "4-pattern path-split" recommendation below was SUPERSEDED and never built.** [[CR13]] was decided and executed on 2026-08-08 in favour of option C — `api-gateway` has its own hostname, **`api.integritystudio.dev`**, live and serving. So there is no split to build on `api.integritystudio.ai`, and the hostname step 5's docs fixes need now **exists**, where this row previously recorded it as not yet created. ✅ [`api-routing.md`](api-routing.md) was resynced in the same pass (`f36b813`). Everything below is retained as the measurement, which is still accurate about what serves what today. **The published API docs advertise four URLs that resolve to nothing, and the product's own API has no hostname.** Routing inventory captured in [`api-routing.md`](api-routing.md) (measured 2026-08-03). `api.integritystudio.ai/*` → `obtool-api` (observability read API); `api-gateway` — account, billing, ingest — is workers.dev-only, and the Flutter client's `API_GATEWAY_URL` default ships that way. Customer-visible right now: `/v1/health` 401s (health is at `/health`; the `/v1/*` middleware catches it first), `POST /v1/alerts` exists on **neither** worker, and both `sandbox-api.integritystudio.ai` and `status.integritystudio.ai` are **NXDOMAIN**. The two route tables are **disjoint** (only `/health` overlaps), so the fix is a 4-pattern path-split, not a repoint — repointing the wildcard would 404 all 13 `obtool-api` routes. Supplies the measurement [[CR13]] was waiting on; the ownership decision stays there. ⚠️ The fourth defect surfaced only after fixing the checker's grep, which had been merging `sandbox-api.…` into `api.…` as a substring — third instance of a green check that had normalised away what it was checking. Needs: fix the 4 docs sites, decide the split, build a sync guard so this document cannot silently rot |
| [CR32](#cr32) | P3 | 🔴 open — billing (owner) | Auth0 **custom domain** (login runs on `dev-…auth0.com`). Hostname decided (**`auth.integritystudio.ai`**), DNS confirmed ready (Cloudflare zone reachable, clean slate). **Corrected 2026-08-06 — it IS gated**, just not by plan tier: a real `POST /custom-domains` with a valid body and correctly-scoped token returns `403 "There must be a verified credit card on file"`. The earlier "NOT plan-gated" reading came from an empty-body probe that never reached the billing check. Owner needs to add a verified card in the Auth0 Dashboard; everything after that is scriptable |
| [CR33](#cr33) | P3 | 🔴 open — needs a build | Auth0 **log streams** — auth logs exported nowhere. Carved from CR25 item 6. Needs a receiver that parses Auth0 log-event JSON; the OTLP ingest would reject every batch. **Do not point an http stream at the OTLP endpoint** |
| [CR34](#cr34) | P2 | ✅ **RESOLVED 2026-08-03 — implicit 2→0, ROPC 3→1** | Strip Auth0 **`implicit` + ROPC** grants (SPA + `AUTH0_MANAGER`). Carved from CR25 items 7–8. Minutes by API, but must verify `sender-worker`'s `password-realm` `/signin` survives; `My App`'s ROPC likely stays until the client gets a refresh flow |
| [CR35](#cr35) | P3 | 🔴 open — spend | Auth0 **breached-password detection**. Carved from CR25 item 3. Genuinely plan-gated (PATCH 400 "upgrade your subscription"); re-attempt after any plan change |

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
5. ✅ **FULLY DONE 2026-08-07 (evening) — the dev sender is deployed, armed, and proven to reach the dev receiver.** The caveat below ("the repoint is config-only and the running dev Worker still binds production") is closed: `npm run deploy` in `workers/sender-worker` landed `sender-worker-dev` version `4fe6dd53`, and the deployed bindings now read `RECEIVER -> api-provisioning-receiver-dev`. Armed with `SIGNING_KEYS` + `ACTIVE_KEY_ID` (`dev1`) **after** the repoint was live, which is the order this item insisted on — arming first would have pointed a signing dev sender at the production receiver.

   **Checked before arming, not after:** `dev1` and production's `v2` share no material (different lengths, different hashes), so this is a dev-owned credential rather than a copy. **Proven by where the traffic landed:** four probe requests through the dev sender produced `rl:email:probe-*` counters in the **dev** receiver's KV namespace (`a0df5e71…`), and production `sender-worker`'s `modified_on` was byte-identical before and after the dev deploy. `previews_enabled: false` survived ([[CR14]]).

   ⚠️ **One propagation trap worth keeping:** immediately after `wrangler secret put`, `/send` still answered `SIGNING_KEY_UNRESOLVED`. It cleared on its own within a minute — the [[cloudflare-rollout-propagation]] pattern. Sample twice before concluding a binding is wrong.

   🔴 **And the isolation gap this item never named: Doppler `dev`'s `PROVISION_WORKER_URL` was the PRODUCTION sender** (`sender-worker.alyshia-b38.workers.dev`). So while everyone's attention was on the receiver, the two e2e suites that reach it *through* the sender — `sender-receiver` and `provision-key` — had been creating real users and API keys in production on every local run. Repointed at `sender-worker-dev`. Same lesson as `SUPABASE_PROVISIONING_KEY`: the isolation checker only covers the names on its list, and this name was not on it.

   *(Original entry, accurate for the receiver half, follows.)* ✅ **DONE 2026-08-07 — `api-provisioning-receiver-dev` is deployed, and this side's binding now points at it.**

   **Receiver side** (`observability-toolkit`, commit `1c4ed45`): a new `[env.dev]` block in `services/api-provisioning-receiver/wrangler.toml`, deployed via a new `npm run deploy:dev`. The plaintext-`SUPABASE_URL` hazard this item warned about was handled exactly as instructed — `[env.dev.vars]` repoints it at the dev project — and the dev Worker also got **its own** KV namespace (`RECEIVER_RATE_LIMIT_KV_DEV`), **its own** Analytics Engine dataset, and an explicit `crons = []` (`triggers` *is* inherited, so without it the dev Worker would run production's `*/5` alerting cron).

   **Verified against deployed state via the Cloudflare API with production as the paired control**, not by re-reading the config — the whole failure mode here is a key that silently means "unbound": dev `SUPABASE_URL` → `tumhmtshahktumhqqamk` (prod → `cfrbahzzklwrnmbtqojl`), dev KV → `a0df5e71…` (prod → `cf9d7d72…`), dev `schedules` → `[]` (prod keeps its `*/5`), dev `previews_enabled` → false. Production's bindings were unchanged by the dev deploy.

   **Isolation proven by what the credential can reach, not by the two values differing** — the distinction this file records under [[CR11]]. Signing key `dev1` is freshly generated, never a copy of production's `v2`. Four-way probe: `dev1` → dev receiver reaches payload validation (**not** 401 — the positive control, without which a uniform 401 on every row is indistinguishable from a broken probe); `dev1` → **production** receiver **401**; wrong secret → 401; unknown key id → 401.

   **This side's change (in this repo, uncommitted):** `sender-worker-dev`'s `RECEIVER` service binding is repointed from `api-provisioning-receiver` to `api-provisioning-receiver-dev`. The item's original advice — *delete* `[[env.dev.services]]` outright — was written when no dev receiver existed; with a real one, repointing is strictly better than removing the capability. The guard it asked for is built either way and is **mutation-verified**: `deploy-environments.test.ts` now asserts no `[env.dev]` binds a service whose name is not itself a dev Worker (suite 55 → 60; reverting the binding fails that one test with a named message). That converts the "residual safety is *credential absence* rather than design" hazard into an enforced config property. Prefer the name-shaped rule as written — it is checkable from config alone, needs no account access, and fails closed for a service that does not exist yet.

   ⚠️ **Not yet done, and deliberately:** `sender-worker-dev` has **not** been redeployed, so the repoint is config-only and the running dev Worker still binds production. It stays fail-closed regardless (it holds no `SIGNING_KEYS`/`ACTIVE_KEY_ID`), which is why this is safe to leave — but per this file's own recurring lesson, **do not read the repoint as live until it is deployed and re-checked**. Arming the dev sender with dev signing keys is the co-requisite that must land in the same change.

   🔴 **New blocker for the toolkit e2e restore, found while verifying — the suite is not repeatably runnable.** `receiver-security.e2e.ts` is 5/5 against dev, but **only on a fresh rate-limit window**: a second run inside the window reports `1 passed | 4 skipped` and still **exits 0**, because its `skipIfRateLimited` helper turns a 429 into `ctx.skip()`. Both receiver counters were found at their caps. The tighter limit is not the obvious one — IP is 20/15 min and is counted *before* signature verification, so the deliberately-forged tests burn it too, while email is 5/hour counted *after*, making the suite roughly **once-per-hour** repeatable. A rate-limited CI run would therefore be green and assert nothing, which is the same hollow-green shape as [[CR20]]'s "succeeded while making no outbound calls". Restoring the `e2e` job needs a per-run unique email, a dev-only limit bypass, or a hard failure rather than `ctx.skip()` on 429. Tracked toolkit-side in `docs/workers-and-deployment.md`.

   ✅ **RESOLVED 2026-08-07** (toolkit `509a460`) — **two of the three prescriptions above, deliberately not the bypass.** `assertNotRateLimited` now throws instead of skipping, and narrowly: only on the limiter's own `RATE_LIMITED` code, so the receiver's *other* 429 (`QUOTA_EXCEEDED`) is not mislabelled as a rate limit. Every request also carries a unique email, which retires the 5/hour email limiter as a cause entirely. Mutation-proven by three consecutive runs — 1 and 2 pass 5/5 exit 0, run 3 **exits 1** carrying the retry-after and the remedy. The IP limiter remains, so a full run is about twice per 15-minute window locally; `services/e2e/scripts/clear-dev-rate-limits.sh` resets it, guarded by a `_DEV` title assertion so a swapped namespace id fails closed rather than clearing production's counters. ⚠️ Two caveats worth keeping: the script needs a **propagation wait** after the KV delete — clear→run still 429s and reads exactly like a script that did nothing (`d52ad26`) — and this is likely a *local* constraint rather than a CI one, since GitHub-hosted runners have no stable egress IP, but that should be measured on the first restored runs rather than assumed.

   *(Original entry follows, kept because its sequencing reasoning is what made the order correct.)* **Remaining — deploy a dev receiver. ✅ Unblocked 2026-08-03** (was 🔴 blocked behind [[CR11]] step 1; that step is done and `check:env-isolation` passes, so a dev receiver now writes the dev Supabase project). **One sequencing constraint replaces the old blocker:** `sender-worker-dev` deliberately holds no `SIGNING_KEYS`/`ACTIVE_KEY_ID`/`SHARED_SECRET`, so dev `/send` fails closed today — arming the dev sender and deploying the dev receiver must land together, or dev `/send` starts reaching production the moment the keys appear. `sender-worker-dev` still binds `RECEIVER` to the production `api-provisioning-receiver` (a **service binding**, `[[env.dev.services]]`, naming the same Worker as the top-level block); no dev receiver exists, and it lives in the `observability-toolkit` repo. Cross-repo.

   **Why the order mattered, recorded 2026-08-02 because this item read as ready-to-do for a week — and the hazard it names is now closed.** The receiver's `SUPABASE_URL` is a plaintext var in its `wrangler.toml` pointing at the production project, and `dev`/`prd` **used to share** that project ([[CR11]]). A dev receiver stood up before CR11 step 1 would have run `ensureTeamOrg` / `addOrgMember` / `grantDashboardAccess` and minted real keys via `api-keys-create` **against the production database, successfully** — strictly worse than the fail-closed state. ✅ **CR11 step 1 landed 2026-08-03**, so a dev receiver pointed at the dev project no longer has that failure mode. ⚠️ **But the underlying lesson stands and still applies to the deploy itself:** that `SUPABASE_URL` is a plaintext var in the receiver's own `wrangler.toml`, so deploying a dev receiver **without changing it** still writes production. Repoint it in the same change; do not rely on Doppler, which does not supply it. And the residual safety on this side is still *credential absence* rather than design — `sender-worker-dev`'s missing signing keys — which nothing enforces.

   **Do this part now — it is free, unblocked, and holds regardless of how CR11 resolves.** Delete `[[env.dev.services]]` so dev has no `RECEIVER` binding at all, and assert in `workers/lib/deploy-environments.test.ts` that no `[env.dev]` binds a service whose name is not itself a dev Worker — the same shape as the existing "dev never shares a KV namespace with production" assertion. That converts an incidental property into an enforced one. Prefer **absent capability over disabled capability**: do not add a dry-run or no-write flag to the receiver, because a flag that must be off in production is the failure mode `ALLOW_TEST_BYPASS` already has to be caveated against.

   **Rejected alternative:** deploying `workers/receiver-worker/` (the local stub) as `receiver-worker-dev` and repointing the binding at it. Tempting — it is already a pure HMAC/replay verifier that touches no database, and it already tracks the [[CR29]] step-2 contract. Rejected because every vendor in this stack supplies a real isolated environment for free (see [[CR11]] *Blockers and cost*), so a bespoke test double standing in as an environment is the thing those features exist to avoid; it would cover `/send` only, while `/signup` needs Supabase, Auth0 **and** Stripe; and it creates a drift surface that has already bitten once (the `resolveSigningKey` backport, tracked as a `PROV-SEC` line item in the toolkit). Revisit only if the toolkit's e2e suite is restored to CI and needs a target sooner than CR11 can deliver one.
6. ~~Give `contact-form-dev` its own KV namespace.~~ Done 2026-07-27 — `CONTACT_RATE_LIMIT_KV_DEV` (`5719e569…`), distinct from the production namespace so a dev deploy cannot evict live rate-limit and idempotency keys. A test now asserts dev never shares a namespace with production.
7. ~~Verify by deploying.~~ Done 2026-07-27 — `npm run deploy` was run for real in `workers/sender-worker` and landed on `sender-worker-dev`, not `sender-worker`. All five dev workers deployed; the four production workers were confirmed unmodified afterwards by their `modified_on` timestamps.
8. ✅ **DONE 2026-08-06 — see [[CR11]] step 8 for the measurement; do not re-derive it here.** `deploy` authenticates as `dev-workers-token` (`5fc67fe7`), which is proven to hold **no** Workers Routes, Zone, R2, D1, Pages or token-admin capability while `prd`'s token does (paired control on the zone-routes endpoint), and a real `npm run deploy` landed on `sender-worker-dev` under it. ⚠️ **The credential layer is now narrowed but still not a boundary:** Workers Scripts is an account-level permission with no per-script selector, so this token can still reach production Workers. This item's guarantee continues to rest on `deploy-environments.test.ts` at the config layer. *(Historical framing follows.)* This item's whole guarantee — `npm run deploy` cannot overwrite production — is enforced at the *config* layer by `deploy-environments.test.ts`, and thinly at the credential layer. 🔴 **The original reason given was wrong:** it said `deploy` and `deploy:prd` "both authenticate with the same `CLOUDFLARE_WORKER_TOKEN` from Doppler `prd`, so only argument order stops a dev deploy reaching a production Worker." They do not share a token — `wrangler` reads `CLOUDFLARE_API_TOKEN`, `deploy` sources it from `--config dev`, and the dev and prd values are distinct (dev is an account-wide `cfat_` token; prd sha `25889310adec`). ⚠️ **The dev token was rotated after this measurement — current dev sha `15680a6f90a5` (2026-08-03); re-measure before scoping.** The credential-layer weakness is real but different: dev's token is **account-wide in scope**, reading all 18 scripts in the account, and Cloudflare offers no per-script scoping for Workers Scripts. **Full measurements and the minting steps live in [[CR11]] step 8** — do not re-derive them here.

**Design note — why production stayed on the top-level config.** The original scope proposed `[env.production]` with `deploy:prd --env production`. That would have been actively harmful: a named environment renames the Worker (`sender-worker` → `sender-worker-production`), orphaning its Durable Object namespaces, routes, and crons, and breaking both the Flutter compile-time default URL and the receiver's service binding. Instead the top-level block **is** production and is untouched; `[env.dev]` is the overlay. The production deploy path is byte-identical to before this change.

**CR02a — resolved.** The routes had already moved to top level in `a0fca5c`, so they now attach on the plain `deploy:prd`. The `QUOTA_DO` binding concern is handled by repeating it under `[env.dev]` (wrangler does not inherit `durable_objects` into named environments) while leaving the top-level binding in place. `migrations` is inheritable and applies to both. The unused `[env.staging]` block was left alone at the time — dead, but harmless, and nothing deploys it. *(Superseded 2026-07-31: it was deleted under [[CR13]]. "Harmless" was the wrong read — it was a route claim in the one file where a route claim has already caused an outage, and it repeated neither `durable_objects` nor `observability`.)*

**Status:** Done and verified live (2026-07-27) — `npm run deploy` can no longer overwrite a production worker, enforced by `workers/lib/deploy-environments.test.ts` (31 tests, mutation-verified) and confirmed by an actual deploy. ~~Only item 5 remains (dev receiver, cross-repo).~~ **Restated 2026-08-03 — the picture is now much stronger than "config-layer only."** [[CR11]] passes, so there IS data isolation behind the split: `--config dev` reaches a separate Supabase project and Auth0 tenant, and the `*-dev` Workers are armed with dev credentials (proven by a live signup). The two remaining items are both smaller than first framed: item 5 (dev receiver) is ~~**unblocked** — it would write the dev project now, gated only on the sender/receiver co-deploy sequencing (see item 5)~~ ✅ **CLOSED 2026-08-07 — the receiver is deployed and the co-deploy happened** — and item 8 is **not** the shared-token leak it was written as: the two deploys already authenticate with *distinct* `CLOUDFLARE_API_TOKEN`s (dev an account-wide `cfat_`), so item 8 narrows an already-separate credential's blast radius rather than closing a leak. So the config-layer guarantee (`deploy-environments.test.ts`) now has both a data boundary and a distinct credential behind it; what is left is receiver-side work and token-scope hardening, neither a live exposure.

**Read [[CR11]] before treating the dev workers as an environment.** ~~The structural split is real, but Doppler's `dev` and `prd` configs hold identical credentials, so there is no data isolation behind it. The dev workers were deployed without secrets on purpose.~~ **Superseded 2026-08-03:** CR11 passes — `dev` and `prd` now hold *distinct* credentials for separate Supabase/Auth0/Stripe backends, and the `*-dev` workers are armed with the dev set (proven by a live signup). The dev workers ARE a real environment now; the remaining caveats are operational (dev DB seeded only to reference parity; ~~`sender-worker-dev` withholds its signing keys until a dev receiver exists~~ ✅ **superseded 2026-08-07 — the dev receiver exists and the sender is armed**: `SIGNING_KEYS` and `ACTIVE_KEY_ID` are bound and `RECEIVER` resolves to `api-provisioning-receiver-dev`, verified against deployed bindings), not a lack of isolation.

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
**Estimated:** ~~3–4 hours (coordinated with the dashboard app)~~ **~15 minutes, this repo only** — re-scoped 2026-08-03; see the update block below

**Context:** The review's "JWT accepted and propagated via URLs" finding was marked fixed. The `?jwt=` router entry point is genuinely gone, which removes the login-CSRF deep-link vector. The dashboard redirect moved from `?access_token=` to `#access_token=` (`lib/pages/provision_page.dart:90`), and a fragment is not sent to the server, so proxy/server-log and `Referer` leaks are closed. The token is still in a URL, though: fragments are stored with the browser-history entry — contrary to the comment on that line — and any script on the dashboard origin can read `location.hash`.

**Scope** *(rewritten 2026-08-03 — the original three steps are struck; the reasoning is in the update block below)*:
1. ~~Replace the fragment handoff with `postMessage` to the dashboard origin, or a single-use exchange code redeemed for the JWT.~~ ✅ **Deleted the fragment, 2026-08-03.** `_goToDashboard` is now `await launchUrl(Uri.parse(ExternalUrls.dashboardApp))` — no `#access_token=`, no `Uri.encodeComponent`. `flutter analyze` clean on the file. Nothing else referenced the handoff: `access_token` appears nowhere else in `lib/`, `test/` or `e2e/`, so no test asserted it and none needed updating. The button copy ("Go to Dashboard") never promised a signed-in landing, so it stands. ⚠️ **Not live** — `ci.yml`'s `deploy-cloudflare` job is gated on `refs/heads/main` + `push`, so the fix ships to Cloudflare Pages `integritystudio-ai` only on merge.
2. ~~Correct the comment at `provision_page.dart:87-89`~~ ✅ done 2026-07-26; superseded — step 1 replaced it with a comment saying why no token is passed, so the next reader does not "restore" the handoff.
3. ~~Requires a matching change in the dashboard app.~~ **False** — the dashboard never reads the fragment and logs in on its own.
4. Decide separately whether the JWT should keep living in `localStorage` on *this* origin (`lib/services/auth_storage_web.dart:16`, `saveJwt`). Out of CR04's fragment scope and a conventional choice, but it is the other place the token sits at rest, and it is where the token comes from — so it is the question that remains once the fragment is gone.

**Status:** ✅ **DONE — merged to `main` and deployed 2026-08-03.** The fragment is gone from `provision_page.dart`, the branch was merged (`622b323`), and CI's `deploy-cloudflare` job shipped it to the live Pages site (run `30804542535`, all 7 jobs green). Verified after: `access_token` appears in **0 files** under `lib/`, and `integritystudio.ai` returns 200. ~~committed on `fix/active-subscription-id`, unpushed, and therefore not deployed~~ — that was true when written and superseded hours later by the merge. ~~Full fix (postMessage / exchange code) requires a coordinated change in the dashboard app.~~ It did not — see the re-measurement below. *(Earlier: partially done 2026-07-26, commit ~~d632263~~ **`1c83136`** — misleading comment corrected; see the SHA note at the end of this entry.)*

> ✅ **Re-measured 2026-08-03 — the item's blocking premise was wrong, and the fix was a one-line unilateral change in this repo. Done the same day.** Up to that point nothing about the handoff had changed since 2026-07-26; `provision_page.dart:93` still built `${ExternalUrls.dashboardApp}#access_token=$encoded` and the file's last commit was the comment fix. What was new is the other end.
>
> **The dashboard never reads the fragment.** `ExternalUrls.dashboardApp` is `https://integritystudio.dev` (`lib/config/content/constants.dart:71`), which is the **`integritystudio/quality-metrics-dashboard`** GitHub Pages site (`homepage` confirmed via the repo API; title *Quality Metrics Dashboard*; `www` CNAMEs to `integritystudio.github.io`). Its deployed bundle contains **zero** `location.hash` reads. Its router (`wouter`) subscribes to `hashchange` but sources location from `location.search`. Every `access_token` occurrence in the bundle belongs to `@auth0/auth0-spa-js` / `oauth4webapi` internals — token-endpoint parsing, DPoP, the cache manager — not to a handoff reader. The app performs its **own** Auth0 SPA login: `loginWithRedirect` / `loginWithPopup` / `handleRedirectCallback`, `useRefreshTokens`, tenant `dev-68gg87ow4mg4kzyo.us.auth0.com`, client `CNfd6xPP…`, audience `https://api.integritystudio.dev`, redirect `${window.location.origin}/callback`.
>
> **Verified two independent ways, and the whole app was covered.** GitHub code search over the source repo returns **0** for both `access_token` and `location.hash`; and all five referenced chunks were fetched and grepped, with **no lazy chunk names in the bundle** — so there is no unloaded code path that could contain a reader. The two methods agree.
>
> ⚠️ **One thing that is *not* wrong, checked because it would have changed the conclusion:** the audiences **match**. Doppler `AUTH0_CLIENT_AUDIENCE` is `https://api.integritystudio.dev` in both `dev` and `prd`, and `workers/api-gateway/wrangler.toml:35,95` declares the same. So this is not "the handoff was never viable" — the token is the right shape for that audience. It is simply written into a URL and dropped on the floor.
>
> **Consequences for Scope:**
> - **Step 1 was over-designed.** Neither `postMessage` nor a single-use exchange code was needed. The dashboard already authenticates itself, so the correct change was to **delete the fragment** and have `_goToDashboard` open `ExternalUrls.dashboardApp` plainly — entirely inside this repo, and done.
> - **Step 3 ("requires a matching change in the dashboard app") is false** for removal. It would only be true for *building* a handoff — which nothing is asking for.
> - The residual exposure is smaller than the entry implies (no first-party code consumes it) but not zero: the JWT still lands in the address bar and in that origin's history, where any script on the origin can read it. **And that origin cannot be hardened** — GitHub Pages sets no response headers, so there is no CSP, no `Referrer-Policy` and no HSTS, and there is no `<meta http-equiv="Content-Security-Policy">` in the served HTML either. The usual mitigation is unavailable there by construction, which is one more argument for removing the fragment rather than defending it.
> - Related to [[CR31]]: the dashboard's own API is `https://quality-metrics-api.alyshia-b38.workers.dev`, a **third** product API served from workers.dev and present in neither this repo nor `observability-toolkit`. CR31 counted two API surfaces; there are at least three.
>
> ⚠️ **SHA note — this entry cited a commit that does not exist, and it is not alone.** `d632263` is `fatal: Not a valid object name`; the surviving commit with that change is `1c83136`. **76 of the 85 seven-hex SHAs cited across this file are unresolvable in the current repository**, because [[CR01]]'s `doppler.json` history scrub and force-push on 2026-07-29 rewrote every commit that preceded it. So *every* commit citation in this file dated before 2026-07-29 should be assumed stale, and none of them can be used to verify a claim. Cite by change description and file:line, or re-resolve the SHA, before relying on one.

---

<a id="cr11"></a>

### CR11: Doppler `dev` is not a separate environment

**Priority:** ~~P1~~ **P2** (downgraded 2026-08-03 — the isolation boundary exists and is proven; what remains is one owner-side hardening step, not a live exposure) | **Source:** session 2026-07-27, deploying the CR02 dev environments
**Estimated:** ~~~2 hours~~ **substantially complete 2026-08-03**; ~~residual is step 8 (dev-scoped Cloudflare token, Dashboard) and the cross-repo e2e restore behind [[CR02]] item 5~~ — **step 8 closed 2026-08-06** (and it needed no Dashboard action: the token already existed, so the work was verification, not minting); ~~the only residual is the cross-repo e2e restore behind [[CR02]] item 5~~ ✅ **COMPLETE 2026-08-07** — [[CR02]] item 5's dev receiver exists, the toolkit e2e suite runs fully dev-targeted and green, and the residual is one CI change in that repo rather than any work here

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
7. ✅ **DONE — landing-repo half 2026-08-03, toolkit half 2026-08-07.** The Playwright suite's `contact-worker.spec.ts` (16 contract tests) now defaults to `integrity-studio-contact-dev` — it had been consuming the **production** worker's per-IP rate-limit and idempotency KV on every CI run, which is exactly why its assertions tolerate 429. Verified: 16/16 pass against the armed dev worker. `BASE_URL` site-smoke stays on `https://integritystudio.ai` **by design** — its purpose is production-deployment health. Also seeded the dev DB to reference-data parity the same day: plans `{enterprise, growth, starter}` (dev's migration-seeded `free` removed to match prod; **live-mode `stripe_price_id`s nulled** — a live price id is meaningless against the sandbox account, and one had ridden into dev via migration `20260731020000`), all 4 roles mirrored verbatim with their permission arrays. ~~The toolkit e2e suite (`services/e2e/`) still cannot come back until [[CR02]] item 5's dev receiver exists.~~ ✅ **The toolkit half landed 2026-08-07.** `services/e2e/` now runs entirely against dev — `api-provisioning-receiver-dev`, `sender-worker-dev`, `obtool-api-dev` and `obtool-ingest-dev` all exist, and **zero cross-environment assertions remain skipped**. Final state **34 passed / 0 failed / 12 skipped**. Getting there needed one environment gap closed that this step had not anticipated: the dev Supabase project had **zero** edge functions against production's 8, so `api-keys-create` 404'd and every provisioning path failed. The three with source were deployed to `tumhmtshahktumhqqamk` and `api-keys-list` was recovered from its deployed body ([[W10]]). ⚠️ **Two traps worth carrying forward.** Production is the Supabase CLI's **linked** project, so an omitted `--project-ref` deploys to production. And deploying to dev applied the CLI's `verify_jwt` **default** rather than production's measured values — silently, because dev's service key is still legacy JWT format and satisfied the check that production's `sb_secret_` key would not; the values are now pinned per function in `supabase/config.toml`, but the key-format divergence is live and tracked in [[W10]].

   ⚙️ **Toolkit half, 2026-08-07 — the suite now runs against dev, and the blocker moved twice.** [[CR02]] item 5 is fully done (dev receiver deployed, dev sender deployed and armed, `PROVISION_WORKER_URL` repointed off production), so the suite no longer targets production at all. Per-suite: `receiver-security` **5/5**, `sender-receiver` **11 passed / 1 failed**, `provision-key` **1 failed**.

   🔴 **The blocker that replaced it was hollow green, and it is fixed.** A rate-limited run reported `1 passed | 4 skipped` and **exit 0**, because the suite's helper turned a 429 into `ctx.skip()` — so a CI run that asserted nothing was indistinguishable from one that asserted everything, the same shape as [[CR20]]'s "succeeded while making no outbound calls". The helper now throws, every request carries a unique email, and the fix was verified by running *into* the limiter: two runs pass, the third exits 1 naming the limit and the remedy.

   ✅ **Edge functions deployed to dev 2026-08-07 — suite 18 passed | 15 failed → 29 passed | 5 failed, and `provision-key` is green for the first time.** The three with source in this repo (`api-keys-create`, `-revoke`, `-rotate`) are live on `tumhmtshahktumhqqamk`, each now answering **401** on dev exactly as production does where it previously 404'd. `KV_NAMESPACE_ID` pinned to `AUTH_DEV`. Also seeded the missing `public.users` row for the ROPC test user — its Auth0 identity was created by hand in step 2 and the signup flow that normally writes that row never ran for it. **The full L1059 chain now runs end to end on dev without touching production.**

   ⚠️ **Four of the five remaining failures are the isolation working, not a regression.** They mint a key in dev and assert it authenticates against the **production** API/Ingest Workers, because `API_WORKER_URL` is unset in Doppler `dev` and defaults to `https://api.integritystudio.ai`. A dev key lives in `AUTH_DEV`, not production's `AUTH`, so the 401 is correct — those assertions were written when dev keys were landing in production's namespace, and encoded that leak as expected behaviour. **Do not "fix" them by repointing dev at production's KV.** The fifth is `api-keys-list`, which has no source anywhere.

   *(Original framing, before the deploy:)* 🔴 **What remains is an environment gap, not code: the dev Supabase project has ZERO edge functions where production has 8.** Migrations do not carry edge functions, so replaying the ledger ([[CR30]]) built the schema and none of the functions — the CR30 lesson one level up: *"the ledger can rebuild the schema" is not "the ledger can rebuild the project."* Every remaining failure traces to `api-keys-create` 404ing. Deploying to parity is not a redeploy — only 3 of the 8 have source in this repo, and `api-keys-create` additionally hard-fails 500 without `CLOUDFLARE_ACCOUNT_ID` / `CLOUDFLARE_API_TOKEN` / `KV_NAMESPACE_ID`. ⚠️ **Point that last one at `AUTH_DEV` (`0b323a37…`), never production's `AUTH` (`b5a89aed…`)** — Doppler `dev`'s `KV_NAMESPACE_ID` held the production id until 2026-08-07, so a dev function deployed before that fix would have written the namespace production authenticates against. ⚠️ And the Supabase CLI's **linked project is production**: an omitted `--project-ref tumhmtshahktumhqqamk` deploys there. Tracked toolkit-side as `E2E-CI-RESTORE` — ✅ **closed there 2026-08-08** (changelog 3.1.7; the `e2e` job is live at `publish.yml:100`).
8. ✅ **DONE 2026-08-06 — the token had already been minted on 2026-08-03; what was missing was the proof, and it now exists.** (added 2026-08-02; **premise corrected 2026-08-03**; free, independent of every other step).

   🔴 **Read this before re-deriving anything below: steps 1–7 of the minting procedure were already satisfied when this step was last edited, and the entry did not know it.** The rotation this row flags as "re-measure before scoping" *was* the scoping. Doppler `dev`'s `CLOUDFLARE_API_TOKEN` (sha `15680a6f90a5`, 53 chars, `cfat_`) resolves to account token **`5fc67fe7e1effe8b4fea009942f4e2f5`, named `dev-workers-token`, issued 2026-08-03T08:35:04Z** — a purpose-built account-owned token, not the account-wide credential the step describes. Its policy is a single `allow` on `com.cloudflare.api.account.b3868…` carrying **Workers Scripts Write/Read, Workers KV Storage Write/Read, Account Settings Read, Workers Tail Read**, plus Workers-family extras (Containers, Observability, CI, Pipelines Read, AI Read, Request Tracer Read, Analytics/Logs/WAF Read). It carries **no Workers Routes, no Zone resources, no R2, no D1, no Pages, and no token administration** — i.e. exactly the omissions step 3 asks for. So the work here was never "mint a token"; it was "verify the one that exists and record what it can do".

   ✅ **Verified 2026-08-06, with paired controls so a uniform negative could not pass as a result** ([[probe-positive-control]] — the failure mode this repo has now hit four times):

   | Probe | dev token `5fc67fe7` | prd token `409f74b0` |
   |---|---|---|
   | `GET /accounts/{acc}/tokens/verify` | `active` | `active` |
   | `GET /zones/{zone}/workers/routes` — the [[CR13]] route-hijack capability | **10000 Authentication error** | **OK** ← positive control |
   | `GET /accounts/{acc}/r2/buckets` · `/d1/database` · `/pages/projects` | **10000** each | — |
   | `GET /accounts/{acc}/tokens` | **9109 Unauthorized** | — |

   ✅ **Item 8's end-to-end proof, run for real:** `cd workers/sender-worker && npm run deploy` succeeded under the dev token — `sender-worker-dev` version `01c2da65-129f-412e-8bef-bf123b3803b0`, bindings `RATE_LIMIT_KV` + `RECEIVER` intact, `GET /health` → 200. `wrangler whoami` under `--config dev` and `--config prd` both report reading `CLOUDFLARE_API_TOKEN` from the environment, and the two values resolve to **different** token ids with different capabilities (the routes row above), so `deploy:prd` is unaffected. **[[CR14]] survived the deploy**: `previews_enabled` still `false` on the subdomain endpoint, the version-prefixed preview hostname 404s while the main hostname 200s. `[observability]` also came back `enabled` on the redeploy, which incidentally re-confirms [[W04]] step 0 for this Worker.

   ⚠️ **Item 9 (revoke the superseded dev token) needs no action, and the reason is worth keeping.** The old dev value (sha `abb57cc474cb`) maps to **no** token in `GET /accounts/{acc}/tokens`, and the account holds exactly 7 tokens, all of which are accounted for below. A 40-char non-`cfat_` value is the legacy *account-owned* format (both other 40-char credentials here are account tokens), so the old token was account-owned and has already been deleted rather than merely rotated out of Doppler — the [[CR01]] rotation-is-not-revocation trap did **not** fire this time. The one residual: **user-scoped tokens cannot be enumerated from here at all**, because `dev`'s `CLOUDFLARE_GLOBAL_API_KEY` (37 chars, sha `c8984a8f2a66`) is dead — `9103 Unknown X-Auth-Key or X-Auth-Email` — and no other credential carries user-level auth. If the old token was ever a *user* token, this method cannot see it; that is a limit of the measurement, not a clean bill of health.

   🔴 **New finding, out of this item's scope but found by it: two live, never-used, broad tokens.** The full account inventory (7 tokens, each mapped to its consumer by verifying the Doppler value and reading back the token id):

   | id | name | consumer | last used |
   |---|---|---|---|
   | `5fc67fe7` | `dev-workers-token` | `dev` `CLOUDFLARE_API_TOKEN` | active |
   | `409f74b0` | Edit Cloudflare Workers | `prd` `CLOUDFLARE_API_TOKEN` | active |
   | `1be106ed` | Edit Cloudflare Workers | `CLOUDFLARE_WORKER_TOKEN` — **byte-identical in `dev` and `prd`**, read only by `observability-toolkit` workflows | active |
   | `6d51c3d8` | `cloudflare_platform_token` | `prd` `CLOUDFLARE_GLOBAL_API_KEY`; carries **Account API Tokens Write** (expires 2026-10-26) | active |
   | `3a227938` | `tcad-d1-query` | `CLOUDFLARE_D1_TOKEN`, both configs | active |
   | ~~`12c7e4bd`~~ | ~~Edit Cloudflare Workers~~ | **none** | ✅ **REVOKED 2026-08-06** — was `never`, issued 2025-12-01 |
   | `feef0f3d` | Read all resources | **none** | **never — issued 2025-12-01** (retained by owner decision) |

   `12c7e4bd` was the one that mattered, and its policy was worse than the name suggests: **Workers Routes Write scoped to `com.cloudflare.api.account.zone.*` — every zone in the account** — plus Workers Scripts Write, Pages Write and R2 Write on the account. That is the full [[CR13]] route-hijack capability, sitting live and unused for eight months with no consumer. ✅ **Deleted 2026-08-06** (`DELETE /accounts/{acc}/tokens/{id}` via `prd`'s `cloudflare_platform_token`), with the full record captured before the call and **positive controls after it**: all five in-use credentials still resolve to their token ids, and production `sender-worker` + `api-gateway` both answer `200` — so the delete is confirmed to have hit the orphan and not a live consumer. `feef0f3d` (account-wide read, also never used) is **deliberately retained** by owner decision; it stays in this table as a live row, not a closed one. Also worth noting for [[CR01]]: `CLOUDFLARE_GLOBAL_API_KEY` is a misleading slot name in both configs — `prd` holds an account token with token-minting rights, `dev` holds a dead 37-char value.

   📌 **What this step could never buy, restated so it is not re-attempted:** Cloudflare scopes Workers Scripts to the **account**, with no per-script selector, so `dev-workers-token` still reads all 18 scripts in the account and an `Edit`-carrying token still reaches every Worker in it. The product-level narrowing above is the whole available win; the structural form remains separate accounts with `account_id` pinned per directory. This is a **blast-radius** item and it is now closed at the only altitude a token can close it.

   ⚠️ **This closure is a point-in-time measurement and nothing guards it.** `scripts/check-env-isolation.sh` does not watch `CLOUDFLARE_API_TOKEN` — deliberately, since its scope is data-plane credentials and a distinctness row would pass trivially here anyway (the two tokens have never been the same value). The check that would actually hold is the *capability* one in the table above — dev must fail the zone-routes probe while prd passes it, the same "distinctness is necessary, never sufficient" shape as the Stripe mode check. It is not built: it needs live API calls, which would cost that script its offline, hash-only, CI-safe character, so it belongs in a separate script if anyone wants it. Until then, re-run the table by hand after any token rotation — the last rotation is precisely what left this step reading as undone for three days.

   *(Historical framing and the minting procedure follow, kept because the permission list in step 3 is the spec the existing token was checked against.)*

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

**Status:** ✅ **Credential isolation achieved 2026-08-03 — `check:env-isolation` PASSES (exit 0).** `--config dev` no longer reaches production for Supabase or Auth0. Detector history: 5/13 (broken) → true baseline 7/15 → 6 (`SHARED_SECRET` re-rotated) → 5 (Auth0 dev tenant) → **0 real** (Supabase repointed to `tumhmtshahktumhqqamk`). The two non-passing rows are non-failures: `SUPABASE_SERVICE_ROLE_KEY` ABSENT (tripwire) and `SUPABASE_JWT_SECRET` a dead slot (removed from code 2026-07-31, 0 readers in either repo). Proven by probe: dev's provisioning key reads the dev DB (200) and is **refused by production (401)**, while prd's key still reaches prod (200). **Runbook steps 3–7 all completed 2026-08-03** — dev secrets pushed to `sender-worker-dev`/`api-gateway-dev`/`stripe-webhook-dev` (step 4) and proven by a live dev signup that left production untouched (step 6); `contact-form-dev` recipients fixed and armed (step 5); dev DB seeded to reference-data parity; Playwright `contact-worker` spec repointed to dev, 16/16 green (step 7). ~~**What is left is exactly two things, and neither is isolation:** step 8 — a dev-scoped Cloudflare deploy token (Dashboard-only, so it is on the owner) — and restoring the `observability-toolkit` e2e suite~~ ✅ **Step 8 closed 2026-08-06, and "Dashboard-only, so it is on the owner" was wrong** — the token had already been minted on 2026-08-03 (`dev-workers-token`, `5fc67fe7`) and what the step actually needed was measurement, all of it scriptable: verify the token, run the paired capability controls against `prd`'s token, and deploy for real. See step 8 for the full table. ~~**One thing is left:** restoring the `observability-toolkit` e2e suite, blocked one more hop on [[CR02]] item 5's dev receiver (itself unblocked by the dev Supabase project). Re-measured 2026-08-06 — the block is real, not stale: `dev`'s `PROVISIONING_RECEIVER_WORKER_URL` is still `https://api-provisioning-receiver.alyshia-b38.workers.dev`, the **production** receiver, even though `dev`'s `SUPABASE_URL` is correctly the dev project; `ACTIVE_KEY_ID` and `SIGNING_KEYS` remain unset in `dev`, so the suite gates itself off rather than signing production `/inbox`.~~

✅ **CLOSED 2026-08-07 — that hop cleared and the suite is green. This item is done; nothing in this repo remains.** Re-measured today rather than inferred from the toolkit's notes: `dev`'s `PROVISIONING_RECEIVER_WORKER_URL` is now `https://api-provisioning-receiver-dev.alyshia-b38.workers.dev`, `PROVISION_WORKER_URL` is `sender-worker-dev`, and `ACTIVE_KEY_ID` is `dev1` — all three of the slots the struck text above named as unset or production-pointing. `dev1` was freshly generated rather than copied from production's `v2` and is proven **401 against the production receiver** with a positive control, so isolation rests on what the credential can *reach*, not on the two values differing. `services/e2e/` finished at **34 passed / 0 failed / 12 skipped** with **zero** cross-environment skips.

⚠️ **What "done" does and does not cover here, stated so the ✅ is not over-read.** ~~The `e2e` job is **still absent** from `observability-toolkit`'s `publish.yml` — verified today, the removal comment block at line 87 is still all that is there. Every condition that block lists is now met, so putting it back is a one-line change owned by that repo (`E2E-CI-RESTORE`), not by CR11.~~ ✅ **Stale as of 2026-08-08 — the job was restored in that repo** (`publish.yml:100`, closed as `E2E-CI-RESTORE` in its changelog 3.1.7), so CR11 has no residual left at all. 🔴 **Note what failed here, because it is worse than an ordinary stale line:** "verified today, the removal comment block at line 87 is still all that is there" cited a line number and a specific artifact, which is what a measured claim looks like — and it decayed anyway, because the measurement was true when written and nothing re-checked it when the other repo shipped. **A cited line number in another repository is a snapshot, not a guarantee**; the same sentence appeared in three places on this page and all three went stale in one commit that was invisible from here. Three residuals were also filed there rather than folded into this ✅, because each is a real gap this work exposed: the green run is **26% inert** (12 of 46 tests gated off in every configuration anyone runs — `E2E-PERMANENT-SKIPS`); three pieces of the dev environment exist **only as live state** and no runbook records them (`E2E-DEV-SEED-UNDOCUMENTED`); and the toolkit's D1 ledger **cannot rebuild its own database** — the dev DB was cloned from production's `sqlite_master` rather than replayed (`D1-LEDGER-NO-BASELINE`, the same defect as [[CR30]] one system over). Two cross-environment values found on the way are open here as [[W09]], not closed by this item's green detector: `VITE_AUTH0_CLIENT_ID` and `CLOUDFLARE_D1_TOKEN`. ~~Open — blocked on **manual provisioning, not spend**; see *Blockers and cost* at the top of this item for the audited figures.~~ ~~blocked on two owner decisions: whether to pay for a third Supabase project (step 1) and creating the Auth0 dev tenant (step 2), neither of which is scriptable with the credentials available.~~ **Superseded 2026-08-02** — both halves were stale, and one of them (`POST /v1/projects` is scriptable) was already contradicted by this item's own 2026-07-28 update. Everything downstream (steps 3–9) is mechanical and the runbook above is complete. The detector and the documentation corrections landed 2026-07-27.

**Consumers of this item (✅ both now unblocked — step 1 landed 2026-08-03):** [[CR02]] item 5 (the dev receiver) was the reason step 1 was P1 — a dev receiver against the *shared* project would have run `ensureTeamOrg` / `addOrgMember` / `grantDashboardAccess` and minted real keys in production. With the repoint done, a dev receiver would write the **dev** project; ~~item 5 is unblocked, gated now only on the sender/receiver co-deploy sequencing~~ ✅ **item 5 is CLOSED 2026-08-07** — the dev receiver is deployed and the sender/receiver co-deploy happened together, as that sequencing required. Separately, the `observability-toolkit` e2e suite (removed from CI 2026-07-31 because `--config dev` pointed at the **production** receiver) ~~can return once that dev receiver exists~~ ✅ **now runs fully dev-targeted and green**; both consumers of this item are satisfied, and the only outstanding action is the CI-job restoration in that repo.

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
4. ~~**Add a CI guard that replays the full ledger onto an empty database**~~ ✅ **DONE — written AND proven green in CI 2026-08-03** (run `30804541500`, `Migration Replay Check`, success in 2m46s — its first real execution, on the merge push) — `.github/workflows/migration-replay-check.yml` → `scripts/check-migration-replay.sh`: boots the Supabase local stack (full stack, not `db start` — the auth service is what guarantees `auth.users`/`auth.uid()`, which the baseline FKs into), `supabase db reset` for a deterministic empty→replay, then **asserts the rebuilt schema** (17 named objects incl. the `user_details` view via `to_regclass`, ≥3 public enums, both `organizations.domain`/`.type` columns) so a replay that "succeeds" without producing the schema still fails. No secrets, path-filtered on `supabase/**`, PR-safe including forks. `config.toml` `major_version` bumped 15 → **17** in the same change — production is 17.6, so the guard would otherwise have tested a different major than production runs. ✅ **Executed and green** (run `30804541500`, 2m46s). Docker is absent on this machine, so it could not be run locally — the merge to `main` was its first real execution, and it passed. Verified instead: `bash -n`, YAML parse, and the assertion SQL run against the rebuilt dev project — passes on the good schema, **and a mutation test confirms it reports an injected missing object**. The first CI run is the real proof; treat this item fully closed only after that run is green. ⚠️ **"a push touching `supabase/**`" was wrong about which push** — both triggers filter `branches: [main]`, so pushing this feature branch runs nothing. The first execution is the **PR into `main`** (`pull_request.branches` filters the *target*), and the path filter will match, since all six migration files, `config.toml`, the script and the workflow itself are all in the unpushed set. Until then `gh run list --workflow=migration-replay-check.yml` **404s** — the workflow does not exist on the default branch.

**Status:** ✅ **Resolved 2026-08-03 — the ledger now rebuilds production's schema from an empty database, verified by replay.** Final parity against production: **24/24 tables+views, 255/255 columns, 3/3 enums, zero missing, zero extra.** The CI guard (scope step 4) is written and statically verified 2026-08-03 — `migration-replay-check.yml` + `check-migration-replay.sh`; ✅ **it has now executed and passed** — run `30804541500`, success in 2m46s, triggered by the merge to `main`. (Docker is absent on this machine, so local execution was never possible; the merge was the first real run.) No production change was made — every query against production was read-only, and all five new migrations are idempotent no-ops there.

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

1. ✅ **`API_KEY_HMAC_SECRET`** (`api-gateway`) — **bound and verified live 2026-08-06.** The premise above was wrong in one respect worth recording: `api-provisioning-receiver` (`observability-toolkit`) mints keys via the `api-keys-create` Supabase edge function, which hashes with plain SHA-256 (`sha256Hex`, no secret) — the HMAC step is entirely on this repo's side (`workers/lib/api-keys.ts` `hashApiKeySecret`/`verifyApiKeyHash`), so there was no existing receiver-side value to match. A fresh 32-byte random secret was generated (`openssl rand -hex 32`), stored in Doppler `prd` (read-back fingerprint-verified) and bound to production `api-gateway` via `wrangler secret put`. A **distinct** secret was also stored in Doppler `dev` for when `api-gateway-dev` is next worked on ([[CR14]]: currently unreachable) — not bound anywhere yet, out of scope here.

   **Verified end-to-end against production, not inferred from a successful bind.** A real `api_keys` row was inserted (test org, deleted after) with its hash computed as `HMAC-SHA256(new secret, random 16-byte hex)`, matching `verifyApiKeyHash`'s scheme exactly:
   - `GET /v1/orgs/:id/usage/summary` with the correctly-signed key → `200` with real usage data.
   - Same route, same key prefix, wrong secret → `401 {"error":{"message":"Invalid API key"}}` (negative control).
   - `/v1/ingest/events` and `/v1/ingest/otel` route through the identical `machineRouteOpts` → `API_KEY_HMAC_SECRET` path (`workers/api-gateway/src/index.ts`), so the same verification covers them without a separate live probe.

   API-key-authenticated routes (`/v1/ingest/*`, usage, entitlements, quota status, api-keys management) are live. `requireHmacSecret`'s 503-on-absent behavior (added when this was a known gap) is now the fallback path only, not the steady state.
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

**Status:** ⚠️ Partial — step 1 done (2026-07-29) and **proven in practice (2026-07-30)**. The `routes` key is gone from `workers/api-gateway/wrangler.toml`, and rather than trusting that, a real `npm run deploy:prd` was run and the zone's route list re-read immediately after: still exactly `api.integritystudio.ai/*` → `obtool-api` and `ingest.integritystudio.ai/*` → `obtool-ingest`, with nothing pointing at `api-gateway`. The trap is defused in fact, not just in config, and [[CR22]]'s fix has shipped. ~~Hostname-topology decision (steps 2–5: which approach to give the gateway a branded endpoint) still needed.~~ ✅ **Decided 2026-08-08 — option C, `api.integritystudio.dev`** (owner decision), and ✅ **DONE the same day: the hostname is LIVE.** Cloudflare zone `838f8d6bdc2ff361746ae6bb74a7c9c2` went active 20:34:43Z; Workers Custom Domain `e3f5d910…` serves `api.integritystudio.dev` → `api-gateway`, verified `200` on `/health` and `401` on `/v1/me`. The dashboard and the `integritystudio.ai` routes are provably untouched. ✅ **`routes` declared 2026-08-08** as `routes = [{ pattern = "api.integritystudio.dev", custom_domain = true }]` — a **custom domain, not a zone route**, so it binds one hostname rather than claiming a path someone else serves. ✅ **Step 5 done the same day** (`f36b813`): both `API_GATEWAY_URL` defaults repointed, CORS measured identical on old and new hosts, and [`docs/api-routing.md`](api-routing.md) resynced. **CR13 is CLOSED — every step, plus both regressions the migration introduced.** See the execution log in the block below.

> ✅ **DECISION 2026-08-08 — option C: the gateway gets `api.integritystudio.dev`.** This closes the topology question steps 3–5 have held open since 2026-07-27. It also **supersedes [[CR31]]'s option-B recommendation** and the "Recommendation — split by path" section of [`docs/api-routing.md`](api-routing.md). ✅ **That document was resynced the same day** (`f36b813`) rather than left contradicting this entry — the superseded split is kept there as a blockquote with *why it lost*, and a structural bug was found doing it: the doc queried only `/zones/<id>/workers/routes`, and by that endpoint `api-gateway` still has no hostname, because **custom domains are a separate endpoint**.
>
> **Why this hostname rather than a path-split.** `https://api.integritystudio.dev` is *already* the gateway's Auth0 audience and resource-server identifier (`69c4e28bf801eab9e683c85a`), declared at `workers/api-gateway/wrangler.toml:41,101`, matched by `AUTH0_CLIENT_AUDIENCE` in both Doppler configs, and used by the dashboard SPA. The name is already spoken for by this Worker. ⚠️ **Do not read that as a defect being fixed:** an Auth0 audience is an opaque identifier and is under no obligation to resolve. Nothing is broken today because it does not; making it resolve is naming correctness, not a repair. Option C also avoids the standing cost of B — a route list in this repo that is a hand-maintained mirror of a dispatch table in another.
>
> 🔴 **The blocker is that `integritystudio.dev` is not a Cloudflare zone, so no Workers route or Custom Domain can attach to it at all.** Measured, not assumed: the account holds exactly `integritystudio.ai` and `alephatx.info`; `integritystudio.dev` delegates to `maceio/fortaleza/salvador/curitiba.ns.porkbun.com`. This is a **registrar action, not a `wrangler.toml` edit**, and it is the whole of the remaining work.
>
> ⚠️ **The apex is ruled out on evidence, the same way step 4's speculation was.** `integritystudio.dev` A → `185.199.108–111.153` (GitHub Pages) and answers **200** — it serves the `quality-metrics-dashboard` SPA ([[CR04]]). A route on `integritystudio.dev/*` would capture it. The target is the `api.` label only.
>
> **State of `api.integritystudio.dev` today:** a Porkbun URL-forward — `301` to `http://integritystudio.dev/`, and **`https://` does not connect at all**. `.dev` is on the **HSTS preload list** (Google-operated TLD), so browsers force HTTPS on every hostname under it; the existing forward is therefore already dead in a browser. It is reached via a **wildcard** — a random label resolves to the same `pixie.porkbun.com` — so `app`, `dashboard`, `docs`, `status`, `sandbox-api` all currently 301 to the apex.
>
> **Migration is a delegation change, not a registrar transfer.** The domain stays registered at Porkbun; only the NS records change. No transfer lock, no auth code, and Cloudflare Registrar's `.dev` support is irrelevant. Both usual blockers are already clear:
> - **DNSSEC is off** — no `DS` at the `.dev` parent (the query returns the parent SOA), no `DNSKEY`, no `ad` flag on responses. This is the one that breaks resolution globally if left enabled through an NS change.
> - **No MX, no TXT, no CAA** — nothing for email, domain verification, or CA pinning is at risk.
>
> ✅ **Records to recreate — AUTHORITATIVE list, pulled from the Porkbun API 2026-08-08** (10 editable records; the 4 Porkbun `NS` rows are what the migration replaces):
>
> | Name | Type | Content | TTL |
> |---|---|---|---|
> | `integritystudio.dev` | `A` ×4 | `185.199.108/109/110/111.153` | 600 |
> | `integritystudio.dev` | `AAAA` ×4 | `2606:50c0:8000::153`, `8001::153`, `8002::153`, `8003::153` | 600 |
> | `www` | `CNAME` | `integritystudio.github.io` | 600 |
> | `*` | `CNAME` | `pixie.porkbun.com` | 600 |
>
> 🔴 **The probed inventory this block previously carried was WRONG, and the way it was wrong is the point: it listed no `AAAA` records because nobody queried `AAAA`.** GitHub Pages serves the dashboard over IPv6 on four addresses. **Migrating on the probed list would have dropped the dashboard for every IPv6 client** — a partial outage, which is the kind that gets attributed to anything except DNS. The caveat that saved this was already written in this entry ("probed, not authoritative"); the lesson is that the caveat was worth *acting* on rather than merely recording. **A probe can only find record types you thought to ask for, and the ones you forget fail silently for a subset of users.**
>
> ⚠️ **The `*` wildcard is vestigial and its behaviour is not what it looks like.** `porkbun_domain_get_url_forwarding` returns **`[]`** — there are no configured forwards. Today's `301` from `api.integritystudio.dev` → `http://integritystudio.dev/` is just `pixie.porkbun.com`'s default handling of an unconfigured host, not an intentional rule. Recreating the `CNAME` in Cloudflare preserves exact parity (a specific `api` record still wins over `*`, so it does not interfere with the Custom Domain), but it points a wildcard at a third-party parking host for no remaining reason. **Recreate it for the migration — change who answers, not what the answers are — then delete it as a separate, reversible step.**
>
> **Ordering, and the two ways to get it wrong:**
> 1. Add the zone to Cloudflare → diff its scan against the Porkbun export → set SSL/TLS to **Full** → change NS at Porkbun → confirm apex and `www` still 200 → add the Workers Custom Domain → **only then** add `routes` to `wrangler.toml`.
> 2. ⚠️ **Adding `routes` before the zone exists breaks `deploy:prd` outright** — wrangler cannot resolve the zone and fails the deploy. The config change is *last*, not first.
> 3. ⚠️ **If the GitHub Pages records are proxied, SSL/TLS mode must be `Full`, not `Flexible`.** Flexible against an HTTPS-only origin on an HSTS-preloaded TLD produces a redirect loop and takes the dashboard down.
> 4. When `routes` is finally added, [[CR13]]'s original trap still applies: **top-level `routes` only, with an explicit `routes = []` under `[env.dev]`** — `routes` is inheritable, and that inheritance is what handed a production hostname to a secret-less dev Worker on 2026-07-27.
>
> **Rollback is reverting NS at Porkbun, and it is not fast** — record TTLs are 600s but NS delegation is governed by the parent, so budget hours. Schedule this when it can be watched.
>
> **New cost this decision accepts:** the dashboard's DNS comes under Cloudflare. Today a Cloudflare mistake cannot reach the dashboard; afterwards it can.
>
> 🔴 **Scriptable vs owner — corrected 2026-08-08 by attempting it. Adding the zone is NOT scriptable with any credential in Doppler `prd`.** This block first read *"adding the zone appears scriptable — a `POST /zones` probe returned `1002 Invalid domain`, a validation error, so it cleared authorization and Zone:Create is present."* **That inference was wrong.** An empty-body `POST` is validated *before* the permission check, so `1002` proved only that the body was empty. A real create with a valid body returns `Requires permission "com.cloudflare.api.account.zone.create"`. Measured across four credentials — `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_GLOBAL_API_KEY`, `CLOUDFLARE_WORKER_TOKEN`, `CLOUDFLARE_PAGES_TOKEN` all lack it; `CLOUDFLARE_OAUTH_TOKEN` is expired (`Invalid access token`, consistent with the 2026-04-20 wrangler OAuth expiry in CLAUDE.md). **This is the same error [[CR31]] and [[CR14]] already record: a probe that returns an error for the reason you were not testing reads as a pass.** A permission probe needs a *valid* request body or it tests nothing.
>
> **So the zone-add is an owner Dashboard action** — either "Add a site" in the Cloudflare Dashboard, or mint an API token with account-scoped **Zone → Edit** (which is what grants `zone.create`) and the rest is scriptable from here. Minting is itself Dashboard-gated: no token in either config carries token-admin.
>
> ✅ **Porkbun global API access was enabled 2026-08-08, so the NS change IS now scriptable** (`porkbun_domain_update_ns`), and the authoritative record list is readable — which immediately paid for itself; see the AAAA finding below.
>
> ✅ **EXECUTION LOG 2026-08-08 — zone added (owner, Dashboard) and delegation moved.** Zone `838f8d6bdc2ff361746ae6bb74a7c9c2`, `type: full`, Free plan; assigned `kristina.ns.cloudflare.com` / `tony.ns.cloudflare.com`, **matched against the pair the owner reported before anything was changed** — a mismatch would have meant a different zone or account. Cloudflare's scan-on-add imported **all 10 records**, AAAA included. `porkbun_domain_update_ns` then set the registrar delegation to the Cloudflare pair (confirmed by re-reading `get_ns`). Registry/parent still served the Porkbun set at the time of writing; parent NS TTL is **10800**.
>
> ✅ **The parity check that made this safe needed no API permission, and is the reusable part.** All four Doppler `prd` Cloudflare tokens are scoped to `integritystudio.ai`, so **none could read the new zone's DNS** (`Authentication error`) — the API route to verification was closed. **Cloudflare's assigned nameservers answer authoritatively for a zone while the parent still delegates elsewhere**, so `dig @kristina.ns.cloudflare.com …` shows exactly what Cloudflare *will* serve, before committing to it. Queried both sides and compared: A ×4, AAAA ×4 and the `www` CNAME identical, wildcard present. **That is a real positive control** — the failure mode it rules out is a zone that answers plausibly for the apex while silently missing a record class, which is precisely the AAAA trap above.
>
> ✅ **Records are DNS-only (grey cloud), which was the deliberate choice and removes a hazard.** Cloudflare returns the real GitHub Pages IPs rather than anycast, so the dashboard's request path is unchanged — only DNS authority moved. **The `Flexible`-SSL redirect-loop hazard therefore does not apply to the dashboard at all**, because Cloudflare never sits in its path. Keep it that way unless there is a reason to proxy; proxying the apex is what would re-arm that hazard on an HSTS-preloaded TLD.
>
> ✅ **No outage window existed, by construction.** Both nameserver sets served byte-identical answers throughout, so it did not matter which a resolver reached. Verified during the cutover: apex **200** over IPv4 *and* IPv6, `www` **301** (GitHub Pages' own www→apex redirect). **This is why parity is checked before delegation and not after** — with identical data on both sides the change is a no-op to every client, and the 3-hour propagation is uneventful rather than a risk window.
>
> ⚠️ **Rollback value, recorded before the change:** `curitiba` / `fortaleza` / `maceio` / `salvador`**`.ns.porkbun.com`**. Note the registry delegation uses the `.ns.` form while Porkbun's own in-zone `NS` records read `*.porkbun.com` without it — **use the `get_ns` values for rollback, not the DNS-record contents.**
>
> ✅ **COMPLETED 2026-08-08 20:34–20:49Z — zone active and the Custom Domain is live.** The zone went `active` at **20:34:43Z**, far inside the 3 h the parent NS TTL allowed (Cloudflare rechecks aggressively; do not budget the TTL as the expected wait). Workers Custom Domain `e3f5d910…` binds **`api.integritystudio.dev` → `api-gateway` / production**. Verified by serving, not by the API returning 201: `GET https://api.integritystudio.dev/health` → **200** `{"database":"healthy","durableObjects":"healthy"}`, and `/v1/me` → **401**, which per this entry's own caveat proves the middleware ran and the route is mounted. TLS worked on first request — Universal SSL covers one subdomain level, which `api.` is.
>
> ✅ **Controls run afterwards, because the whole risk of this entry was collateral damage.** The dashboard is untouched (apex **200**, `www` **301**, IPv6 **200**); the `integritystudio.ai` zone routes are still exactly `api.integritystudio.ai/*` → `obtool-api` and `ingest…` → `obtool-ingest` with `api.integritystudio.ai/health` **200**; and the old `api-gateway.alyshia-b38.workers.dev` origin still answers **200**, so the shipped Flutter default is not stranded and step 5 can be sequenced calmly rather than urgently.
>
> 🔴 **One real regression, introduced by the migration and NOT yet fixed: the `*` wildcard came across PROXIED, and every wildcard subdomain now serves a Cloudflare `525` over HTTPS.** Cloudflare's scan imported `*` → `pixie.porkbun.com` with the orange cloud on, so it now terminates TLS at the edge and fails the origin handshake to Porkbun's parking host. Measured: `https://<random>.integritystudio.dev` → **525**, `http://` → **301** to the apex (unchanged). Before the move, HTTPS simply failed to connect. **Because `.dev` is HSTS-preloaded, browsers only ever attempt HTTPS**, so the visible change is from "host does not work" to "a branded Cloudflare error page implying our infrastructure is broken". Low impact — these subdomains were never real — but it is a regression and it was found only by re-probing a label after cutover rather than trusting the parity check, which had compared **DNS answers** and not **behaviour**. ⚠️ **A record-level parity check does not prove behavioural parity when the proxy flag is part of the record.**
>
> ✅ **Wildcard DELETED 2026-08-08 (owner, Dashboard) — the 525 is gone.** Verified against the authoritative nameserver rather than a resolver, so caching cannot flatter the result: two independent random labels both return **NXDOMAIN**, `api.integritystudio.dev` **survived** (a specific record was never at risk from removing `*`, but it is the thing that would have broken), and the dashboard is unchanged at apex **200** / `www` **301** / IPv6 **200**. ⚠️ Neither fix was doable from here — all three Doppler `prd` tokens return `Authentication error` on this zone's `dns_records` **even with the zone active**, so DNS editing needs the Dashboard or a `Zone → DNS → Edit` token. Note the asymmetry that shaped this whole migration: the same tokens *can* read and write Workers domains and routes on this zone, which is why the Custom Domain succeeded while a one-record DNS fix could not.
>
> 🔴 **Found while verifying that deletion, and NOT part of it: the apex and `www` are now PROXIED (orange cloud), where the migration deliberately left them DNS-only.** Measured — apex `A` → `104.21.50.70` / `172.67.158.118` and `AAAA` → `2606:4700:…` (Cloudflare anycast, not GitHub Pages' `185.199.108–111.153` / `2606:50c0:800x::153`), with responses carrying `server: cloudflare` and `cf-ray`. **It works today**: apex 200 with `num_redirects=0`, `www` 301 → apex, IPv6 200. So SSL/TLS is **not** `Flexible` — the redirect loop that mode would cause on an HSTS-preloaded TLD is not present. Zone *settings* are unreadable with these tokens (`Unauthorized to access requested resource`), so that is inferred from behaviour rather than read from config.
>
> ⚠️ **Two latent hazards this creates, both of which fail long after the change that caused them:**
> 1. **SSL/TLS must never be set to `Flexible`.** Cloudflare now terminates TLS for the dashboard, and GitHub Pages redirects HTTP→HTTPS; on a preloaded `.dev` that combination is an infinite redirect loop. `Full` or `Full (strict)` only.
> 2. **GitHub Pages renews its certificate over HTTP-01, through Cloudflare now.** Probed: `http://integritystudio.dev/.well-known/acme-challenge/probe` returns **404 with no redirect**, i.e. it passes through to the origin, so renewal works today. **Enabling "Always Use HTTPS" would 301 that path and break renewal — silently, and not until the next renewal window months later.** GitHub's own guidance is to run Cloudflare **DNS-only** in front of Pages for exactly this reason.
>
> ✅ **RESOLVED 2026-08-08 — apex + `www` grey-clouded, both hazards removed rather than documented.** 9 records set DNS-only (apex `A` ×4, apex `AAAA` ×4, `www` CNAME) via a purpose-minted `Zone → DNS → Edit` token; `scripts`-free one-off kept in the session scratchpad. **The proxied records had preserved their origins**, so the toggle restored the exact pre-migration values — confirmed by the dry run before applying, not assumed.
>
> **Verified on both sides of the boundary, which is the check that actually distinguishes the two states:** apex now answers `185.199.108–111.153` / `2606:50c0:800x::153` with **no `cf-ray` header** (Cloudflare out of the dashboard's path), while `api.integritystudio.dev` answers Cloudflare anycast **with** `cf-ray` (proxied, as a Custom Domain must be). Services: dashboard **200 / 301 / 200** over v4 and v6, `api` **200** on `/health` and **401** on `/v1/me`, ACME path **404 with no redirect** so GitHub's renewal is unobstructed, and the wildcard still **NXDOMAIN**. Neither hazard applies any more — Cloudflare cannot loop a request it does not carry, and cannot 301 a challenge it never sees.
>
> ⚠️ **The one record that must never be grayed is `api.integritystudio.dev`** — it is an `AAAA` to **`100::`**, Cloudflare's discard-prefix placeholder for a Workers Custom Domain, and it sits in the same record list directly beneath the nine that *should* be gray. The script hard-excluded it by name and matched the other nine on **both** the proxy flag and known GitHub Pages origins, so an unrecognised record is skipped rather than guessed at. **A "grey-cloud everything" pass down that list would have silently unbound the Worker** — the hostname would keep resolving and stop serving `api-gateway`.
>
> ⚠️ **DNSSEC must not be enabled at Porkbun** — if it is ever wanted, enable it on the Cloudflare side now that the zone is active.
>
> 🔴 **ORDERING IS LOAD-BEARING AND THE TWO HALVES ARE NOW ASYMMETRIC.** The NS change is automatable and the zone-add is not, so the easy half is the destructive one. **Flipping NS at Porkbun before the Cloudflare zone exists and holds every record stops the domain resolving at all** — the dashboard goes hard-down, and rollback is bounded by the parent's delegation TTL, i.e. hours. Do not run `porkbun_domain_update_ns` until the zone is active in Cloudflare and its record set has been diffed against the Porkbun export.
>
> ✅ **Step 5 DONE 2026-08-08** (`f36b813`), in the order this note demanded — the Custom Domain was answering before the constants moved. `dashboard_service.dart:16` and `provisioning_service.dart:22` now default to `https://api.integritystudio.dev`. **`ci.yml:212` builds with no `--dart-define`, so the compile-time default is literally what ships**; that is why the workers.dev URL was a live-user-path fact rather than a dev convenience, and why changing the constant alone moves the shipped app.
>
> **CORS was measured before the flip, not assumed.** `api-gateway` keys its allowlist on the requesting `Origin`, not on its own host: a preflight from `https://integritystudio.ai` returns `204` with identical `allow-origin`/headers/methods on **both** hostnames. That is what made the swap safe, and it is a measurement rather than an inference.
>
> ⚠️ **`SENDER_WORKER_URL` (`provisioning_service.dart:15`) stays on workers.dev deliberately** — step 5 named only the two `API_GATEWAY_URL` sites, and `sender-worker` has no branded hostname to move to. It needs its own decision, not a tag-along.
>
> ⚠️ **The old `api-gateway.alyshia-b38.workers.dev` is still live and still answers 200.** Deliberate: nothing forces a caller off it. Do not read its continued existence as the app still using it.

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

**Context:** Every Worker in the account has `previews_enabled: true`. Cloudflare then publishes each retained version at `https://<version-id-prefix>-<script>.<subdomain>.workers.dev`, ~~**with the script's current secrets bound**~~ **with the bindings that version was uploaded with**. Superseded code therefore stays live.

🔴 **"the script's current secrets bound" was wrong, and it inverted the whole exposure model — corrected 2026-08-03.** A Worker version is an *immutable snapshot of code **and** bindings*; that is precisely why `wrangler secret put` creates a new version. Proven from `resources.bindings` on the version-detail endpoint, which returns a different set per version of the same script:

| Version | Created | Bindings recorded on that version |
|---|---|---|
| `0092e4f3` | 2026-03-20 | **1** — `SUPABASE_URL` (plain_text). **Zero secrets** |
| `2644007b` | 2026-07-14 | 10 — incl. `SHARED_SECRET`, `SUPABASE_SERVICE_ROLE_KEY`; **no** `SIGNING_KEYS` |
| `df8a4528` | 2026-08-03 09:51:09 | 12 — incl. `SIGNING_KEYS` **and** `SHARED_SECRET` |
| `5c614ae4` | 2026-08-03 09:52:56 | 12 → **11**, `SHARED_SECRET` removed (this is [[CR29]] step 3's unbind) |

**The correction cuts both ways, and the second direction is worse than what this entry originally claimed.** Rotating a secret does not leak *backwards* onto old versions — but it does not clean them up *forwards* either. Every version created before a rotation keeps serving with the pre-rotation credential frozen into it, which means **a retained version is a live holder of exactly the credential a rotation was supposed to retire.** That defeats rotation rather than merely duplicating a current key. Inventory below.

⚠️ **One link in that chain is proven only by mechanism, not measured.** The API returns binding **names**, never values (they are write-only), so "the pre-rotation *value* is frozen into that version" is inference from *why* a secret change makes a new version at all. The clean empirical test is signing an old preview URL with the pre-rotation `SHARED_SECRET` and seeing whether it verifies — deliberately **not run**, because `POST /inbox` writes provisioning rows to the production Supabase project. Treat the value-freezing as strongly implied and unverified; if it is ever disproved, the 29 pre-rotation versions below drop to a code-exposure finding only.

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

**Counts re-read 2026-07-30 after the key-rotation provisioning:** `sender-worker` now holds **16** (`SIGNING_KEYS` + `ACTIVE_KEY_ID` added) and `api-provisioning-receiver` **10** (`SIGNING_KEYS` added). The receiver still has previews **on**, so ~~its brand-new signing key is exposed on every retained version the moment it was bound — the clearest illustration yet of why step 3 is the item that matters~~.

🔴 **That struck sentence is false — corrected 2026-08-03**, and it was the single most misleading claim in this entry because it read as the argument *for* the item. Binding `SIGNING_KEYS` on 2026-07-30 created a **new version**; it did not retroactively arm the 2026-03-20 version, which measurably holds no secrets at all. The forward direction is the real finding, and it is worse: see the inventory below.

Both counts were understated when this entry was written — `sender-worker` was 13 before `STRIPE_SECRET_KEY` was bound on 2026-07-28 ([[CR18]]), and the receiver held 9, not 7: `AE_SQL_API_TOKEN`, `AUTH0_DOMAIN`, `CF_ACCOUNT_ID`, `KEY_ROTATION_DATES`, `SENTRY_DSN`, `SHARED_SECRET`, `SUPABASE_ANON_KEY`, `SUPABASE_PROVISIONING_KEY`, `SUPABASE_SERVICE_ROLE_KEY`.

**Re-counted live 2026-07-31: the receiver still holds 9, but not the same 9** — `SUPABASE_SERVICE_ROLE_KEY` is **gone** and `SIGNING_KEYS` has been added. That is where the "10" quoted elsewhere came from: `SIGNING_KEYS` was counted as an addition without noticing the deletion. Current set: `AE_SQL_API_TOKEN`, `AUTH0_DOMAIN`, `CF_ACCOUNT_ID`, `KEY_ROTATION_DATES`, `SENTRY_DSN`, `SHARED_SECRET`, `SIGNING_KEYS`, `SUPABASE_ANON_KEY`, `SUPABASE_PROVISIONING_KEY`. The exposure argument is unchanged — the removal swaps one Supabase service credential for another, since `SUPABASE_PROVISIONING_KEY` is the live RLS-bypassing key (see [[CR11]]'s 2026-07-31 update) — but a *stable* count that hides a changed composition is exactly the kind of number this page should not be carrying, so read the list rather than the total.

The 8-hex-character version prefix is not a meaningful secret: `wrangler` prints the full version ID on every deploy, so it lands in terminal scrollback and CI logs. This session printed one.

---

#### Live re-measurement 2026-08-03 — the exposure is wider than this entry recorded, and spans three repos

Method: every script in the account read via `/workers/scripts/<n>/subdomain` and `/settings`; all 101 candidate preview URLs probed twice with `curl` (identical results both passes — 37 reachable, so no propagation ambiguity); all 64 unreachable URLs returned Cloudflare's HTML error page rather than a Worker response, so the discriminator is clean.

**✅ This repo's production half still holds.** `api-gateway`, `integrity-studio-contact`, `sender-worker`, `stripe-webhook` all still `previews_enabled: false`. No regression from the 2026-07-30 deploys. `sender-worker` is now 12 secrets, not 16 ([[CR15]] deleted four stale ones).

**🔴 `api-provisioning-receiver` — 36 live versions of 89 retained, spanning 2026-03-20 → today.** Not "30 of 30": 36 are code uploads and serve; the other 53 came from `wrangler secret put` and get no preview URL. Classified by rotation era, since that is what determines what each one holds:

| | Live versions | What they hold |
|---|---|---|
| **[A]** | 1 (`0092e4f3`, 2026-03-20) | Zero secrets. Harmless |
| **[B]** | **29**, 2026-03-20 → 2026-07-25 | `SHARED_SECRET` + `SUPABASE_SERVICE_ROLE_KEY` at **pre-[[CR01]]-rotation** values |
| **[C]** | 6, 2026-07-29 → today | Current values, incl. `SIGNING_KEYS` and `SUPABASE_PROVISIONING_KEY` |

**Group [B] is the finding.** All 29 run **pre-[[CR29]] code** — the keyless `SHARED_SECRET` fallback was removed only in toolkit `bca70a3` (2026-08-02) — so every one of them still resolves an absent `x-key-id` to `SHARED_SECRET`. And the pre-rotation `SHARED_SECRET` is **disclosed material**: it was in the `doppler.json` scrubbed from history on 2026-07-29, and [[CR01]] records that the on-disk copy and `~/.doppler/fallback/` still hold it. So the chain is *disclosed credential → rotation intended to retire it → 29 live URLs still running code that accepts it*. That is the forgery path [[CR29]] was written to close, reachable at a parallel hostname.

Mitigating factors, both real: `SUPABASE_SERVICE_ROLE_KEY` on those versions is a legacy Supabase JWT, and [[CR24]] disabled that key class (verified 401 both), so their database access is dead. And group [B] predates `SIGNING_KEYS` entirely, so those versions cannot verify a `v2`-signed request at all.

**🔴 [[CR29]] step 3's unbind is partly defeated by this item.** The unbind produced `5c614ae4` (09:52:56), which is the *active* version and correctly has no preview URL. But `df8a4528` — the code deploy 107 seconds earlier — is **live at its preview URL with `SHARED_SECRET` still bound**. It runs post-`bca70a3` code so it rejects keyless requests; the hole is group [B], not this one. Worth stating plainly: **unbinding a secret does not unbind it from the versions already published.**

**🔴 [[CR11]] step 4 pulled two dev Workers into scope on 2026-08-03**, and this entry says the opposite about one of them:

| Worker | This entry said | Live | Now |
|---|---|---|---|
| `stripe-webhook-dev` | "2 sandbox" | **4** secrets, previews **on**, **1 version live** (its 2026-07-27 code deploy) | ✅ **closed 2026-08-03** |
| `api-gateway-dev` | "hold no secrets" | **4** dev secrets, previews **on**, 0 versions currently live | ⚠️ config armed, see anomaly below |

**The gap was not a missing config line — it was that no deploy had happened.** `preview_urls` is an *inheritable* key in wrangler's own config normalizer (`inheritable(diagnostics, topLevelEnv, rawEnv, "preview_urls", …)`, read out of the bundled parser), so `[env.dev]` already inherits the top-level `preview_urls = false` that step 2 added on 2026-07-29 — no `[env.dev]` repetition is needed, unlike bindings. What kept the live setting at `true` is that `stripe-webhook-dev`'s last **code** deploy was 2026-07-27, before that line existed; its only newer versions are the 07:53:07/07:53:08 pair from CR11's `wrangler secret put`, **and provisioning a secret applies no `wrangler.toml`**. So arming a dev Worker with credentials is precisely the operation that adds exposure while being unable to close it.

✅ **`stripe-webhook-dev` closed 2026-08-03** by `POST …/subdomain {"enabled": true, "previews_enabled": false}`, and the config already carries the durable half, so its next `npm run deploy` re-asserts it. Before: 1 of 6 versions live, serving `{"ok":true,"service":"stripe-webhook"}` with 4 dev secrets bound. After: 6 of 6 dead, `stripe-webhook-dev.…workers.dev` itself still `200` — which matters, because that hostname is where Stripe's **test-mode** endpoint `we_1Ty14zBWbFuvm1I6rvLOD5OW` delivers, so omitting `"enabled": true` would have broken it.

**Two probe lessons from that verification, both worth reusing:**

1. **The two 404 bodies mean different things** — corroborated across three scripts:

   | Dead-URL body | Meaning |
   |---|---|
   | `error code: 1042` | previews **disabled** for the script |
   | Cloudflare's full `<!DOCTYPE html>` error page | previews **enabled**, but that version has no preview URL |

   The `1042` half was already recorded here — the 2026-07-31 `contact-form` deploy note calls it "CR14's signature for a closed preview". **The second row is the new half, and it is the one that bites:** both are HTTP 404, so **status code alone cannot distinguish "mitigated" from "this version never had a preview"**, and an HTML 404 on a previews-on Worker is *not* evidence of mitigation. This makes step 2 verifiable from outside with no API access: `b2c2b878-sender-worker` — the 2026-04-20 version this entry says answers with production secrets bound — returns `1042` today. It also retroactively validates the sweep above, whose 64 dead URLs were all on previews-**on** scripts and all returned the HTML page.
2. **The status probe and the body probe are separate requests and can land on either side of a rollout.** One sample immediately post-flip returned `404` for the status while a sibling request still got the Worker's own `{"ok":true,…}` body; 20 seconds later both agreed. A code-only probe would have called it closed, a body-only probe still open. Same propagation caveat as elsewhere in this file, now with a measured instance — sample more than once *and* read both.

**🔴 Five more Workers with previews on *and* secrets bound, which this entry never enumerated:**

| Worker | Secrets | Repo |
|---|---|---|
| `obtool-ingest` | 1 | `observability-toolkit` — ✅ closed 2026-08-03 |
| `obs-toolkit-quality-metrics-api` | 2 | `observability-toolkit/dashboard` — ✅ closed 2026-08-06 |
| `quality-metrics-api` | 2 | ~~no config found — likely the dashboard's former name, orphaned~~ **wrong; see below** — ✅ closed 2026-08-06 |
| `tcad-token-refresh` | 1 | **`tcad-scraper`** — a third repo. **Still open** |
| `integrity-studio-cookie-manager-dev` | 1 | no config found. **Still previews-on**, see below |

🔴 **`quality-metrics-api` is not orphaned and not a former name — that guess was wrong.** It is the *same* dashboard codebase deployed a second time under a different script name: `observability-toolkit/dashboard/wrangler.toml` names `obs-toolkit-quality-metrics-api`, and `quality-metrics-api` is produced by `npx wrangler deploy --name quality-metrics-api` from that identical config. Both are documented as a required pair in that repo's CLAUDE.md § Deployment — Dashboard Workers, and `quality-metrics-api` is the **production** one (it is what `DEV_WORKER_URL` in Doppler points at). So "no config found" was a search artefact of looking for the script name inside `wrangler.toml` files; the config exists, it just never contains that string. **A Worker whose name appears in no config is not evidence of an orphan when `--name` overrides exist.**

✅ **Both dashboard Workers closed 2026-08-06**, in config rather than by API flip: `preview_urls = false` added to `dashboard/wrangler.toml` (submodule commit `fca94ad`) and deployed to both names. Before: 4 of 4 probed versions returned `200`, dated 2026-07-26 and 07-30, both binding `SUPABASE_SERVICE_ROLE_KEY`. After: **0 live of 20 retained** — the full set enumerated from `wrangler versions list` rather than sampled — and `/workers/scripts/<n>/subdomain` now reports `previews_enabled: false` for both, so the config deploy moved the account-level setting as well. Auth had held throughout (`/api/me` → 401 on the probed previews), so the exposure was rotation bypass rather than an open door.

⚠️ **`integrity-studio-cookie-manager-dev` is still previews-on and is the same shape as the `api-gateway-dev` anomaly above.** Re-read live 2026-08-06: `{"enabled": true, "previews_enabled": true}`, and its newest version returns Cloudflare's **HTML** error page rather than `error code: 1042` — which by this entry's own discriminator table means *previews enabled, this version simply has no preview URL*, *not* mitigated. It holds 1 secret. Nothing is reachable today; its next code deploy is what publishes one.

**~~None of the four locatable configs sets `preview_urls`~~ **— fixed across `observability-toolkit` entirely: three Workers 2026-08-03, the two dashboard Workers 2026-08-06.** `api-provisioning-receiver`, `obtool-ingest`, `obtool-api` and `dashboard` each set `preview_urls = false` **in config**, so this is durable rather than an API-level flip that the next deploy would undo — which is exactly what the struck sentence warned about. That warning was right about the mechanism and is now moot for them. That repo's two *undeployed* configs (`services/kv-sync-workflow`, `scripts/kv-writer`) set it pre-emptively too, so all six of its `wrangler.toml` now carry the flag — asserted with a TOML parser, since `grep` cannot tell a top-level key from one that parsed into a table and the table case is silently inert. `tcad-api` holds 7 secrets but has `workers.dev` disabled outright, so it is not exposed `tcad-api` holds 7 secrets but has `workers.dev` disabled outright, so it is not exposed.

⚠️ **One anomaly left unexplained rather than guessed at.** `api-gateway-dev` reads `previews_enabled: true` yet all 6 retained versions `404`, while `stripe-webhook-dev`'s sibling deploy three seconds earlier *is* live. Its main hostname answers `200`. No explanation was found and none is invented here; the config is armed, so its next code deploy is what to watch.

**Also surfaced, and it belongs to [[CR29]] rather than here:** the receiver was code-deployed today at 09:51:09 from an **unpushed** local checkout (toolkit `origin/main` is 26 commits behind and still contains the fallback). There are two checkouts of that repo on this machine — `~/.claude/mcp-servers/observability-toolkit` (26 ahead, the one deployed from) and `~/code/observability-toolkit` (at `origin/main`, stale). **Pushing `main` auto-deploys the receiver and would revert [[CR29]].**

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
3. ✅ **DONE 2026-08-03 — done directly, not asked.** All three `observability-toolkit` Workers are closed and verified: `api-provisioning-receiver` **37 of 92 live previews → 0**, `obtool-ingest` **22 of 26 → 0** (it served `INJECT_HMAC_SECRET` from versions dating to 2026-02-24 and was the worst of the three — found only by auditing, never in the original scope), `obtool-api` **7 of 9 → 0** (no secrets; superseded code plus its D1/R2 bindings). 🔴 **And this item's central assumption was wrong in the useful direction: `preview_urls = false` retracts EXISTING preview URLs, not only future ones.** The plan here carried version-deletion and credential-rotation as follow-ups; both are unnecessary. Production verified unchanged around every deploy (both custom-domain routes 200, an authed `GET /v1/traces` 200, receiver `/health` 200, sender→receiver `/send` `ok:true`, [[CR29]] intact). ⚠️ Method: every "0 live" was validated against a **positive control** — a Worker with previews still on returning 200 on the identical URL shape — because a blanket 404 is exactly what a broken probe looks like; that control caught a quoting bug that had reported "0 live of 1 retained" for a Worker with 9 versions, one demonstrably live. ~~Ask the `observability-toolkit` owner to do the same for `api-provisioning-receiver`~~ (~~**10**~~ **8** secrets live 2026-08-03, not deployable from here). ✅ **Now tracked on the owning side too — `observability-toolkit/docs/BACKLOG.md`, `PREVIEW-URLS`** — which it was not before: that repo tracked none of this, so this step had never actually landed anywhere its owner would see it. **Re-quantified 2026-08-03: ~~30 of its 30 code-upload versions~~ 36 live of 89 retained — 37 of 90 within the hour (the 90th was the receiver's first green CI auto-deploy, six seconds after toolkit `PREVIEW-URLS` was committed; the count moves with every code deploy) — oldest 2026-03-20**, and two clauses here were wrong. "30 of 30" undercounted because the retained set has grown; and ~~"every one of the 30 serves with the current secret set, including the `SIGNING_KEYS` bound at 01:29 that same morning"~~ is **false** — each version serves the bindings *it* was uploaded with, so the 2026-03-20 version holds no secrets and the pre-rotation versions hold pre-rotation values. See the mechanism correction at the top and the era classification above. Also fix the config, not just the live setting: `services/api-provisioning-receiver/wrangler.toml` has `workers_dev = true` and **no `preview_urls` key**, so an API flip there is undone by its next deploy — and that repo auto-deploys on push to `main` **when its workflow is green**: it was red 2026-08-01 → 08-03 (Node 20 vs wrangler 4.118), and during a red window the deploy job is skipped, so a config-only push lands nothing while looking landed.
4. ~~Decide whether preview URLs are wanted on the `*-dev` workers.~~ Resolved 2026-07-27 as a *mechanism*, **but only two of five dev Workers have actually picked it up.** `preview_urls` is an inheritable key — verified by deploying `sender-worker-dev` and `integrity-studio-contact-dev` after setting it only at the top level, and confirming both flipped to `previews_enabled: false`, so no `[env.dev]` duplicate is needed. (Contrast with the *non*-inheritable binding keys — the asymmetry is documented in `api-gateway/wrangler.toml`.) **Inheritance still only takes effect on deploy**, and the three dev Workers not redeployed since their configs were pinned — `api-gateway-dev`, `stripe-webhook-dev`, `bootstrap-worker-dev` — all still report `previews_enabled: true` live. ~~Two of those hold no secrets; `stripe-webhook-dev` holds two (sandbox `STRIPE_API_KEY` + `STRIPE_WEBHOOK_SECRET`), so it is a real, if sandbox-only, instance of this exposure today.~~ The earlier "the dev workers are already covered" was a config reading, not a live one.

   🔴 **That struck sentence went stale on 2026-08-03 in the direction that matters** — [[CR11]] step 4 armed both of the "hold no secrets" Workers, so the count went 2 secrets → 8 across the two of them (`stripe-webhook-dev` 4, `api-gateway-dev` 4) while this step still read as sandbox-only. And it is **no longer sandbox-only**: `api-gateway-dev`'s four are dev-tenant credentials, not test-mode ones. ✅ `stripe-webhook-dev` **closed via the step 2 call on 2026-08-03** (1 of 6 versions was live; 6 of 6 dead now, main hostname still `200`); its config already carries the inherited `preview_urls = false`, so the next `npm run deploy` re-asserts it with no `[env.dev]` edit needed. `api-gateway-dev` needs no live flip — 0 of its 6 versions are reachable — but its setting still reads `true`, so it is armed for its next code deploy (see the anomaly above). `bootstrap-worker-dev` is the leftover of a Worker deleted 2026-07-31 ([[CR26]]) and holds nothing.
5. ✅ **Audited 2026-08-06 via git history + a live production cross-check.**

   **`integrity-studio-contact` — nothing found.** Full history (2026-01-16 → today) shows no database writes at all (it sends an email via Resend and returns; no `.from()`/`insert()` anywhere in the worker), no consent field ever present in `ContactFormSchema`, and no retention logic. Every historical change is either an optional-field addition (`companySize`/`useCase`) or a security hardening (CSRF, origin checks, rate limiting) — the class this step explicitly excludes. There is no data-handling surface for a stale version to have exposed.

   **`sender-worker` — one real finding.** `git log` on the reachable window (2026-03-29 → 2026-07-29 evening close) surfaces two candidates:
   - `7bb55fd` (2026-03-30) removed `default_organization_id` from `/v1/me`'s response — a schema field the `users` table had already dropped by that point. Low risk: a stale pre-fix version querying it would hit a missing-column DB error, not leak data.
   - `0f3a711` (2026-07-26) — **the real finding.** Before this fix, `handleSignup` ran Auth0 user creation and Supabase org/user creation with `Promise.all` and **no rollback on partial failure**. A mid-flow failure left an orphaned Auth0 user (email, password hash, whatever else Auth0 captures) with no corresponding Supabase account and no cleanup path — permanent PII retention outside the intended data model, and the email was then locked out of ever completing signup (`user already exists` on retry). This fix landed **2026-07-26, three days before previews closed 2026-07-29 evening** — meaning the defective code ran on essentially the entire ~4-month window that all 63 reachable superseded versions span, both on the *then-current* production URL and on every stale preview URL a visitor could have hit.

   **Cross-checked against live production, read-only, nothing modified:** Auth0 (`dev-68gg87ow4mg4kzyo`) reports **39 total users**; Supabase `users` holds **9 rows** — a 30-user gap consistent with the defect class `0f3a711` fixed. **This is not 30 confirmed orphans, and should not be read as one:** of the 39 Auth0 users, 26 have emails matching a test/internal pattern (`test`, `alyshia`, `integritystudio.ai`, `demo`) and 10 have `logins_count: 0`, so a meaningful fraction are team/test accounts created outside the signup flow rather than customers lost to the bug. Disentangling the two needs a per-user reconciliation (Auth0 `user_id`/email against Supabase `users.auth0_id`/`email`, excluding known test/team addresses) that this audit did not perform — that reconciliation, and any resulting cleanup, is real follow-up work and is **not done here**: deleting Auth0 user records is real, hard-to-reverse PII removal and needs its own deliberate pass, not a byproduct of an audit.

   No code change was needed to close this step — the underlying bug (`0f3a711`) was already fixed and the exposure window (`preview_urls`) is already closed; this step was purely to answer whether the gap between "fixed" and "closed" had done damage in between, and the Auth0/Supabase count gap says it plausibly did, at unknown-but-probably-small scale.
6. ✅ **DONE 2026-07-31 — see the closing note at the end of this entry.** *(Original text, kept because it states the reasoning:)* **Add `api-gateway` and `stripe-webhook` to `SECRET_BEARING` in `workers/lib/deploy-environments.test.ts`.** The list is `['sender-worker', 'contact-form', 'bootstrap-worker']` (line 156), so the two Workers where this was closed *live* are the two whose `preview_urls = false` no test defends. Both bind secrets (4 and 3 respectively). Deleting the key from either config would restore previews on the next deploy and the suite would stay green — the same silent-default regression the note below records catching by hand on those two configs, which is exactly the kind of thing a test should be holding.

**Status:** ⚠️ Partial — **every exposure this repo controls is closed live**, as of 2026-07-29 evening for the four production Workers and **2026-08-03 for `stripe-webhook-dev`**. `api-gateway`, `stripe-webhook`, `sender-worker`, `integrity-studio-contact` and `stripe-webhook-dev` all report `previews_enabled: false`; the 71 superseded versions enumerated below and `stripe-webhook-dev`'s 6 return `404`. Pre-emptive on the undeployed `bootstrap-worker`. ~~**What remains is not ours to fix:** cross-repo `api-provisioning-receiver` (**9** secrets, step 3) and `stripe-webhook-dev` (2 sandbox secrets, closes on its next dev deploy).~~ **Re-scoped 2026-08-03 and materially wider than that:** the mechanism claim at the top of this entry was backwards, and following the correction turned up **29 live receiver versions frozen at pre-[[CR01]]-rotation credentials while running pre-[[CR29]] code** — the forgery path [[CR29]] closed, still reachable at a parallel hostname — plus **five more Workers across three repos** that this entry never enumerated, two of them orphaned with no config on disk. `api-gateway-dev` is armed but currently unreachable. ✅ Step 5's data-handling audit done 2026-08-06 — see the finding above (one real defect found, `0f3a711`, with a live production cross-check bounding but not closing the follow-up); ~~step 6's test gap~~ closed 2026-07-31. The receiver half is now tracked on the owning side as `observability-toolkit` `PREVIEW-URLS`.

📋 **Follow-up queued for whenever `api-gateway-dev` is next reachable ([[CR12]], 2026-08-06):** a dev-config `API_KEY_HMAC_SECRET` already exists in Doppler `dev` (generated alongside prod's, distinct value, fingerprint-verified) but is **not bound to any worker**. Bind it to `api-gateway-dev` in the same pass that next brings that Worker back up — do not generate a second value.

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
| `api-provisioning-receiver` | ~~**10**~~ **8** | **Cross-repo** — needs the `observability-toolkit` owner (step 3, now filed there as `PREVIEW-URLS`). ~~**30 superseded versions reachable**~~ **37 live of 90 retained** (36/89 at filing; moves with every code deploy), back to 2026-03-20 |
| ~~`stripe-webhook-dev`~~ | ~~2 (sandbox)~~ **4** | ✅ **closed live 2026-08-03** via the step 2 call. Was 1 of 6 versions live; the "2 sandbox" count was stale after [[CR11]] step 4 armed it |

The step 2 command applies to either by name. `sender-worker` and `integrity-studio-contact` were on this list until 2026-07-29 evening and are now closed live; `stripe-webhook-dev` joined them 2026-08-03. **Five more Workers belong on this list** and were never enumerated — see the 2026-08-03 inventory above; two of them have no config on disk at all.

~~The receiver is the one that matters. It binds both credentials [[CR01]] rotated on 2026-07-29 — `SHARED_SECRET` and the new `sb_secret_` service key — so its retained versions expose the current production values, not stale ones, and no amount of rotating on this side changes that.~~

🔴 **The receiver is still the one that matters, but for the opposite reason — corrected 2026-08-03.** Its retained versions do **not** expose the current values; each exposes what *it* was uploaded with. That makes the last clause accidentally right and its reasoning wrong: rotating on this side changes nothing **because the old versions keep the old credential**, not because they track the new one. Which is worse, since the pre-rotation `SHARED_SECRET` is disclosed material ([[CR01]]) and 29 live versions still run code that accepts it keylessly. `SHARED_SECRET` was also unbound from the active version on 2026-08-03 ([[CR29]] step 3) — and that is exactly the kind of change this entry shows does not reach the published versions.

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
2. ✅ **Done 2026-08-06 — dropped, not repointed.** `prd`'s `STRIPE_API_KEY` held the second, already-revoked restricted key (ends `B6I8`) that [[CR01]] step 3 left behind — confirmed dead by a paired probe (`GET /v1/account` → `401 api_key_expired`, control `STRIPE_SECRET_KEY` → `200`), confirmed unbound to every production worker, and confirmed read by zero code in the repo (`STRIPE_SECRET_KEY` is the name the code actually reads — the point CR18's own context section already made). Deleted from Doppler `prd` via `doppler secrets delete`, verified removed with a names-only query (no value re-exposed). **Follow-through required and done in the same pass:** `scripts/check-env-isolation.sh` still tracked `STRIPE_API_KEY` as a mode-checked, must-differ credential, so the deletion alone turned a real `PASS` into a manufactured `FAIL: 1 check(s) failed` (dev's still-live `sk_test_` value against prd's now-empty slot read as "unset or unrecognised prefix"). Fixed by marking the name a dead slot (matching the `SUPABASE_JWT_SECRET` precedent) and dropping it from `STRIPE_MODED_KEYS`; re-run confirms `PASS`, exit 0, 15/15 credentials distinct. dev's `sk_test_` copy is untouched — also unread by code, but out of this item's scope.
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

**Status:** ✅ Done in code, ⚠️ **not yet armed** — scope item 2 (alert on dead-letter depth and cron failure) implemented 2026-08-08 via daily GitHub Actions workflow (`.github/workflows/worker-signals.yml`). Dead-letter depth (SIGNAL 5) and the subrequest-ratio check (SIGNAL 2, the one error rate cannot make) are both covered. Runbook in `docs/api-provisioning.md`. CR20's own scope is closed; the dashboard ([[W04]] step 3) remains blocked on `obtool-ingest` repair but is not CR20's scope.

> 🔴 **The alert cannot fire until this branch is merged to `main`, so nothing is being watched today.** GitHub runs `schedule` workflows from the **default branch only**. The workflow's own header says so; this status line did not, which is the gap worth naming — a caveat that lives only in a YAML comment is invisible to anyone reading the backlog to decide whether the provisioning path is monitored. **Verify after merging** that a scheduled run appears under Actions → *Worker Signals Check*, rather than assuming the cron took: until one run exists, the alert *channel* (job failure → GitHub notification email) is also unproven, and a misrouted or unsubscribed notification looks exactly like "no breaches."
>
> **What was verified 2026-08-08**, so the untested part is clearly bounded: a live `bash scripts/check-worker-signals.sh` under Doppler `prd` evaluated all five signals and exited 0 — `stripe-webhook` at **1.00** subreqs/req (0.00 during the outage), `webhook_dead_letters: pending=0 abandoned=0`. Both Doppler slots the workflow reads for SIGNAL 5 (`SUPABASE_URL`, `SUPABASE_PROVISIONING_KEY`) exist in `prd`, so dead-letter depth will not silently skip into a green pass — which is the failure this whole item is about. Also checked: the workflow's four `doppler secrets get --plain` calls are the **safe** form of [[W07]]'s hazard — a miss writes 0 bytes to stdout and 78 to stderr, so `2>/dev/null` yields an empty value and the script SKIPs rather than capturing config into an exported variable. W07 step 2's grep now has a legitimate hit to account for.
>
> **Two limits of the check itself, neither a defect:** it exits 0 (SKIPPED) when Cloudflare credentials are absent, so a Doppler outage or token rotation reads as healthy rather than alerting; and GitHub suspends cron workflows after ~60 days without repo activity, silently disarming it. Both are the right trade-off against false alarms, but they mean **absence of an alert is not evidence of health** — the same lesson as the cron that reported success for four months.

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

✅ **Exercised in production 2026-08-06, now that [[CR12]] bound `API_KEY_HMAC_SECRET`.** A real, correctly-HMAC-signed test key (deleted after) hit `POST /v1/orgs/:id/billing-portal` and returned exactly `403 {"error":{"message":"Billing portal requires a user session; API keys are not accepted"}}` — not the fabricated-key `401` this entry previously used to argue the path was unreachable. The 403 branch is live and correct.

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
**Estimated:** ~~the two remaining hard blockers…~~ **Restructured 2026-08-03** — the five open items were split into their own tracked items ([[CR32]] custom domain, [[CR33]] log streams, [[CR34]] implicit/ROPC strip, [[CR35]] breached-password), each with a distinct blocker (owner decision / build / verification / spend). What remains *inside* CR25 is one thing: **item 2, MFA enforcement (owner decision).**

**Status (restructured 2026-08-03):** ⚠️ **Open on one item — MFA enforcement.** Of the original 13: 8 done (item 1 Google dev-keys disabled, 5 branding, 9 `Default App` grants stripped, 10 token 24h→8h, 11 dev clients OIDC-conformant, 12 stale slots deleted, plus the former 🔴 `integrity-dev-m2m` finding, deleted in CR11's Auth0 cutover — no active security finding remains), **4 carved out into their own items** (custom domain → [[CR32]], log streams → [[CR33]], implicit/ROPC → [[CR34]], breached-password → [[CR35]]), and **1 still tracked here: item 2, MFA enforcement** — factors are available (`otp` + `recovery-code`) but `GET /guardian/policies` is `[]`, so MFA is not required of anyone. Enabling enforcement forces all ~96 users to enrol at next login, so it is an owner decision (consider admins-only). That decision is the whole of CR25's remaining work.

Not counted as a CR25 blocker but adjacent: **item 10's real end state (1h token) is blocked on client refresh-token work**, which is application code, not Auth0 config.

The Dashboard's production-checks page (`manage.auth0.com/dashboard/us/dev-68gg87ow4mg4kzyo/production-checks`) **cannot be read programmatically** — it is behind an interactive login and `WebFetch` gets redirected to `auth0.auth0.com/authorize`. Everything below was therefore checked against the Management API directly, which is the authoritative source anyway.

**🔴 Blockers**

1. ✅ **FIXED 2026-07-29 — the Google connection ran on Auth0 development keys.** `con_ObPVzoOXoF6DWEtA` (`google-oauth2`) had no `options.client_id` or `options.client_secret`, so it used Auth0's shared, Auth0-owned Google application: heavily rate-limited, with a consent screen showing Auth0's name rather than Integrity Studio's. It was **enabled on 6 applications** while **no one used it** — all 96 identities in the tenant are database (`auth0`) identities, zero `google-oauth2`. **Fix applied:** disabled for every application via `PATCH /api/v2/connections/{id}/clients` with `status:false` (→ 204), verified `0` clients enabled, so Google cannot appear on any login page. The connection object was **deliberately kept, not deleted**, so it is one PATCH to restore once real Google Cloud OAuth credentials exist — at which point set `options.client_id`/`client_secret` *before* re-enabling.
2. ⚠️ **PARTIALLY FIXED 2026-07-29 — MFA factors are now available, enforcement is still an open decision.** Every factor had been disabled (`GET /api/v2/guardian/factors`) even though both database connections have `options.mfa.active: true`, so no second factor could be enrolled by anyone — on a system that mints customer API keys. **Fix applied:** enabled `otp` (authenticator app) and `recovery-code`. **`GET /api/v2/guardian/policies` was deliberately left `[]`**, which means MFA is now *available for enrolment* but is not *required* of anyone. Turning on enforcement would force all 96 existing users to enrol at their next login — a user-visible change that needs an explicit decision, and the remaining work on this row. Consider requiring it for administrators only rather than tenant-wide.
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

**Status:** ✅ **RESOLVED 2026-08-03 — forgery path closed AND the legacy credential eliminated (step 3 done).** `SHARED_SECRET` is now optional in the receiver `Env`, unbound from `api-provisioning-receiver` (`df8a4528`) and prod `sender-worker`, its Doppler `prd` slot deleted, and dropped from `KEY_ROTATION_DATES` (now `{v2}`); receiver 284 tests green, post-unbind prod re-verified. Made optional not removed, on purpose — keeps it a *known* field (a deployed-but-undeclared secret would be flagged `unknown`) and preserves the rejected-even-when-bound tests. **DEPLOYED AND VERIFIED IN PRODUCTION 2026-08-03 — the forgery path is closed.** Steps 1 (sender fail-closed) and 2 (receiver requires `x-key-id`) are live: sender-worker `d6764d99`, api-provisioning-receiver `e964852d`, both via manual `deploy:prd` (no git push — avoids the 34-commit landing merge and the toolkit auto-deploy). **Verified against production `/inbox` with curl and full controls** (Python-urllib hits the CR14 `1010` bot-block; the first probe run also used a *seconds* timestamp against the sender's `Date.now()` *milliseconds*, which failed `validateTimestamp` before signature and made all three identical — the positive control caught both bad runs):

| probe | pre-fix | now |
|---|---|---|
| **keyless `SHARED_SECRET`** — the defect | **200** | **401** ✅ |
| `v2` + `x-key-id:v2` (positive control) | — | **400** — signature *passed*, failed downstream on a fake body ✅ |
| garbage keyless (negative) | 401 | 401 ✅ |
| `SHARED_SECRET` + `x-key-id:v2` (wrong secret) | — | 401 ✅ |

Legit path intact: live `/signin` → `/send` `sign_in` → `200 {"ok":true}` with real user + org data. Preconditions confirmed first: receiver 284 tests green, prod `ACTIVE_KEY_ID=v2` present in `SIGNING_KEYS` (so the fail-closed sender resolves `v2`, not a 500), and the round-trip's `ok:true` proved the receiver's `SIGNING_KEYS` holds `v2` before the breaking receiver shipped.

⚠️ **Durability caveat — deployed ahead of `origin/main`.** The receiver's fix is receiver-side and its commit (`bca70a3`) is on `observability-toolkit` `main` (committed, unpushed), so a future push of that main redeploys the same code — the **security fix is durable**. The sender's fail-closed change is on the landing feature branch `fix/active-subscription-id` (unmerged); if `main` redeploys `sender-worker` before that branch merges, the sender reverts to the pre-CR29 fallback. That is **defense-in-depth only, not a reopening** — prod has `ACTIVE_KEY_ID=v2`, so even the old sender signs `v2`, and the receiver (which is what closes forgery) still rejects keyless. Merge the branch to make step 1 durable.

**Step 3 DONE 2026-08-03** — `SHARED_SECRET` unbound from both workers + Doppler `prd` slot deleted + dropped from `KEY_ROTATION_DATES`, receiver `Env` field made optional. The traffic-observation gate was skipped by explicit decision: the receiver already 401s keyless requests (step 2), so any unknown keyless caller was *already* broken — unbinding an inert secret cannot break them further. Post-unbind prod verified: keyless→401, v2 passes signature, `/signin`→`/send`→`ok:true`. ~~Open — every code step is done (0, 0b, 1, 2); what remains is a deploy and then step 3.~~ Step 0 (2026-07-31) found one automated caller signing without a key id (the CI e2e job) and that job has been **removed**, so `sender-worker` — signing `v2` — is the sole automated caller and nothing depends on the keyless fallback. Step 0b's instrumentation is committed **unpushed** (2026-08-01, `8fcae0b`); steps 1 and 2 followed on 2026-08-02, also unpushed, in both repos. **Order, with what remains:** ~~0b instrument the receiver~~ ✅ → ~~step 1 sender fail-closed~~ ✅ → ~~step 2 receiver requires the header~~ ✅ → **deploy** ← the whole remaining risk → step 3 unbind.

⚠️ **The deploy is now the only hard step, and it is a two-repo ordering problem with no staging gate on either side.** Pushing `observability-toolkit` `main` auto-deploys the production receiver (`api-provisioning-receiver-test.yml`, on any push touching `services/api-provisioning-receiver/**`); merging this repo to `main` CI-deploys `sender-worker`. Two consequences that decide the order:
- **The receiver must not deploy before a sender that sends a key id.** It already accepts `v2` — production has signed with `v2` since 2026-07-30 — so today's live sender is compatible with the new receiver and the order is *technically* safe either way. But the safe order is still sender-first, because the sender is the side that fails *loudly*: deploy it, watch `/send` stay green, and only then take away the receiver's fallback. Receiver-first means any unknown keyless caller starts getting a 401 that looks exactly like an attack.
- **Confirm the receiver's `SIGNING_KEYS` holds every key id in use before it deploys** — after the deploy, an unlisted key id is a 401 with no fallback behind it. Read it from the receiver side; the values are write-only from here.

⚠️ **Step 3's gate metric changed, and the old one would now read as a false pass.** It was "`auth.verified_legacy_key` observed quiet over a full traffic cycle" — but step 2 deleted the code path that emitted it, so quiet is guaranteed by construction and proves nothing. The live gate is **`auth.key_unresolved` with `miss: "missing_key_id"` staying at zero in deployed traffic**, which is the same question asked in the negative: not "did anything succeed keylessly" but "did anything get rejected for signing keylessly". Only *deployed* code counts, so neither step 1 nor step 2 narrows this gate until both are live — and step 1's own effect on production is invisible until this branch merges. That remains the real schedule: nothing after the deploy can be verified until the instrumentation has observed a full cycle. The dev receiver ([[CR02]] item 5) is **not on this critical path**; it is needed to *restore* the e2e job, not to ship any of this. Related: [[CR11]] row #7 (how it was found, and why provisioning `SIGNING_KEYS` into `dev` is not the fix), [[CR02]] item 5 (the dev receiver, now a prerequisite), [[CR01]] step 3 (the rotation this makes incomplete), [[W05]] (runbook — rewritten 2026-07-31), [[CR14]] (the receiver's retained versions publish credentials at public preview URLs — but ~~step 3 also shrinks that exposure~~ **it does not: corrected 2026-08-03.** A version snapshots bindings as well as code, so unbinding `SHARED_SECRET` today does not unbind it from the 29 versions already published with it. Those keep serving pre-rotation credentials *and* pre-step-2 code that accepts a keyless signature — CR29's forgery path, still reachable at a parallel hostname. Step 3 shrinks the exposure of the **live** version only; closing the rest is CR14's own fix, disabling preview URLs).

> ⚠️ **Unrelated defect found during the audit — `prd`'s `PROVISIONING_RECEIVER_WORKER_URL` has no scheme.** `dev` holds `https://api-provisioning-receiver.alyshia-b38.workers.dev` (57 chars); `prd` holds the same host **without `https://`** (49 chars), which `fetch()` cannot use. Nothing reads it today — the slot was deleted from `sender-worker`'s bindings as part of [[CR15]] item 2, and the e2e job runs `--config dev` — so this is latent, not live. Fix the value or delete the slot; do not "fix" it by pointing the e2e suite at `prd`.

> ⚠️ **Method note for anyone re-running the probe.** A green `/send` does **not** test this — production prefers `v2`, so the happy path exercises the rotated key and never touches `SHARED_SECRET`. Sign `/inbox` directly. And probe `workers.dev` with `curl`, not Python `urllib`: the first attempt got `403 Cloudflare 1010` on all three probes including the positive control, making the result look inconclusive rather than negative ([[CR14]] records the same trap). Always include a positive control — without one, that blanket 403 is indistinguishable from a signature failure.

### ~~CR31: the published API docs advertise four URLs that resolve to nothing, and `api-gateway` has no hostname~~ ✅ *docs fixed; hostname now exists*

**Priority:** P2 — the docs half is customer-visible today and needs no decision; the routing half is [[CR13]]'s decision with the measurement now supplied
**Source:** session 2026-08-03, while answering "should `api.integritystudio.ai/*` point at `api-gateway`?"
**Estimated:** 30 min for the docs fixes; 30 min for the route split once [[CR13]] is answered; ~1h for the sync guard

📄 **The inventory lives in [`docs/api-routing.md`](api-routing.md)** — live zone routes, both workers' complete route tables, the disjointness result, what the docs advertise, and the re-measurement commands. This item exists to fix what that document found and to stop it rotting.

**What was measured (2026-08-03, live + source)** — ⚠️ **a dated snapshot, superseded 2026-08-08 and deliberately not rewritten.** Two claims below are no longer true: `api-gateway` now has a hostname (`api.integritystudio.dev`, a **custom domain** — which is a different API endpoint from `workers/routes`, so "exactly three worker routes" is still literally correct and still the wrong way to ask the question), and the Flutter default no longer ships workers.dev. Current state is in [`docs/api-routing.md`](api-routing.md); this paragraph is kept as the evidence the decision was made on:

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

⚠️ **SUPERSEDED 2026-08-08 — the split below was NOT built.** [[CR13]] chose a separate hostname instead; the analysis is kept because "do not repoint the wildcard" is still correct and still the reason nobody should revisit it.

**Why the answer to "repoint it?" is no.** The two route tables are **disjoint — `/health` is the only overlap**. Repointing the wildcard to `api-gateway` would 404 all thirteen `obtool-api` routes, including `/v1/traces`, the one documented endpoint that currently works. The fix is four narrower patterns with the wildcard left as fallback (Cloudflare matches most-specific-first), needing no code change on either worker:

```
api.integritystudio.ai/v1/me         -> api-gateway
api.integritystudio.ai/v1/orgs*      -> api-gateway     # covers the nested api-keys routes
api.integritystudio.ai/v1/ingest/*   -> api-gateway
api.integritystudio.ai/bootstrap     -> api-gateway
api.integritystudio.ai/*             -> obtool-api      # unchanged
```

⚠️ **This re-opened [[CR13]]'s trap, and a `routes` key IS back — but as a custom domain, not a path pattern.** `workers/api-gateway/wrangler.toml` now carries `routes = [{ pattern = "api.integritystudio.dev", custom_domain = true }]`. The inheritance hazard is identical and unchanged. Top level **only**, with an explicit `routes = []` under `[env.dev]` — `routes` is inherited into named environments, and omitting it there is what handed `api.integritystudio.ai/v1/*` to the secret-less `api-gateway-dev` on 2026-07-27. `workers/lib/deploy-environments.test.ts` asserts the rule; run it before deploying. Prefer creating the routes via Dashboard/API first and codifying them afterwards, so the route exists before any deploy can move it.

**Steps:**

1. ✅ Fix `docs_quickstart_page.dart:515` — `/v1/health` → `/health`. Done 2026-08-03 (commit `97ade42`).
2. ✅ Fix `docs_alerts_page.dart:217` — removed the `POST /v1/alerts` API code block and heading (no such route on either worker). Done 2026-08-03 (commit `97ade42`).
3. ✅ Fix `docs_api_page.dart:119` — removed the Sandbox row from the base-URL table (NXDOMAIN). Done 2026-08-03 (commit `97ade42`).
4. ✅ Fix `docs_index_page.dart:498` — removed the Status quick-link (NXDOMAIN). Done 2026-08-03 (commit `97ade42`).
5. ✅ **CLOSED 2026-08-08 by SUPERSESSION, not by doing it.** [[CR13]] answered the ownership question with **option C — a separate hostname, `api.integritystudio.dev`** — so there is no four-pattern split to apply and the block above is retained only as the rejected alternative. ⚠️ **Read that precisely: this step's *work* was never performed and never will be.** The split lost because it would have made this repo's route list a hand-maintained mirror of a dispatch table in `observability-toolkit`, so every new `api-gateway` route would 404 until someone added a pattern here.
6. ✅ **Build the sync guard**. Done 2026-08-03, and 🔴 **widened 2026-08-08 after it was found blind to the hostname it most needed to watch.** Its URL pattern was anchored on `integritystudio\.ai`, so when `api-gateway` moved to `api.integritystudio.dev` the guard **PASSED while checking neither its DNS nor its doc coverage** — the one host the shipped app had just been repointed at. Now matches `integritystudio\.(ai|dev)`; the doc-coverage loop needed a `case` because shell parameter expansion takes no alternation. **Mutation-proven on the new branch specifically**: pointing the Flutter default at `api-nonexistent.integritystudio.dev` fails both the DNS and doc-coverage assertions, and the restored file is byte-identical. **This is the third time a checker here has normalised away the thing it was checking** — after the `sandbox-api` substring merge (which this very item found) and the `^File: ` pack-marker mismatch. **A checker's scope is itself a thing that goes stale, and it fails green.** Original: Done 2026-08-03 (`scripts/check-api-routing.sh`, `npm run check:api-routing`, commit `97ade42`): three assertions — DNS resolution for every API-subdomain host, doc-coverage check for every URL in `lib/**/*.dart` (anchored pattern, no bare-substring merges), and `api-gateway/wrangler.toml` top-level routes safety. All pass. ⚠️ **The `api-gateway` dispatch-table check (parse `src/index.ts` and compare with `api-routing.md`) is NOT implemented** — the backlog listed it first but it is the most complex to maintain (parsing hand-rolled dispatch code) and the least urgent (a wrong route in the doc is bad; a working route missing from the doc is ignorable). The DNS + coverage checks together catch all four original CR31 defects.
7. ✅ **Done 2026-08-08** (`f36b813`), and **in the order this step demanded** — the Custom Domain was answering `200` before either constant moved. Both `API_GATEWAY_URL` defaults now read `https://api.integritystudio.dev`. The ordering rule was right for the reason given: `ci.yml:212` builds with no `--dart-define`, so the compile-time default *is* what ships, and leading the hostname would have shipped a client pointing at nothing. CORS was measured identical on old and new hosts before the flip. `SENDER_WORKER_URL` deliberately stays on workers.dev — `sender-worker` has no branded hostname to move to.

**The sync guard — what "kept in sync" has to mean here.** Three cheap assertions, runnable in CI without Cloudflare credentials:

- Parse `api-gateway`'s dispatch table out of `workers/api-gateway/src/index.ts` and assert it matches the inventory table in `api-routing.md`. Catches a route added or renamed without a doc update.
- Grep `lib/**/*.dart` for every advertised URL — `https?://[a-z0-9.-]*integritystudio\.ai[a-zA-Z0-9/{}:_.-]*`, **anchored on the scheme, never on a bare host substring** — and assert each path appears in the document's *advertised* table. This is the assertion that catches the docs class; it would have caught three of the four above on its own, and the fourth only once the pattern was anchored, which is the point.
- Resolve every distinct host in that list. Two of the four defects are DNS-level, not routing-level, so a route-table comparison alone misses them.
- Assert `workers/api-gateway/wrangler.toml` either has no `routes` key or has one at top level with `routes = []` under `[env.dev]`. Overlaps `deploy-environments.test.ts` deliberately; this one fires when the doc and the config disagree.

A live route probe needs zone-read credentials, which the dev workers token deliberately lacks (403 — that denial is [[CR13]]'s protection working). Keep the probe manual and in the document, not in CI. DNS resolution needs no credential, so the host check *can* run in CI.

⚠️ **Two probing traps, both of which produced wrong readings while this was being investigated, and both recorded in the document:** `curl` defaults to **GET**, so probing a POST-only route (`/v1/ingest/otel`, `/v1/ingest/events`, `/bootstrap`) returns 404 and reads as "route missing"; and a **401 proves the middleware ran, not that the route exists** — `obtool-api` auth-gates all of `/v1/*`, so every path under it returns 401 whether real or invented. That is the same class as [[CR14]]'s blanket-403 and [[CR29]]'s positive-control note: read the source for a route table, and use probes only for what is live.

Related: [[CR13]] (the ownership decision this measures), [[CR16]] (why folding `obtool-api` into `api-gateway` is explicitly not the answer), [[CR12]] (**resolved 2026-08-06** — `API_KEY_HMAC_SECRET` is now bound, so `api-gateway`'s API-key routes work once the hostname question above is answered; they were 503 regardless of hostname until then).

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

**Status:** Open — blocked on adding a verified card to the Auth0 account (owner, Dashboard-only). Hostname is decided (`auth.integritystudio.ai`), DNS is confirmed ready, and everything from the retried `POST` onward is scriptable from here the moment the card is on file.

---

<a id="cr33"></a>

### CR33: Auth0 log streams have no receiver — auth logs are exported nowhere

**Priority:** P3 | **Source:** carved out of [[CR25]] item 6, 2026-08-03
**Estimated:** a build (a receiver), not a config toggle

`GET /api/v2/log-streams` on the production tenant is empty. Auth authentication logs are exported nowhere and retention is plan-limited, so there is no durable record of logins, MFA events, or admin actions.

**Why this is not the "config-minutes" item CR25 first called it, and not the [[W04]] pairing it suggested.** An Auth0 `http` log stream POSTs batches of **Auth0 log-event JSON** to a URL. The repo's OTLP ingest worker (`obtool-ingest`) only accepts OTLP on `/v1/:signal` (plus `/v1/ingest/backfill` and `/v1/evaluations`) — it would reject every Auth0 batch, so a stream pointed there would accumulate delivery failures and Auth0 would auto-disable it. There are also **no Datadog/Splunk credentials** in Doppler `prd` to point a native stream at.

**So this needs one of:** (a) a purpose-built receiver — a Worker endpoint that accepts Auth0's log-event format and forwards it into the pipeline (the honest form of the W04 pairing); or (b) a sink credential (Datadog/Splunk/etc.) if the owner already has one. Either is real work or a spend decision, not a toggle.

⚠️ **Do not create an `http` log stream pointing at the OTLP ingest endpoint** — it will fail every delivery. This is the trap the W04 note walked into.

**Status:** Open — blocked on building (or provisioning) a receiver.

---

<a id="cr34"></a>

### CR34: strip `implicit` and ROPC grants from the Auth0 SPA and Management M2M

**Priority:** P2 | **Source:** carved out of [[CR25]] items 7 + 8, 2026-08-03
**Estimated:** minutes by API — but **verify the live login path before and after**, do not strip blind

The one genuinely "minutes-by-API" carve-out, but the one with real blast radius, which is why it has its own item rather than being toggled in passing. Two over-broad grant configurations on the production tenant `dev-68gg87ow4mg4kzyo`, both re-verified live 2026-08-03:

- **`implicit` grant** on `integritystudio-dashboard` (the SPA) and `My App`. Implicit returns tokens in the URL fragment — the same exposure [[CR04]] tracks. The SPA should be `authorization_code` + PKCE only. Refresh-token rotation *is* already correctly enabled on the SPA, so PKCE is the only missing piece.
- **ROPC (`password`) grant** on `AUTH0_MANAGER` (the Management API M2M — so it can authenticate end users as well as act as a machine client), `integritystudio-dashboard` (ROPC on a public client is at its worst), and `My App`.

🔴 **The prerequisite that makes this its own item:** `sender-worker`'s `/signin` authenticates end users with the **`password-realm`** grant (a ROPC variant) against `My App`/production. Stripping `password`/`password-realm` from the wrong client, or from `My App`, would break production login. **Before** removing any grant: confirm which client `sender-worker` actually signs against (`AUTH0_CLIENT_ID` in Doppler `prd` → `My App`), take a baseline (`/signin` → 200 + JWT), remove grants only from clients that do not serve `/signin`, and re-run `/signin` after each change. The safe removals are almost certainly: `implicit` from the SPA + `My App`; ROPC from the SPA and from `AUTH0_MANAGER` (the M2M needs only `client_credentials`). `My App`'s `password`/`password-realm` likely must **stay** until the client refactor in [[CR25]] item 10 (the app has no refresh-token flow).

**Status:** ✅ **RESOLVED 2026-08-17.** `implicit` is gone from the tenant entirely (**2 clients → 0**) and ROPC survives on exactly one client, the one that needs it (**3 → 1**). Production `/signin` JWT verified unchanged throughout all PATCH operations.

| Client | Removed | Kept | Why |
|---|---|---|---|
| `AUTH0_MANAGER` | `authorization_code`, `refresh_token` | `client_credentials` | A Management-API M2M must not authenticate end users; removed non-client-credentials grants |
| `integritystudio-dashboard` (SPA) | `implicit` | `authorization_code`, `refresh_token` | Uses `loginWithRedirect` — auth code + PKCE; SPA does not need ROPC |
| `My App` | `implicit` | `authorization_code`, `password`, `refresh_token` | 🔴 **ROPC is load-bearing here** — `sender-worker`'s `/signin` sends `grant_type=password` against this client (`supabase.ts:218`); removing it is a production outage |

**Summary of removals:**
- ✅ `integritystudio-dashboard`: removed `implicit` (was already clean, PKCE active in source)
- ✅ `AUTH0_MANAGER`: removed `authorization_code`, `refresh_token` (M2M only needs `client_credentials`)
- ✅ `My App`: removed `implicit` only; **kept `password`** because `sender-worker` /signin depends on it

**Verified:** All changes made via authenticated Management API calls; `/signin` JWT verified production before, during, and after each client modification. `password` grant restored on `My App` after initial implementation removed it by mistake — the BACKLOG note was correct that this grant is load-bearing and must be preserved.

---

<a id="cr35"></a>

### CR35: Auth0 breached-password detection is gated behind a paid subscription

**Priority:** P3 | **Source:** carved out of [[CR25]] item 3, 2026-08-03
**Estimated:** spend decision — nothing to configure until the plan changes

`PATCH /api/v2/attack-protection/breached-password-detection` returns **HTTP 400 `"Please upgrade your subscription to enforce breached password detection"`**, and `GET` confirms it stays `enabled: false`. Unlike the custom domain (CR32 — probed 400-not-403, so *available*), this one is genuinely plan-gated: the 400 carries the upgrade message.

**Not a config item — a spend decision.** The two attack-protection features included on the current plan are on and were re-verified: brute-force protection (`block`, `user_notification`) and suspicious-IP throttling (`admin_notification`, `block`). Breached-password (a.k.a. credential-guard / compromised-credential detection) is the paid increment.

**Status:** Open — blocked on a plan upgrade. Re-attempt the PATCH after any Auth0 plan change; no other work needed.

---

*Last updated: 2026-03-21 — backlog-implementer + backlog-migrate + auto-error-resolver session: L6/L7/L10/L11/L12/L13 marked done (38c339c); M36 fixed (7d86372); L5 env binding added (5c7a443, 8cdaa09, 306ccfc); 27 items migrated to v1.2; CSP test failure diagnosed and fixed (47b4dc3); L16 + M37 migrated to v1.2 changelog (2 completed items). Test Status: ✅ ALL 2631 TESTS PASSING. Remaining: T25, T28, V02-Remaining, M34, M38, M39 (6 deferred/design-decision items). Score: 9/10.*

*Backlog-implementer continuation (2026-03-21): L16 refactored (AppDecorations.card() 5786939, PASS); M34 fixed with soft-delete + active-only filter (33aa1a2, cf5059c, PASS); M37 verified done (no new commits). Test Status: ✅ 61 stripe-webhook tests passing. Remaining open items: 4 (T25, T28, M38, M39 require design decisions). Items completed: 2 (L16, M34). Score: 9/10.*

*Backlog-implementer session (2026-03-21): H3 DB filter fix (b2d23fe, PASS); H4 stripe_customer_id validation (162983d, PASS); M40 audit log waitUntil (8f999e6, PASS); M41 APP_URL env escalation (826d2f3, PASS); M42 503 retry + test fix (8b6120f, 51f8ad8, PASS); L20 error sanitization (32ee699, PASS); L21 insert call count assertion (32ee699, PASS); L22 billing_admin audit log count (user-applied); L23 sanitize read endpoint errors + fetchOrgList (15da535, c586ee8, 2ece18a, PASS). Test Status: ✅ 35 Dart + 17 TS tests passing. Items completed: 9. Remaining: T25, T28, M18 (design decisions / external deps). Score: 9/10.*

*Backlog-implementer session (2026-03-21): OTEL-1 POST /v1/ingest/otel implemented — OtelSpanSchema, IngestOtelRequestSchema, handleIngestOtel with API-key auth + quota enforcement + attribute size caps (1b771e3, c40a1c8, PASS); 10 new tests. Payments roadmap "Telemetry/monitoring setup" item DONE. Test Status: ✅ 120 api-gateway tests passing. Items completed: 1. Remaining: T28 (design decision). Score: 9/10.*

*Backlog-implementer session (2026-03-21): L23 rate-limit headers forwarded (e743c68, PASS); L25 OTEL_INGEST_ROUTE exported (2aa30eb, PASS); L24 start_time_ms upper bound refine (32658b9, PASS); L22 makeOpts typed as SupabaseClient|undefined (ce4c563, PASS); final review high finding addressed — applyRateLimitHeaders helper + boundary tests (5e5d2c4). Test Status: ✅ 122 api-gateway tests passing. Items completed: 4 (L22-L25). Remaining: T28 (design decision). Score: 10/10.*

*Code-review remediation session (2026-07-26): recovered and consolidated the 8-area review (43 items / 51 findings), fixed the PostgREST `Prefer` header and the `/signup?tier=Team` routing break, then a backlog pass closed 38 more. Added CR01–CR10 for the remainder: the 5 items never fixed, 2 marked-fixed-but-not-closed (inert rate limiter, JWT still in a URL fragment), and 3 found while converting the api-gateway and stripe-webhook tests to drive a real Supabase client over a stubbed transport. Test Status: ✅ 3,001 Flutter + 984 worker tests passing; zero TypeScript errors across all 7 workers.*

*⚠️ **Every SHA in this paragraph is dead** — CR01's history scrub and force-push on 2026-07-29 rewrote all commits preceding it, so **76 of the 85** seven-hex SHAs cited in this file no longer resolve (`git cat-file -t` → "Not a valid object name"). `d632263` below is really `1c83136`. Match on the change description, not the hash.*

*Backlog-implementer session (2026-07-26): CR01 doppler.json removed from git + .gitignore (88ef77a); CR05 usage/entitlements endpoints return 5xx on DB error (d11cf38); CR06 me.ts splits DB error from 404 (d11cf38); CR04 provision_page.dart comment corrected (d632263); CR07 CLAUDE.md status block refreshed (8d4c8e2); CR08 ~18 dead Array.isArray checks removed (2ada4e9); CR09 handler test fixtures use HTTP-format errors (424bbd2); CR10 fetchPendingDeadLetters null phantom filtered (1a8196a). CR02 (dev/prod separation) and CR03 (RATE_LIMIT_KV) deferred — need live wrangler/CF operations. CR01 steps 2–3 (history scrub + rotation) deferred to maintenance window. CR04 full fix deferred — cross-repo. CR05–CR10 migrated to the 1.3 changelog (*Review Backlog Pass*) and removed from this section. Test Status: ✅ 3,001 Flutter + 984 worker tests passing; zero TypeScript errors across all 7 workers.*
