# Worker health signals

The signals worth alerting on for the Workers this repo deploys, where each one
comes from, and what "bad" looks like. This is [`BACKLOG.md`](BACKLOG.md) **W04
step 2**; step 3 (dashboard) and step 4 (alert channel) consume it.

Evaluate them all with:

```bash
CLOUDFLARE_API_TOKEN=$(doppler secrets get CLOUDFLARE_API_TOKEN --project integrity-studio --config prd --plain) \
CLOUDFLARE_ACCOUNT_ID=$(doppler secrets get CLOUDFLARE_ACCOUNT_ID --project integrity-studio --config prd --plain) \
SUPABASE_URL=$(doppler secrets get SUPABASE_URL --project integrity-studio --config prd --plain) \
SUPABASE_SERVICE_ROLE_KEY=$(doppler secrets get SUPABASE_PROVISIONING_KEY --project integrity-studio --config prd --plain) \
  npm run check:worker-signals
```

Exit 0 = all within threshold, 1 = a breach, 2 = the check itself failed. With no
Cloudflare credentials it prints `SKIPPED` and exits 0, matching
`check-migration-drift.sh` — a check that fails for a known, non-actionable reason
is one nobody reads.

> **Note the Doppler slot name.** The service-role key lives in
> `SUPABASE_PROVISIONING_KEY`, not `SUPABASE_SERVICE_ROLE_KEY`. The latter is the
> *Worker binding* name and does not exist as a Doppler slot in `prd`.

---

## Why this is not built on error rate

Error rate would not have caught the outage that motivated it.

`stripe-webhook`'s reconciliation cron ran ~96×/day for four months reporting
`status: success` with `errors: 0` while doing **nothing at all**. Its Supabase
client threw on unbound secrets, and `fetchPendingDeadLetters` caught that and
returned `[]`, so the loop had nothing to iterate and the invocation completed
cleanly. Invocation count was normal. Error count was zero. The only telemetry
that distinguished broken from working was **subrequest count**, which sat at
exactly 0 until secrets were bound and then rose to ~1.00 per invocation:

| Date | Invocations | Errors | Subrequests |
|---|---|---|---|
| 2026-07-20 → 07-27 | 91–102/day | 0 | **0** |
| 2026-07-28 | 101 | 0 | 86 |
| 2026-07-30 | 99 | 0 | 94 |

The generalisable failure signature is **"succeeded while making no outbound
calls"**, and SIGNAL 2 below is what watches for it. See BACKLOG.md CR20.

This matters beyond one cron. [[CR21]] made the cron the *only* retry path for
Stripe events — the Worker returns 2xx before processing — so nothing else will
ever tell you an event was lost.

---

## Data sources, and where they disagree

Three sources, and they do not agree with each other. Knowing which is
authoritative for what is the difference between a dashboard and a wrong
dashboard.

| Source | Good for | Caveat |
|---|---|---|
| **GraphQL `workersInvocationsAdaptive`** (`/client/v4/graphql`) | Counts and rates: requests, errors, subrequests, outcome status, per worker per day | No message bodies. This is the authoritative source for *rates*. |
| **Workers Logs** (`POST /accounts/{id}/workers/observability/telemetry/query`) | Individual events: log lines, cron expressions, request paths, levels | **Incomplete and shorter-lived.** See below. |
| **Supabase PostgREST** | Queue depth (`webhook_dead_letters`) | Application state, not telemetry. RLS-bypassing key required. |

**The two Cloudflare sources disagree, measured 2026-07-31.** For
`integrity-studio-contact`, GraphQL reported 34 invocations in 24h and 3
`scriptThrewException` on 2026-07-30, while a Workers Logs query over **72
hours** returned only 10 events, none of them an exception. Two reasons compound:
Workers Logs only captures from the moment `observability` was enabled on a
Worker — for `api-gateway` and `integrity-studio-contact` that was the
2026-07-30 deploy, so nothing before it exists — and its retention is shorter
than the analytics rollup's.

**Consequence for step 3:** build rate panels on GraphQL. Use Workers Logs for
drill-down only, and do not conclude "no errors" from an empty log query — the
contact-form exceptions are invisible there while GraphQL counts them.

A token note: an account-owned Cloudflare token verifies only at
`/accounts/<id>/tokens/verify` and returns `Invalid API Token` from the user
endpoint. That is not a broken token. It needs **Account Analytics Read**.

---

## The signals

Thresholds live at the top of
[`scripts/check-worker-signals.sh`](../scripts/check-worker-signals.sh) as named
constants; the values below mirror them.

### SIGNAL 1 — unhandled exceptions

`status: scriptThrewException`, threshold **0**.

A throw that escaped the handler. The caller got a Cloudflare `1101`, not an
application error response, so it is invisible to any check that reads response
bodies. Distinct from a 4xx/5xx the Worker chose to return.

### SIGNAL 2 — a cron that runs but does no work

Two paired checks on cron-driven Workers, currently `stripe-webhook` (`*/15`, 96/day):

- **Invocation floor** — fewer than 75% of the expected count means the cron is not firing.
- **Subrequest ratio** — below **0.5** means it is firing but not reaching its database.

The ratio is the one error rate cannot replace. A reconciliation tick issues at
least one Supabase read; a tick that issues none did nothing, however green it
looks. Applies to any future cron, not just this one.

### SIGNAL 3 — resource exhaustion

`status: exceededResources`, threshold **0**.

The isolate was killed for exceeding CPU or memory. No handler code ran, so
neither application logs nor response codes exist for these — they are only
visible in the invocation rollup.

### SIGNAL 4 — cross-repo receiver health

`api-provisioning-receiver` runs the same exception and exhaustion checks, but
**reported only, never failing the build**. `sender-worker`'s `/send` terminates
there, so a receiver failure breaks provisioning exactly as a sender failure
would — but it deploys from the `observability-toolkit` repo and this one cannot
fix it. Reporting it stops the failure being misattributed to the sender.

### SIGNAL 5 — dead-letter queue depth

`webhook_dead_letters`, thresholds: **pending > 10**, **abandoned > 0**.

- **pending** — awaiting retry. Sustained depth means the cron is not draining.
- **abandoned** — retries exhausted. Requires a manual Stripe replay; nothing recovers these automatically.

Optional; skipped without Supabase credentials. This is the signal CR27 proved
necessary: the first real Stripe traffic this account ever saw dead-lettered all
three events on two four-month-old defects, and nothing alerted.

### Not yet implemented

Named so they are not mistaken for covered:

- **`/send` error-rate split by code.** `ERROR_CODE.RECEIVER_ERROR`, `INTERNAL_ERROR` and the 502 "receiver-worker unreachable" path are distinguishable only in response bodies, which neither Cloudflare source records. Needs a counter emitted from the Worker.
- **Receiver 401 spikes** — signature or replay failures, i.e. attack or key-rotation drift. Cross-repo.
- **Provisioning latency.** GraphQL exposes wall-time quantiles; no threshold has been chosen, and picking one before there is real traffic would be inventing a number.
- **Auth0 / Supabase call failures** as distinct from the invocation failing.
- **Auth 429 rate** on `/signup` and `/signin` — brute-force indicator, now that `RATE_LIMIT_KV` is live (CR03).

---

## First run, 2026-07-31

The check found two live failures on its first execution, which is the argument
for it existing.

**🔴 `integrity-studio-contact` — 3 `scriptThrewException` on 2026-07-30**, out of
34 invocations (~9%). The contact form is the site's only lead-capture path, so
these plausibly cost three submissions. **Unexplained**: the exceptions predate
observability being enabled on that Worker, so no log line survives, and this is
recorded as unresolved rather than guessed at. If it recurs the logs will now
capture it.

**🔴 `obtool-ingest` — ~90% of invocations failing `exceededResources`**, ongoing,
and it is *not* deployed from this repo (`observability-toolkit`). Its `*/5` cron
fails essentially every run:

| Date | success | exceededResources |
|---|---|---|
| 2026-07-26 | 26,613 | 185 |
| 2026-07-27 | 4,045 | 154 |
| 2026-07-28 | 70 | 241 |
| 2026-07-29 | 31 | 257 |
| 2026-07-30 | 29 | 273 |

Successful ingest collapsed from tens of thousands per day to ~30 around
2026-07-28 while resource kills became the dominant outcome. **This directly
affects W04 step 3**, which proposes routing Worker telemetry through
`ingest.integritystudio.ai` — that pipeline is currently broken, so it cannot be
the destination until it is fixed. Belongs to the `observability-toolkit` owner.

Everything this repo owns was otherwise clean: `api-gateway`, `sender-worker` and
`stripe-webhook` all zero errors, and `webhook_dead_letters` empty on both
counts.
