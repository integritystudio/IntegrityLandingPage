# Codebase review — 2026-07-24

**Scope:** Flutter web app + all Cloudflare Workers
**Method:** 8 parallel area sweeps, each finding adversarially verified by an independent agent that re-read the cited source and tried to refute it
**Consolidated & remediated:** 2026-07-26

The original run finished all 8 area sweeps, but rate limits killed the last verifier and the final report. All 16 agents' results were recovered from the workflow journal, the 5 findings that never received an adversarial check were verified by hand (3 confirmed, 2 were duplicates of already-confirmed issues), and the whole set was consolidated and worked through.

**45 tracked items covering 51 confirmed findings** — a few entries bundled two locations in the same file.

## Where the items went

| Outcome | Count | Location |
|---|---|---|
| Fixed | 40 | [`docs/changelog/1.3/CHANGELOG.md`](docs/changelog/1.3/CHANGELOG.md) → *Codebase Review Remediation* |
| Still open | 5 | [`docs/BACKLOG.md`](docs/BACKLOG.md) → CR01–CR10 |
| Refuted | 3 | below |

The backlog's CR01–CR10 is the worklist. It holds the 5 items that were never fixed, 2 that were marked fixed but are **not fully closed** — the auth rate limiter is inert because its KV namespace was never created (CR03), and the dashboard JWT moved to a URL fragment rather than out of the URL (CR04) — and 3 more found while remediating.

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
