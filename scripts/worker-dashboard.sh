#!/usr/bin/env bash
#
# Render an operational dashboard for the provisioning path and the production
# Workers around it, from Cloudflare Workers Analytics (GraphQL).
#
# This is BACKLOG.md W04 step 3.  Step 2 built `check:worker-signals`, which is a
# pass/fail gate over a 1-day window; this is the surface you read when that gate
# fires, or when asking "is the provisioning path healthy?".  The two are
# deliberately separate: a gate that also tries to be a dashboard grows
# thresholds for things nobody wants to fail the build on.
#
# ── Why GraphQL and not the internal OTEL pipeline ───────────────────────────
# W04 step 3 offers two destinations: "Cloudflare Workers Analytics, or route
# through the existing internal OTEL pipeline".  The step was recorded as blocked
# from 2026-07-31 because the second one -- `obtool-ingest` -- was failing.  That
# blocker is real and still live (see the note in BACKLOG.md W04 step 3), but it
# only ever applied to that one option.  Workers Analytics needs nothing built
# and nothing repaired, and step 2's own caveat already mandates it for rate
# panels:
#
#   "Build rate panels on GraphQL; use Logs for drill-down only, and never read
#    an empty log query as 'no errors'."
#
# The two Cloudflare sources disagree -- Workers Logs only captures from the
# moment `observability` was enabled on each Worker (2026-07-30 for api-gateway
# and integrity-studio-contact) and its retention is shorter than the analytics
# rollup's.  So this dashboard reads GraphQL exclusively.
#
# ── Why the resource panel exists ────────────────────────────────────────────
# CR20's lesson is that error rate is blind: `stripe-webhook` reported
# `status: success, errors: 0` through a four-month total outage.  The resource
# panel is the same lesson applied to the other failure mode -- a Worker killed
# for exceeding CPU never runs handler code, so it throws no exception and logs
# nothing.  Watching cpuTime P99 against the *configured* `cpu_ms` limit predicts
# that kill before it starts dropping data, which watching `errors` cannot.
#
# The limit is read live from each script's settings endpoint rather than parsed
# from a wrangler.toml, so it cannot drift from what is deployed and it works for
# Workers deployed out of other repos (the receiver and ingest live in
# observability-toolkit).
#
# Usage:
#   CLOUDFLARE_API_TOKEN=<token> CLOUDFLARE_ACCOUNT_ID=<id> \
#     bash scripts/worker-dashboard.sh
#
#   # With Doppler:
#   CLOUDFLARE_API_TOKEN=$(doppler secrets get CLOUDFLARE_API_TOKEN \
#     --project integrity-studio --config prd --plain) \
#   CLOUDFLARE_ACCOUNT_ID=$(doppler secrets get CLOUDFLARE_ACCOUNT_ID \
#     --project integrity-studio --config prd --plain) \
#     bash scripts/worker-dashboard.sh
#
#   # Window other than the default 7 days:
#   DASHBOARD_WINDOW_DAYS=14 bash scripts/worker-dashboard.sh
#
# Token note: an account-owned token (`cfat_`) verifies only at
# /accounts/<id>/tokens/verify, never the user endpoint.  This script does not
# verify the token; a 403 usually means it lacks Account Analytics Read.
#
# Exit codes:
#   0  dashboard rendered, OR skipped because credentials are unset
#   2  prerequisites missing or the API call failed
#
# This is an observation surface, not a gate -- it does NOT exit non-zero on an
# unhealthy reading.  `npm run check:worker-signals` is the gate.

set -uo pipefail

readonly DEFAULT_WINDOW_DAYS=7

# Cloudflare Workers memory ceiling, a platform constant rather than a per-script
# setting: https://developers.cloudflare.com/workers/platform/limits/
readonly WORKER_MEMORY_LIMIT_BYTES=134217728

# Fraction of a Worker's configured cpu_ms (or of the memory ceiling) at which
# the reading is worth flagging.  Not a failure threshold -- see the exit-code
# note above; it only decides whether a row is annotated.
readonly RESOURCE_WARN_FRACTION=0.8

WINDOW_DAYS="${DASHBOARD_WINDOW_DAYS:-$DEFAULT_WINDOW_DAYS}"

if [[ -z "${CLOUDFLARE_API_TOKEN:-}" || -z "${CLOUDFLARE_ACCOUNT_ID:-}" ]]; then
  echo "SKIPPED: CLOUDFLARE_API_TOKEN / CLOUDFLARE_ACCOUNT_ID not set."
  echo "         Set both to render the dashboard; see the header for a Doppler invocation."
  exit 0
fi

for cmd in curl python3; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "error: $cmd is required" >&2; exit 2; }
done

export CF_TOKEN="$CLOUDFLARE_API_TOKEN"
export CF_ACCOUNT="$CLOUDFLARE_ACCOUNT_ID"
export CFG_WINDOW_DAYS="$WINDOW_DAYS"
export CFG_MEMORY_LIMIT_BYTES="$WORKER_MEMORY_LIMIT_BYTES"
export CFG_WARN_FRACTION="$RESOURCE_WARN_FRACTION"

python3 - <<'PYEOF'
import json, os, sys, urllib.request, urllib.error
from datetime import datetime, timedelta, timezone

TOKEN = os.environ["CF_TOKEN"]
ACCOUNT = os.environ["CF_ACCOUNT"]
WINDOW_DAYS = int(os.environ["CFG_WINDOW_DAYS"])
MEMORY_LIMIT_BYTES = int(os.environ["CFG_MEMORY_LIMIT_BYTES"])
WARN_FRACTION = float(os.environ["CFG_WARN_FRACTION"])

API_BASE = "https://api.cloudflare.com/client/v4"
GRAPHQL_URL = API_BASE + "/graphql"
REQUEST_TIMEOUT_S = 30
GRAPHQL_ROW_LIMIT = 10000

MICROSECONDS_PER_MS = 1000.0
BYTES_PER_MIB = 1048576.0

# The provisioning path this item exists to watch.  sender-worker's /send
# terminates in api-provisioning-receiver, so a receiver failure is
# indistinguishable from a sender failure unless both are on the same panel.
PROVISIONING_PATH = ["sender-worker", "api-provisioning-receiver"]

# Everything else deployed in production, so the dashboard covers what the alert
# covers.  api-gateway and integrity-studio-contact are this repo's;
# api-provisioning-receiver and obtool-ingest deploy from observability-toolkit.
OTHER_WORKERS = ["api-gateway", "stripe-webhook", "integrity-studio-contact", "obtool-ingest"]

FOREIGN_WORKERS = {"api-provisioning-receiver", "obtool-ingest"}

# Cloudflare's invocation statuses.  `success` is healthy and
# `clientDisconnected` means the caller hung up before the response -- neither
# indicates a Worker fault.  Everything else is a real failure.
STATUS_SUCCESS = "success"
STATUS_CLIENT_DISCONNECTED = "clientDisconnected"
BENIGN_STATUSES = {STATUS_SUCCESS, STATUS_CLIENT_DISCONNECTED}

SPARK_CHARS = "▁▂▃▄▅▆▇█"


def graphql(query):
    req = urllib.request.Request(
        GRAPHQL_URL,
        data=json.dumps({"query": query}).encode(),
        headers={"Authorization": "Bearer " + TOKEN, "Content-Type": "application/json"},
    )
    try:
        body = json.load(urllib.request.urlopen(req, timeout=REQUEST_TIMEOUT_S))
    except urllib.error.HTTPError as exc:
        print("error: Cloudflare GraphQL returned %s: %s"
              % (exc.code, exc.read().decode()[:200]), file=sys.stderr)
        sys.exit(2)
    except Exception as exc:
        print("error: Cloudflare GraphQL request failed: %s" % exc, file=sys.stderr)
        sys.exit(2)
    if body.get("errors"):
        print("error: GraphQL errors: %s" % json.dumps(body["errors"])[:300], file=sys.stderr)
        sys.exit(2)
    return body


def script_settings(name):
    """Live deployed settings for a script, or None if unreadable.

    Read from the API rather than parsed from a wrangler.toml: the settings that
    matter are the deployed ones, and two of these Workers deploy from another
    repo. Supplies both the cpu_ms limit and whether observability is on -- the
    latter is what separates "no invocations because idle" from "no invocations
    recorded because the Worker is dark", which are the same empty table.
    """
    req = urllib.request.Request(
        "%s/accounts/%s/workers/scripts/%s/settings" % (API_BASE, ACCOUNT, name),
        headers={"Authorization": "Bearer " + TOKEN},
    )
    try:
        body = json.load(urllib.request.urlopen(req, timeout=REQUEST_TIMEOUT_S))
    except Exception:
        return None
    return (body.get("result") or {}) if body.get("success") else None


def sparkline(values):
    if not values:
        return ""
    peak = max(values)
    if peak <= 0:
        return SPARK_CHARS[0] * len(values)
    return "".join(
        SPARK_CHARS[min(len(SPARK_CHARS) - 1, int(v / peak * (len(SPARK_CHARS) - 1)))]
        for v in values
    )


since_dt = datetime.now(timezone.utc) - timedelta(days=WINDOW_DAYS)
since = since_dt.strftime("%Y-%m-%d")
until = datetime.now(timezone.utc).strftime("%Y-%m-%d")

daily_query = """
query {
  viewer {
    accounts(filter: {accountTag: "%s"}) {
      workersInvocationsAdaptive(
        limit: %d,
        filter: {date_geq: "%s", date_leq: "%s"}
      ) {
        sum { requests errors subrequests }
        dimensions { scriptName status date }
      }
    }
  }
}
""" % (ACCOUNT, GRAPHQL_ROW_LIMIT, since, until)

resource_query = """
query {
  viewer {
    accounts(filter: {accountTag: "%s"}) {
      workersInvocationsAdaptive(
        limit: %d,
        filter: {date_geq: "%s", date_leq: "%s"}
      ) {
        sum { requests }
        quantiles { cpuTimeP50 cpuTimeP99 durationP99 memoryUsageBytesP99 }
        dimensions { scriptName }
      }
    }
  }
}
""" % (ACCOUNT, GRAPHQL_ROW_LIMIT, since, until)

accounts = graphql(daily_query)["data"]["viewer"]["accounts"]
if not accounts:
    print("error: no account matched %s" % ACCOUNT, file=sys.stderr)
    sys.exit(2)
daily_rows = accounts[0]["workersInvocationsAdaptive"]
resource_rows = graphql(resource_query)["data"]["viewer"]["accounts"][0]["workersInvocationsAdaptive"]

dates = sorted({row["dimensions"]["date"] for row in daily_rows})

# worker -> {"total": {...}, "per_day": {date: {status: requests}}}
agg = {}
for row in daily_rows:
    dims = row["dimensions"]
    name, status, date = dims["scriptName"], dims["status"], dims["date"]
    sums = row["sum"]
    rec = agg.setdefault(name, {
        "requests": 0, "errors": 0, "subrequests": 0,
        "by_status": {}, "per_day": {},
    })
    rec["requests"] += sums["requests"]
    rec["errors"] += sums["errors"]
    rec["subrequests"] += sums["subrequests"]
    rec["by_status"][status] = rec["by_status"].get(status, 0) + sums["requests"]
    rec["per_day"].setdefault(date, {})[status] = \
        rec["per_day"].setdefault(date, {}).get(status, 0) + sums["requests"]

resources = {row["dimensions"]["scriptName"]: row["quantiles"] for row in resource_rows}

ALL_WORKERS = PROVISIONING_PATH + OTHER_WORKERS
settings = {name: script_settings(name) for name in ALL_WORKERS}
cpu_limits = {
    name: ((s or {}).get("limits") or {}).get("cpu_ms") for name, s in settings.items()
}

notes = []


def idle_reason(name):
    """Why a Worker shows no invocations -- never inferred, always read."""
    conf = settings.get(name)
    if conf is None:
        return "no invocations in the window, and its settings could not be read"
    if not (conf.get("observability") or {}).get("enabled"):
        return ("no invocations RECORDED, and observability is disabled on it -- "
                "this is a dark Worker, not an idle one")
    return "no invocations in the window; observability is on, so it is genuinely idle"


def failures(rec):
    return sum(n for status, n in rec["by_status"].items() if status not in BENIGN_STATUSES)


def label(name):
    return name + (" *" if name in FOREIGN_WORKERS else "")


def print_summary_table(names, heading):
    print(heading)
    print("  %-30s %9s %9s %8s %9s  %s" % ("worker", "invocs", "failed", "fail%", "subreq/req", "statuses"))
    for name in names:
        rec = agg.get(name)
        if not rec:
            print("  %-30s %9s" % (label(name), "no data"))
            notes.append("%s: %s" % (name, idle_reason(name)))
            continue
        failed = failures(rec)
        # rec["requests"] already sums every status row, failures included -- so
        # it IS the invocation total and must not have `failed` added back on.
        total = rec["requests"]
        fail_pct = (failed / total * 100.0) if total else 0.0
        ratio = (rec["subrequests"] / rec["requests"]) if rec["requests"] else 0.0
        detail = " ".join(
            "%s=%d" % (s, n) for s, n in sorted(rec["by_status"].items())
            if s != STATUS_SUCCESS
        ) or "-"
        print("  %-30s %9d %9d %7.1f%% %9.2f  %s"
              % (label(name), rec["requests"], failed, fail_pct, ratio, detail))
    print()


print("=" * 78)
print("Worker dashboard - provisioning path and production fleet")
print("  window : %s .. %s (%d day%s)" % (since, until, WINDOW_DAYS, "" if WINDOW_DAYS == 1 else "s"))
print("  source : Cloudflare Workers Analytics (GraphQL)")
print("  gate   : npm run check:worker-signals  (this script never fails a build)")
print("=" * 78)
print()

print_summary_table(PROVISIONING_PATH, "PROVISIONING PATH  (sender-worker /send -> api-provisioning-receiver /inbox)")
print_summary_table(OTHER_WORKERS, "OTHER PRODUCTION WORKERS")

print("DAILY TREND  (successes, then failures; each row scaled to its OWN peak,")
print("              so heights are comparable within a row and never between rows)")
print("  %-30s %-*s %10s   %s" % ("worker", max(len(dates), 1), "successes", "peak/day", "failures"))
for name in ALL_WORKERS:
    rec = agg.get(name)
    if not rec:
        continue
    req_series, fail_series = [], []
    for date in dates:
        day = rec["per_day"].get(date, {})
        req_series.append(day.get(STATUS_SUCCESS, 0))
        fail_series.append(sum(n for s, n in day.items() if s not in BENIGN_STATUSES))
    print("  %-30s %s %10d   %s"
          % (label(name), sparkline(req_series), max(req_series) if req_series else 0,
             sparkline(fail_series) if any(fail_series) else "-"))
print()
if dates:
    print("  days: %s .. %s (left to right)" % (dates[0], dates[-1]))
    print()

print("RESOURCE HEADROOM  (the failure mode error rate cannot see - see header)")
print("  %-30s %9s %9s %11s %10s %9s"
      % ("worker", "cpu p50", "cpu p99", "cpu limit", "p99/limit", "mem p99"))
for name in ALL_WORKERS:
    quant = resources.get(name)
    if not quant:
        continue
    cpu_p50_ms = (quant.get("cpuTimeP50") or 0) / MICROSECONDS_PER_MS
    cpu_p99_ms = (quant.get("cpuTimeP99") or 0) / MICROSECONDS_PER_MS
    mem_p99 = quant.get("memoryUsageBytesP99") or 0
    limit_ms = cpu_limits.get(name)

    if limit_ms:
        used = cpu_p99_ms / limit_ms
        limit_text, used_text = "%d ms" % limit_ms, "%.0f%%" % (used * 100.0)
        if used >= 1.0:
            notes.append(
                "%s: cpu p99 %.0f ms EXCEEDS its configured %d ms limit - the top "
                "percentile of invocations is being killed before handler code runs"
                % (name, cpu_p99_ms, limit_ms))
        elif used >= WARN_FRACTION:
            notes.append("%s: cpu p99 is %.0f%% of its %d ms limit"
                         % (name, used * 100.0, limit_ms))
    else:
        limit_text, used_text = "default", "-"

    mem_used = mem_p99 / MEMORY_LIMIT_BYTES
    if mem_used >= WARN_FRACTION:
        notes.append("%s: memory p99 is %.0f%% of the %d MiB ceiling"
                     % (name, mem_used * 100.0, int(MEMORY_LIMIT_BYTES / BYTES_PER_MIB)))

    print("  %-30s %8.1fms %8.1fms %11s %10s %8.1fMB"
          % (label(name), cpu_p50_ms, cpu_p99_ms, limit_text, used_text, mem_p99 / BYTES_PER_MIB))
print()

if any(name in agg for name in FOREIGN_WORKERS):
    print("  * deployed from observability-toolkit, not this repo")
    print()

for note in notes:
    print("NOTE: %s" % note)
if notes:
    print()

print("Signal definitions: docs/observability-signals.md")
print("Runbook:            docs/api-provisioning.md")
sys.exit(0)
PYEOF
