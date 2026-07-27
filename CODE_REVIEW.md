# Codebase review — 2026-07-24

**Scope:** Flutter web app + all Cloudflare Workers
**Method:** 8 parallel area sweeps, each finding adversarially verified by an independent agent that re-read the cited source and tried to refute it
**Consolidated & remediated:** 2026-07-26

The original run finished all 8 area sweeps, but rate limits killed the last verifier and the final report. All 16 agents' results were recovered from the workflow journal, the 5 findings that never received an adversarial check were verified by hand (3 confirmed, 2 were duplicates of already-confirmed issues), and the whole set was consolidated and worked through.

**45 tracked items covering 51 confirmed findings** — a few entries bundled two locations in the same file.

## Where the items went

| Outcome | Count | Location |
|---|---|---|
| Fixed in the remediation pass | 40 | [`docs/changelog/1.3/CHANGELOG.md`](docs/changelog/1.3/CHANGELOG.md) → *Codebase Review Remediation* |
| Fixed in the follow-up backlog pass | 6 | [`docs/changelog/1.3/CHANGELOG.md`](docs/changelog/1.3/CHANGELOG.md) → *Review Backlog Pass* |
| Fixed in the deploy / settings work | 2 | changelog → *Worker Deploy Separation* (CR02), *Environment Isolation Detector* (CR03) |
| Still open | 9 | [`docs/BACKLOG.md`](docs/BACKLOG.md) → CR01–CR15, with a status table |
| Refuted | 3 | below |

The 10 items that outlived the remediation pass became CR01–CR10: the 5 never fixed, 2 marked fixed but **not fully closed**, and 3 found while remediating. A follow-up pass closed CR05–CR10.

**The open count went up, not down, and that is the honest result.** Acting on CR02 and CR11 meant deploying and auditing the workers for the first time, and five further items surfaced (CR11–CR15) — including two the review could never have found by reading source, because they live in deployed state rather than in the repo: production `api-gateway` running with **zero secrets** and answering 503 for ~4 months (CR12), and superseded Worker versions still publicly callable with live secrets (CR14).

### Corrections recorded during remediation

A review is only as good as its willingness to retract. Three claims made confidently in this process turned out to be wrong:

| Claim | Reality |
|---|---|
| CR03: "the auth rate limiter is inert / fails open" | A misreading of an early return that skips only the KV tier. The in-memory tier above it enforces the limit, and tests had proved so since the limiter landed. Repriced P1 → P2 |
| "Dev and prd share a live Stripe key" | `STRIPE_SECRET_KEY` is empty in every config; the key in use is `STRIPE_API_KEY` = `sk_test_…`. No live-key exposure. Also: `stg` is empty, not a third environment |
| "`[env.dev]` declares no routes, so dev cannot take a production hostname" | Backwards. `routes` is **inheritable** — omitting it inherits production's. A dev deploy consequently served `api.integritystudio.ai/v1/*` for ~14 hours, while the test written to prevent exactly that asserted the bug as its invariant and passed |

The common thread is the same one the refuted claims below teach: quoting a line, or a config key, without tracing what actually runs produces a confident and wrong conclusion. Each is now pinned by a test that was mutation-checked rather than merely written.

One review item, the `workers/receiver-worker/src/index.ts:72` replay window, folded into the existing `W06` backlog entry instead of getting its own. That file is a local stub that is never deployed, and `W06` already tracks a nonce store for the production receiver, which is the real work.

## Refuted claims

These three were raised by area sweeps and **failed** adversarial re-reading of the cited code. They are recorded so a future review does not re-report them.

| Claim | Location |
|---|---|
| `revokeConsent` leaves GTM consent granted and the FB pixel enabled; re-consent permanently mutes analytics | `lib/services/consent_manager.dart` |
| `getClientIp` falls back to the client-supplied `X-Forwarded-For`, letting callers spoof the IP forwarded to the receiver | `workers/sender-worker/src/utils.ts` |
| An unauthenticated attacker-chosen `X-Idempotency-Key` can suppress other users' submissions | `workers/contact-form/src/index.ts` |

## What this review says about the test suite

Two of the nine high-severity findings lived inside `workers/lib/supabase.ts` and were invisible to 132 passing api-gateway tests, because every route test mocked the Supabase client away. A third — the `/signup?tier=Team` break — passed the router tests, which asserted only that `SignupPage` rendered and so stayed green against a completely blank page.

Both gaps were closed during remediation: the route and admin suites now drive a real client over a stubbed transport, and a content-contract test pins the tier wiring. The general lesson is worth keeping. A test that mocks away the component where bugs live cannot find them, and a test that asserts only "a widget rendered" will not notice that it rendered empty.

## Provenance

- Raw per-agent results: `~/.claude/projects/-Users-alyshialedlie-code-is-public-sites-IntegrityLandingPage/dcaf2f18-2817-40e5-9bfb-3d94321fe0e6/subagents/workflows/wf_f801cf11-d4b/journal.jsonl`
- Consolidated workflow output: `/private/tmp/claude-501/-Users-alyshialedlie-code-is-public-sites-IntegrityLandingPage/dcaf2f18-2817-40e5-9bfb-3d94321fe0e6/tasks/w99mk1j47.output` (temp directory — may have been cleaned up)
