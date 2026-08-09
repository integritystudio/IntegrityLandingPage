#!/usr/bin/env bash
# W11 — fail when a workflow that exists on disk is not `active` on GitHub.
#
# Why this exists, measured rather than supposed.  `e2e.yml` ran nightly through
# 2026-06-09 and then produced NOTHING until 2026-08-08 — no schedule runs and no
# push runs — while `ci.yml` recorded 71 runs over the same window from the same
# pushes to the same branch.  W11 offered two candidates and both are refuted by
# that pair: cron suspension only stops `schedule` events (push runs are missing
# too), and "no qualifying push reached main" is contradicted by ~270 commits.
# The workflow was DISABLED, and a disabled workflow is perfectly silent — no red
# build, no notification, nothing in any log.  Two months of Playwright coverage
# were absent and the only symptom was a test that had quietly gone stale.
#
# Both repos already carry a note that nothing checks whether their checks run
# (CR20 here, INGEST-CPU-STARVATION in observability-toolkit).  This is that
# check, and it deliberately watches the *files*, not a hand-maintained list:
# adding a workflow enrolls it automatically, and deleting one retires it.  A
# pinned list would need editing on every change, which is how a guard decays
# into a formality.
#
# Exit codes (matching the sibling check-worker-signals.sh):
#   0  every on-disk workflow is active, OR skipped because GH_TOKEN is unset
#   1  one or more workflows are disabled
#   2  prerequisites missing, or the GitHub API call failed
#
# Usage: GH_TOKEN=$(gh auth token) bash scripts/check-workflows-active.sh
set -uo pipefail

readonly REPO="${GH_REPO:-integritystudio/IntegrityLandingPage}"
readonly WORKFLOW_DIR=".github/workflows"

# Absent credentials SKIP; present-but-failing ones FAIL.  The distinction is
# load-bearing: treating them as one case is what let an expired token switch a
# signal off behind a green tick (observability-toolkit 61ad14e).
if [[ -z "${GH_TOKEN:-}" ]]; then
  echo "SKIPPED: GH_TOKEN not set."
  echo "         Run with: GH_TOKEN=\$(gh auth token) bash scripts/check-workflows-active.sh"
  exit 0
fi

for cmd in curl python3; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "error: $cmd is required" >&2; exit 2; }
done

if [[ ! -d "$WORKFLOW_DIR" ]]; then
  echo "error: $WORKFLOW_DIR not found — run this from the repository root" >&2
  exit 2
fi

API_RESPONSE="$(curl -sS -w '\n%{http_code}' \
  -H "Authorization: Bearer ${GH_TOKEN}" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/${REPO}/actions/workflows?per_page=100" 2>&1)" || {
  echo "error: GitHub API request failed for ${REPO}" >&2
  exit 2
}

export API_RESPONSE
export WORKFLOW_DIR

python3 <<'PYEOF'
import json
import os
import sys
from pathlib import Path

raw = os.environ["API_RESPONSE"]
workflow_dir = Path(os.environ["WORKFLOW_DIR"])

body, _, status = raw.rpartition("\n")
if status.strip() != "200":
    print("error: GitHub API returned HTTP %s" % status.strip(), file=sys.stderr)
    print(body[:400], file=sys.stderr)
    sys.exit(2)

try:
    payload = json.loads(body)
except ValueError as exc:
    print("error: GitHub API response was not JSON (%s)" % exc, file=sys.stderr)
    sys.exit(2)

remote = {w["path"]: w.get("state", "unknown") for w in payload.get("workflows", [])}

# The files are the source of truth for what SHOULD run.  A workflow present in
# the API but absent from disk is a stale registration, not a coverage gap.
on_disk = sorted(
    str(p) for p in workflow_dir.iterdir()
    if p.suffix in (".yml", ".yaml") and p.is_file()
)
if not on_disk:
    print("error: no workflow files found under %s" % workflow_dir, file=sys.stderr)
    sys.exit(2)

breaches = []
notes = []

for path in on_disk:
    state = remote.get(path)
    if state is None:
        # Never registered — GitHub only knows a workflow once it has appeared on
        # the default branch.  Expected on a feature branch; not a breach.
        notes.append("%s is not registered with GitHub yet (new, or not on the default branch)" % path)
        continue
    print("  %-52s %s" % (path, state))
    if state != "active":
        breaches.append("%s is %s — it will not run on ANY trigger" % (path, state))

for path in sorted(set(remote) - set(on_disk)):
    notes.append("%s is registered with GitHub but absent from disk (stale registration)" % path)

print()
for note in notes:
    print("NOTE: %s" % note)
if notes:
    print()

if breaches:
    print("FAIL: %d workflow(s) not active\n" % len(breaches))
    for breach in breaches:
        print("  - %s" % breach)
    print(
        "\nA disabled workflow produces no runs, no failures and no notifications.\n"
        "Re-enable with: gh workflow enable <name>\n"
        "See W11 in docs/BACKLOG.md — this is how two months of Playwright coverage went missing."
    )
    sys.exit(1)

print("OK: all %d on-disk workflow(s) active" % len(on_disk))
sys.exit(0)
PYEOF
