#!/usr/bin/env bash
#
# Evaluate the Worker health signals defined in docs/observability-signals.md
# against live Cloudflare telemetry, and exit non-zero when any breaches.
#
# This is the executable half of BACKLOG.md W04 step 2.  Step 2 asks for the
# signals that matter to be *defined*; defining them in prose alone is how they
# go stale, so each one is also computed here.
#
# The signal set is shaped by BACKLOG.md CR20, which is the reason this script
# does not simply watch error rate.  `stripe-webhook`'s reconciliation cron ran
# ~96x/day for four months reporting `status: success` with `errors: 0` while
# making zero outbound calls: its Supabase client threw on unbound secrets and
# the failure was swallowed into an empty array.  Error rate was blind to a
# total outage.  What distinguished broken from working was the *subrequest
# count*, so SIGNAL 2 below watches exactly that.
#
# Usage:
#   CLOUDFLARE_API_TOKEN=<token> CLOUDFLARE_ACCOUNT_ID=<id> \
#     bash scripts/check-worker-signals.sh
#
#   # With Doppler:
#   CLOUDFLARE_API_TOKEN=$(doppler secrets get CLOUDFLARE_API_TOKEN \
#     --project integrity-studio --config prd --plain) \
#   CLOUDFLARE_ACCOUNT_ID=$(doppler secrets get CLOUDFLARE_ACCOUNT_ID \
#     --project integrity-studio --config prd --plain) \
#     bash scripts/check-worker-signals.sh
#
# Note on the token: an account-owned token (`cfat_` and some others) verifies
# only at /accounts/<id>/tokens/verify and returns "Invalid API Token" from the
# user endpoint.  This script does not verify the token, it just uses it; a 403
# here usually means the token lacks Account Analytics Read.
#
# Exit codes:
#   0  every signal within threshold, OR skipped because credentials are unset
#   1  one or more signals breached
#   2  prerequisites missing or the API call failed

set -uo pipefail

# Cron cadence per worker, used to derive expected invocation counts.
# stripe-webhook reconciles dead letters every 15 minutes -> 96/day.
readonly STRIPE_WEBHOOK_CRON_PER_DAY=96
# Tolerate scheduler jitter and partial days at the window boundary.
readonly CRON_MISS_TOLERANCE=0.75
# A reconciliation tick issues at least one Supabase read.  Below this ratio the
# worker is running without reaching its database - the CR20 failure signature.
#
# 🔴 TEMPORARY 2026-08-08 — set to an unreachable 99 to force exactly one breach,
# so that CR20's *notification* half can be observed rather than assumed. The
# scheduled path only proves the job RUNS; the alert channel is GitHub's
# job-FAILURE email, so a passing run notifies nobody and proves nothing about
# whether anyone would be told. stripe-webhook's real ratio is ~1.00, so 99
# guarantees a single deterministic breach and exit 1.
#
# REVERT TO: readonly MIN_SUBREQUEST_RATIO=0.5
# immediately after the failure email is confirmed. Left in place, this check
# fails every run and becomes noise that trains the owner to ignore it — the
# precise way an alert dies quietly.
readonly MIN_SUBREQUEST_RATIO=99
# Any scriptThrewException is worth surfacing; these are unhandled throws.
readonly MAX_EXCEPTIONS=0
# Pending dead letters awaiting retry.  Sustained depth means the cron is not
# draining.  Abandoned rows have exhausted retries and need manual replay.
readonly MAX_PENDING_DEAD_LETTERS=10
readonly MAX_ABANDONED_DEAD_LETTERS=0

readonly WINDOW_DAYS=1

if [[ -z "${CLOUDFLARE_API_TOKEN:-}" || -z "${CLOUDFLARE_ACCOUNT_ID:-}" ]]; then
  echo "SKIPPED: CLOUDFLARE_API_TOKEN / CLOUDFLARE_ACCOUNT_ID not set."
  echo "         Set both to evaluate signals; see the header for a Doppler invocation."
  exit 0
fi

for cmd in curl python3; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "error: $cmd is required" >&2; exit 2; }
done

export CF_TOKEN="$CLOUDFLARE_API_TOKEN"
export CF_ACCOUNT="$CLOUDFLARE_ACCOUNT_ID"
export SB_URL="${SUPABASE_URL:-}"
export SB_KEY="${SUPABASE_SERVICE_ROLE_KEY:-}"
export CFG_STRIPE_CRON_PER_DAY="$STRIPE_WEBHOOK_CRON_PER_DAY"
export CFG_CRON_TOLERANCE="$CRON_MISS_TOLERANCE"
export CFG_MIN_SUBREQ_RATIO="$MIN_SUBREQUEST_RATIO"
export CFG_MAX_EXCEPTIONS="$MAX_EXCEPTIONS"
export CFG_MAX_PENDING="$MAX_PENDING_DEAD_LETTERS"
export CFG_MAX_ABANDONED="$MAX_ABANDONED_DEAD_LETTERS"
export CFG_WINDOW_DAYS="$WINDOW_DAYS"

python3 - <<'PYEOF'
import json, os, sys, urllib.request, urllib.error
from datetime import datetime, timedelta, timezone

TOKEN = os.environ["CF_TOKEN"]
ACCOUNT = os.environ["CF_ACCOUNT"]
WINDOW_DAYS = int(os.environ["CFG_WINDOW_DAYS"])
STRIPE_CRON_PER_DAY = int(os.environ["CFG_STRIPE_CRON_PER_DAY"])
CRON_TOLERANCE = float(os.environ["CFG_CRON_TOLERANCE"])
MIN_SUBREQ_RATIO = float(os.environ["CFG_MIN_SUBREQ_RATIO"])
MAX_EXCEPTIONS = int(os.environ["CFG_MAX_EXCEPTIONS"])
MAX_PENDING = int(os.environ["CFG_MAX_PENDING"])
MAX_ABANDONED = int(os.environ["CFG_MAX_ABANDONED"])

# Workers this repo owns and deploys.  api-provisioning-receiver is listed
# because sender-worker's /send path terminates there and a receiver failure is
# indistinguishable from a sender failure without it -- but it is deployed from
# the observability-toolkit repo, so it is reported and never fails the build.
OWNED = ["api-gateway", "sender-worker", "stripe-webhook", "integrity-studio-contact"]
FOREIGN = ["api-provisioning-receiver"]

# Workers whose invocations are cron-driven, with their expected daily count.
CRON_WORKERS = {"stripe-webhook": STRIPE_CRON_PER_DAY}

breaches = []
notes = []


def graphql(query):
    req = urllib.request.Request(
        "https://api.cloudflare.com/client/v4/graphql",
        data=json.dumps({"query": query}).encode(),
        headers={"Authorization": "Bearer " + TOKEN, "Content-Type": "application/json"},
    )
    try:
        body = json.load(urllib.request.urlopen(req, timeout=30))
    except urllib.error.HTTPError as exc:
        print("error: Cloudflare GraphQL returned %s: %s" % (exc.code, exc.read().decode()[:200]), file=sys.stderr)
        sys.exit(2)
    except Exception as exc:
        print("error: Cloudflare GraphQL request failed: %s" % exc, file=sys.stderr)
        sys.exit(2)
    if body.get("errors"):
        print("error: GraphQL errors: %s" % json.dumps(body["errors"])[:300], file=sys.stderr)
        sys.exit(2)
    return body


since = (datetime.now(timezone.utc) - timedelta(days=WINDOW_DAYS)).strftime("%Y-%m-%d")
until = datetime.now(timezone.utc).strftime("%Y-%m-%d")

query = """
query {
  viewer {
    accounts(filter: {accountTag: "%s"}) {
      workersInvocationsAdaptive(
        limit: 1000,
        filter: {date_geq: "%s", date_leq: "%s"}
      ) {
        sum { requests errors subrequests }
        dimensions { scriptName status }
      }
    }
  }
}
""" % (ACCOUNT, since, until)

accounts = graphql(query)["data"]["viewer"]["accounts"]
if not accounts:
    print("error: no account matched %s" % ACCOUNT, file=sys.stderr)
    sys.exit(2)
rows = accounts[0]["workersInvocationsAdaptive"]

# Fold the per-status rows into one record per worker.
agg = {}
for row in rows:
    name = row["dimensions"]["scriptName"]
    status = row["dimensions"]["status"]
    sums = row["sum"]
    rec = agg.setdefault(name, {"requests": 0, "errors": 0, "subrequests": 0, "by_status": {}})
    rec["requests"] += sums["requests"]
    rec["errors"] += sums["errors"]
    rec["subrequests"] += sums["subrequests"]
    rec["by_status"][status] = rec["by_status"].get(status, 0) + sums["requests"]

print("Worker signals over the last %d day(s) (%s..%s)\n" % (WINDOW_DAYS, since, until))
print("  %-28s %8s %8s %10s %8s" % ("worker", "reqs", "errors", "subreqs", "ratio"))
for name in OWNED + FOREIGN:
    rec = agg.get(name)
    if not rec:
        print("  %-28s %8s" % (name, "no data"))
        continue
    ratio = rec["subrequests"] / rec["requests"] if rec["requests"] else 0.0
    print("  %-28s %8d %8d %10d %8.2f" % (name, rec["requests"], rec["errors"], rec["subrequests"], ratio))
print()

for name in OWNED:
    rec = agg.get(name)
    if not rec:
        notes.append("%s: no invocations in window (idle worker, or telemetry off)" % name)
        continue

    # SIGNAL 1 - unhandled exceptions.  Any scriptThrewException is a real throw
    # that escaped the handler; the caller got a 1101, not an application error.
    thrown = rec["by_status"].get("scriptThrewException", 0)
    if thrown > MAX_EXCEPTIONS:
        breaches.append("%s: %d scriptThrewException (max %d)" % (name, thrown, MAX_EXCEPTIONS))

    # SIGNAL 2 - a cron that runs but does no work.  See the CR20 note above:
    # this is the check that error rate cannot make.
    expected = CRON_WORKERS.get(name)
    if expected:
        floor = expected * WINDOW_DAYS * CRON_TOLERANCE
        if rec["requests"] < floor:
            breaches.append(
                "%s: %d invocations, expected >= %.0f for its cron cadence - cron may not be firing"
                % (name, rec["requests"], floor)
            )
        ratio = rec["subrequests"] / rec["requests"] if rec["requests"] else 0.0
        if rec["requests"] and ratio < MIN_SUBREQ_RATIO:
            breaches.append(
                "%s: subrequest ratio %.2f below %.2f - running without reaching its database (CR20 signature)"
                % (name, ratio, MIN_SUBREQ_RATIO)
            )

    # SIGNAL 3 - resource exhaustion.  Distinct from a thrown exception: the
    # isolate was killed for exceeding CPU or memory, so no handler code ran.
    exhausted = rec["by_status"].get("exceededResources", 0)
    if exhausted:
        breaches.append("%s: %d invocations killed for exceededResources" % (name, exhausted))

# SIGNAL 4 - the same checks on the cross-repo receiver, reported only.  A
# failure here breaks provisioning just as surely, but this repo cannot fix it.
for name in FOREIGN:
    rec = agg.get(name)
    if not rec:
        continue
    for status in ("scriptThrewException", "exceededResources"):
        count = rec["by_status"].get(status, 0)
        if count:
            notes.append("%s (cross-repo, observability-toolkit): %d %s" % (name, count, status))

# SIGNAL 5 - dead-letter queue depth.  Optional: needs Supabase credentials.
# CR21 made the reconciliation cron the only retry path, so a queue that is not
# draining is the single remaining indicator that Stripe events are being lost.
sb_url = os.environ.get("SB_URL", "")
sb_key = os.environ.get("SB_KEY", "")
if sb_url and sb_key:
    def dead_letter_count(status):
        url = "%s/rest/v1/webhook_dead_letters?select=id&status=eq.%s" % (sb_url.rstrip("/"), status)
        req = urllib.request.Request(url, headers={
            "apikey": sb_key,
            "Authorization": "Bearer " + sb_key,
            "Prefer": "count=exact",
            "Range": "0-0",
        })
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                content_range = resp.headers.get("content-range", "*/0")
        except Exception as exc:
            notes.append("dead-letter depth unavailable: %s" % exc)
            return None
        return int(content_range.split("/")[-1])

    pending = dead_letter_count("pending")
    abandoned = dead_letter_count("abandoned")
    if pending is not None:
        print("  webhook_dead_letters: pending=%s abandoned=%s\n" % (pending, abandoned))
        if pending > MAX_PENDING:
            breaches.append("webhook_dead_letters: %d pending (max %d) - cron is not draining" % (pending, MAX_PENDING))
        if abandoned is not None and abandoned > MAX_ABANDONED:
            breaches.append(
                "webhook_dead_letters: %d abandoned - retries exhausted, manual Stripe replay required"
                % abandoned
            )
else:
    notes.append("dead-letter depth not checked: set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY")

for note in notes:
    print("NOTE: %s" % note)
if notes:
    print()

if breaches:
    print("FAIL: %d signal(s) breached\n" % len(breaches))
    for breach in breaches:
        print("  - %s" % breach)
    print("\nSee docs/observability-signals.md for what each signal means.")
    sys.exit(1)

print("OK: all signals within threshold")
sys.exit(0)
PYEOF
