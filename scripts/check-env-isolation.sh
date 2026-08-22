#!/usr/bin/env bash
#
# Verify that the Doppler `dev` config is actually a separate environment from
# `prd` (BACKLOG.md CR11).
#
# On 2026-07-27 every credential below was byte-identical between the two
# configs, so `--config dev` selected the production Supabase project and the
# production Auth0 tenant. Documentation claimed the opposite ("E2E tests use
# --config dev (isolated from prod)"), and nothing detected the drift.
#
# This script is that detector. It compares hashes only — no secret value is
# printed, so it is safe to run in CI and paste output into a ticket.
#
# Usage:
#   bash scripts/check-env-isolation.sh            # compare dev vs prd
#   BASE_CONFIG=stg bash scripts/check-env-isolation.sh
#
# Exit codes:
#   0  every credential differs between the two configs
#   1  at least one is shared, empty in both, or missing — not isolated
#   2  prerequisites missing (doppler CLI, or not logged in)

set -uo pipefail

PROJECT="${DOPPLER_PROJECT:-integrity-studio}"
BASE_CONFIG="${BASE_CONFIG:-dev}"
PROD_CONFIG="${PROD_CONFIG:-prd}"

# Credentials that must differ for the environments to be meaningfully separate.
# Each one, if shared, means a dev-config process reads or writes production
# state: the database, the identity tenant, or the inter-worker trust boundary.
#
# SUPABASE_SERVICE_ROLE_KEY is deliberately RETAINED even though the slot exists
# in neither config (measured 2026-08-02). It is a tripwire, not a live row: if
# anyone re-creates that name it must be compared again. It no longer counts as
# an isolation failure — see the ABSENT verdict below, which exists because a
# name nobody sets is "not measured", not "not isolated". Reading those as the
# same thing inflated this detector's count by one from 2026-07-29 to 2026-08-02
# and masked the two rows underneath it.
SECRETS=(
  SUPABASE_URL
  SUPABASE_SERVICE_ROLE_KEY
  SUPABASE_PROVISIONING_KEY
  SUPABASE_INTEGRITY_MEMERSHIP_KEY
  SUPABASE_ANON_KEY
  SUPABASE_JWT_SECRET
  AUTH0_DOMAIN
  AUTH0_CLIENT_ID
  AUTH0_CLIENT_SECRET
  AUTH0_CLI_ID
  AUTH0_CLI_SECRET
  # Added 2026-08-08 (W09). All three held PRODUCTION tenant values under `dev`
  # while AUTH0_DOMAIN correctly held the dev tenant's — a split-tenant config
  # this list could not see, because it named only the unprefixed spelling.
  # VITE_AUTH0_DOMAIN is what the dashboard SPA builds against, so the two
  # disagreeing is not cosmetic: once DEV_WORKER_URL pointed at a Worker that
  # verifies dev-tenant JWTs, a production-tenant login could not authenticate
  # against it at all.
  #
  # ⚠️ VITE_AUTH0_AUDIENCE is deliberately NOT here. An Auth0 API identifier is
  # just a name and each tenant registers its own under it, so that one is
  # legitimately byte-identical across configs — adding it would manufacture a
  # permanent failure and train the reader to ignore this check.
  VITE_AUTH0_DOMAIN
  VITE_AUTH0_CLIENT_ID
  AUTH0_TENANT_NAME
  # Added 2026-08-08 (W09 closure). Every one held a PRODUCTION identifier under
  # `dev` while its unprefixed twin held the correct dev value — the same defect
  # as VITE_AUTH0_DOMAIN, repeated for Supabase, KV and the home org.
  #
  # These are the reason the sweep below exists. All six were invisible to this
  # list for as long as the list did not name them, and they were found by an
  # ad-hoc full-config diff rather than by this script. They are pinned here so
  # a regression fails on the named row as well as in the sweep — two
  # independent detections, because the sweep's allowlist is itself editable.
  #
  # ⚠️ Latent, not live: nothing read any of them at the time of the fix. That is
  # not a reason to relax. PROVISION_WORKER_URL was latent in exactly this way
  # until a test suite picked it up and started writing production.
  VITE_SUPABASE_URL
  REACT_APP_SUPABASE_URL
  VITE_SUPABASE_ANON_KEY
  REACT_APP_SUPABASE_ANON_KEY
  CLOUDFLARE_KV_NAMESPACE_ID
  HOME_ORG_ID
  SHARED_SECRET
  STRIPE_SECRET_KEY
  STRIPE_API_KEY
  STRIPE_WEBHOOK_SECRET
)

# Stripe needs a second, stronger check, and the reason is worth stating.
#
# On 2026-07-28 `dev`'s STRIPE_SECRET_KEY held a `pk_live_` key belonging to the
# PRODUCTION Stripe account. It differed from prd's value, so the hash
# comparison above would have called it "ok (distinct)" — while it pointed
# straight at production. Distinctness is necessary but not sufficient.
#
# Stripe encodes the mode in the key prefix, so we can assert it directly: dev
# must hold test-mode keys, prd must hold live-mode keys. A prefix is a type
# marker, not secret material, so printing it is safe.
#
# STRIPE_WEBHOOK_SECRET is deliberately absent here — `whsec_` carries no mode
# marker, so it can only be checked for distinctness. Its isolation rests on the
# two endpoints living on different accounts.
#
# STRIPE_API_KEY is deliberately absent here too, as of 2026-08-07 (CR18 item 2):
# the prd slot was deleted outright — it held an already-expired rk_live_ key,
# was read by no code in either repo, and was bound to no worker. A mode check
# on a credential that no longer exists in prd would misreport dev's still-live
# sk_test_ value as "unset or unrecognised prefix" — a manufactured failure, not
# a real isolation gap. See is_dead_slot below.
STRIPE_MODED_KEYS=(
  STRIPE_SECRET_KEY
)
LIVE_KEY_RE='^(sk|rk|pk)_live_'
TEST_KEY_RE='^(sk|rk|pk)_test_'

# Supabase has the same "distinct but not isolated" hole, reachable by accident.
#
# `POST /v1/projects/{ref}/api-keys` mints a new `sb_secret_` key carrying
# secret_jwt_template {role: service_role}. Pointing dev at one would make
# SUPABASE_SERVICE_ROLE_KEY differ — so the table above would say "ok
# (distinct)" — while the key still bypasses RLS on the PRODUCTION database.
# It would quiet the detector without isolating anything.
#
# SUPABASE_URL is the tell, because it is derived from the project ref and
# cannot differ within one project. If it is shared, every other Supabase
# credential is non-isolating by construction no matter what its hash says.
# Real isolation requires a second Supabase project (`POST /v1/projects`).
SUPABASE_PROJECT_SCOPED=(
  SUPABASE_SERVICE_ROLE_KEY
  SUPABASE_PROVISIONING_KEY
  SUPABASE_INTEGRITY_MEMERSHIP_KEY
  SUPABASE_ANON_KEY
  SUPABASE_JWT_SECRET
  SUPABASE_DB_PASSWORD
)

command -v doppler >/dev/null 2>&1 || { echo "doppler CLI not installed"; exit 2; }
doppler me >/dev/null 2>&1 || { echo "doppler not authenticated — run 'doppler login'"; exit 2; }

# SHA-1 of the empty string: distinguishes "unset in both" from "same value".
EMPTY_HASH="da39a3ee5e6b4b0d3255bfef95601890afd80709"

# `tr -d '\n'` is load-bearing, not tidiness. `doppler secrets get --plain` emits
# a trailing newline for a slot that EXISTS AND IS EMPTY, but nothing at all for
# a slot that is ABSENT — so without stripping it the two hash differently
# (sha1("\n")=adc83b19… vs sha1("")=da39a3ee…) and only the absent case matched
# EMPTY_HASH. Consequence, measured 2026-08-02: SUPABASE_JWT_SECRET exists-but-
# empty in dev and is set in prd, so it hashed adc83b19… against 17e06a04… and
# scored **"ok (distinct)"** — a false PASS on a slot holding no credential at
# all. That is the dangerous direction of this bug: it manufactures isolation
# rather than an alarm. Stripping the newline reclassifies it as "missing in dev".
digest() {
  doppler secrets get "$1" --project "$PROJECT" --config "$2" --plain 2>/dev/null \
    | tr -d '\n' | shasum | cut -d' ' -f1
}

# Emits only the key-type prefix (e.g. `sk_live_`), never the key body.
key_prefix() {
  doppler secrets get "$1" --project "$PROJECT" --config "$2" --plain 2>/dev/null \
    | tr -d '\n' | grep -oE '^(sk|rk|pk)_(live|test)_' || printf '(none)'
}

printf '%-30s %-10s %-10s %s\n' "SECRET" "$BASE_CONFIG" "$PROD_CONFIG" "VERDICT"
printf '%s\n' "----------------------------------------------------------------------"

# Slots kept in the list for the record but no longer read by any code in
# EITHER repo (landing + observability-toolkit), so "set in prd, empty in dev"
# is not an isolation gap — nothing in dev could use the credential and nothing
# reaches for it. Verified 2026-08-03: 0 non-test references anywhere.
#   SUPABASE_JWT_SECRET — removed from the code 2026-07-31 (workers verify Auth0
#   tokens via Auth0 JWKS; EnvSchema.SUPABASE_JWT_SECRET went .optional()). The
#   prd slot still holds the old value; it authenticates nothing.
#   STRIPE_API_KEY — deleted from prd 2026-08-07 (CR18 item 2): dead, expired
#   (verified 401 api_key_expired), unbound from every worker, and read by no
#   code — `STRIPE_SECRET_KEY` is the name the code actually reads. dev's
#   sk_test_ value is likewise unread; left as-is, out of scope for that fix.
is_dead_slot() { case "$1" in SUPABASE_JWT_SECRET|STRIPE_API_KEY) return 0;; *) return 1;; esac; }

failures=0
unmeasured=0
dead=0
for secret in "${SECRETS[@]}"; do
  base_hash="$(digest "$secret" "$BASE_CONFIG")"
  prod_hash="$(digest "$secret" "$PROD_CONFIG")"

  if is_dead_slot "$secret" && [[ "$base_hash" != "$prod_hash" ]]; then
    # Distinct or absent-in-dev on a slot nothing reads. Not counted — a dead
    # credential cannot be an isolation gap. (If it were SHARED it would still
    # fail below, because a dead-but-shared prod credential in dev is a leak
    # surface even when unused.)
    verdict="dead slot — read by nothing (not counted)"; ((dead++))
  elif [[ "$base_hash" == "$EMPTY_HASH" && "$prod_hash" == "$EMPTY_HASH" ]]; then
    # Set in neither config. This is NOT an isolation failure — there is no
    # credential here to share — but it is not a pass either: the detector is
    # watching a name that nobody sets, so this row measures nothing. Counted
    # separately so it can never be mistaken for either verdict. A credential
    # that MOVES SLOTS is exactly what this hides: SUPABASE_SERVICE_ROLE_KEY
    # read "UNSET in both" while the live service key sat, shared, in
    # SUPABASE_PROVISIONING_KEY, which nothing compared.
    verdict="ABSENT in both (measures nothing)"; ((unmeasured++))
  elif [[ "$base_hash" == "$EMPTY_HASH" ]]; then
    verdict="missing in $BASE_CONFIG"; ((failures++))
  elif [[ "$base_hash" == "$prod_hash" ]]; then
    verdict="SHARED WITH PRODUCTION"; ((failures++))
  else
    verdict="ok (distinct)"
  fi

  printf '%-30s %-10s %-10s %s\n' "$secret" "${base_hash:0:8}" "${prod_hash:0:8}" "$verdict"
done

echo
if [[ "$(digest SUPABASE_URL "$BASE_CONFIG")" == "$(digest SUPABASE_URL "$PROD_CONFIG")" ]]; then
  cat <<EOF
SUPABASE SCOPE: both configs share one SUPABASE_URL, so they are the same
project. ${SUPABASE_PROJECT_SCOPED[*]} therefore cannot
isolate anything, whatever their hashes say above — a per-config
\`sb_secret_\` minted via POST /v1/projects/{ref}/api-keys would read
"ok (distinct)" here while still bypassing RLS on production. Isolation
requires a second project (POST /v1/projects). See BACKLOG.md CR11.
EOF
  echo
fi

printf '%-30s %-14s %-14s %s\n' "STRIPE KEY MODE" "$BASE_CONFIG" "$PROD_CONFIG" "VERDICT"
printf '%s\n' "----------------------------------------------------------------------"

for secret in "${STRIPE_MODED_KEYS[@]}"; do
  base_prefix="$(key_prefix "$secret" "$BASE_CONFIG")"
  prod_prefix="$(key_prefix "$secret" "$PROD_CONFIG")"

  if [[ "$base_prefix" =~ $LIVE_KEY_RE ]]; then
    verdict="$BASE_CONFIG HOLDS A LIVE KEY"; ((failures++))
  elif [[ "$prod_prefix" =~ $TEST_KEY_RE ]]; then
    verdict="$PROD_CONFIG holds a TEST key"; ((failures++))
  elif [[ "$base_prefix" == "(none)" || "$prod_prefix" == "(none)" ]]; then
    verdict="unset or unrecognised prefix"; ((failures++))
  elif [[ "$base_prefix" =~ $TEST_KEY_RE && "$prod_prefix" =~ $LIVE_KEY_RE ]]; then
    verdict="ok (test in $BASE_CONFIG, live in $PROD_CONFIG)"
  else
    verdict="unexpected combination"; ((failures++))
  fi

  printf '%-30s %-14s %-14s %s\n' "$secret" "$base_prefix" "$prod_prefix" "$verdict"
done

echo
if (( dead > 0 )); then
  cat <<EOF
NOTE: $dead row(s) are DEAD slots — read by no code in either repo (verified
2026-08-03) — and are excluded from the failure count when not shared. A
credential nothing reads cannot be an isolation gap. Re-verify the reference
count before trusting this if you resurrect one of these names.

EOF
fi

if (( unmeasured > 0 )); then
  cat <<EOF
NOTE: $unmeasured row(s) are ABSENT in both configs and measure nothing. They are
excluded from the failure count on purpose — "nobody sets this name" is not
evidence of isolation. Before trusting a low count, confirm that no LIVE
credential has moved to a slot this list does not name: that is exactly how
SUPABASE_PROVISIONING_KEY (shared, and a working service_role key against the
production database) went uncompared while SUPABASE_SERVICE_ROLE_KEY scored a
phantom failure in its place.

EOF
fi

# ---------------------------------------------------------------------------
# FULL-CONFIG SWEEP (W09) — classify EVERY name present in both configs.
#
# The list above is a hand-maintained "these must differ" set, and its blind
# spot is structural: a name it does not mention is not measured, so the check
# passes. That is not hypothetical — it is how this file's own history reads.
# PROVISION_WORKER_URL pointed dev at the production sender, KV_NAMESPACE_ID at
# production's AUTH namespace, and INJECT_HMAC_SECRET was *proven* to
# authenticate against the production evaluations webhook. All four passed,
# because none of them were named.
#
# So this pass inverts the polarity. Instead of asking "do the names I listed
# differ?", it asks "of every name present in both configs, which hold the same
# bytes, and is each one legitimately shared?" A name nobody has classified
# FAILS. New names default to visible instead of invisible.
#
# Three buckets, and the distinction between the last two is the whole point:
#
#   SHARED_BY_DESIGN  — third-party keys, other projects, account identifiers
#                       and business constants. No dev/prd notion exists, so
#                       sharing is correct, not tolerated.
#   ACCEPTED          — cross-environment and CANNOT be fixed with a credential.
#                       Scoping is structurally impossible; the only remedy is
#                       separate accounts. Accepted with a reason, printed loud
#                       on every run so acceptance never becomes silence.
#   KNOWN_GAP         — genuinely wrong, fixable, and not yet fixed. Carries a
#                       backlog id. Printed as a defect every run.
#
# Values are never printed by this pass — only names and verdicts.
SWEEP_JSON_DEV="$(doppler secrets download --project "$PROJECT" --config "$BASE_CONFIG" --no-file --format json 2>/dev/null)"
SWEEP_JSON_PRD="$(doppler secrets download --project "$PROJECT" --config "$PROD_CONFIG" --no-file --format json 2>/dev/null)"

if [[ -z "$SWEEP_JSON_DEV" || -z "$SWEEP_JSON_PRD" ]]; then
  echo "SWEEP: skipped — could not download one or both configs."
  echo "       This is a DEGRADED run, not a pass. The list-based checks above"
  echo "       still ran; the full-config classification did not."
  echo
  sweep_unclassified=0
else
  sweep_out="$(SWEEP_DEV="$SWEEP_JSON_DEV" SWEEP_PRD="$SWEEP_JSON_PRD" python3 - <<'PYSWEEP'
import json, os, sys

dev = json.loads(os.environ["SWEEP_DEV"])
prd = json.loads(os.environ["SWEEP_PRD"])

# No dev/prd notion exists for these: one third-party account, one other
# project, or a plain identifier/constant. Sharing is correct.
SHARED_BY_DESIGN = {
    # LLM / AI vendors — one account each, no environments
    "ANTHROPIC_API_KEY","OPENAI_API_KEY","GEMINI_API_KEY","XAI_API_KEY","CODEX_API_KEY",
    "OPEN_ROUTER_API_KEY","HF_TOKEN","CLAUDE_API_KEY_ADMIN","CLAUDE_API_KEY_SUDO",
    "OPENCLAW_ANTHROPIC_TOKEN","OPENCLAW_LEVIATHAN_GATEWAY_TOKEN",
    "LANGTRACE_ACCESS_TOKEN","LANGTRACE_API_KEY",
    # Sentry — project/org identifiers and DSNs; environment is a tag, not a key
    "SENTRY_AUTH_TOKEN","SENTRY_DSN","SENTRY_ORG","SENTRY_ORG_ID","SENTRY_ORG_SLUG",
    "SENTRY_PROJECT","SENTRY_PROJECT_SLUG","SENTRY_DSN_SINGLE_SITE_SCRAPER",
    "SENTRY_DSN_TOOL_VISUALIZER","SENTRY_OBTOOL_DASHBOARD_AUTH_TOKEN",
    "REACT_APP_SENTRY_DSN","VITE_SENTRY_DSN","FILE_SYSTEM_SENTRY_DSN",
    "OBTOOL_SENTRY_API_KEY","DOPPLER_DSN",
    # Marketing / analytics — one ad account, one property
    "ALEDLIE_PIXEL","INTEGRITY_PIXEL","FB_AD_ACCOUNT_ID_ALYSHIA","FB_APP_ID",
    "FB_APP_SECRET","FB_PIXEL_ID","FB_REDIRECT_URI","GA4_REPORTS_ID",
    "GOOGLE_ANALYTICS_API_SECRET","GOOGLE_ANALYTICS_MEASUREMENT_ID",
    "GOOGLE_TAG_MANAGER_CONTAINER_ID","GTM_CONTAINER_ID","META_ACCESS_TOKEN",
    "VITE_MIXPANEL_TOKEN","EVENTBRITE_API_KEY","MEETUP_API_KEY",
    # Google / Gmail OAuth — one Google Cloud project
    "GMAIL_APP_CLIENT_ID","GMAIL_APP_SECRET","GOOGLE_EMAIL_CLIENT_ID",
    "GOOGLE_EMAIL_CLIENT_SECRET","GOOGLE_PROJECT_ID","GOOGLE_PUBLIC_KEY",
    # Business / legal constants — facts about the company, not credentials
    "INTEGRITY_ADDRESS","INTEGRITY_EIN","INTEGRITY_WEFILE_ID","LEORA_LICENSE_NUMBER",
    "INTEGRITY_STUDIO_COMPTROLLER_FILE_NUMBER","INTEGRITY_STUDIO_COMPTROLLER_TAX_ID",
    # Unrelated projects sharing this Doppler project
    "GOOGLE_CALENDAR_PROJECT_ID","GOOGLE_CALENDAR_PROJECT_SECRET",
    "TCAD_RENDER_DEPLOY_HOOK","TCAD_TOKEN_WORKER_SECRET","TCAD_WORKER_URL",
    "TOKEN_WORKER_SECRET","TOKEN_WORKER_URL","RENDER_API_KEY","RENDER_DB",
    "RENDER_DB_PASSWORD","RENDER_DB_USER","RENDER_EXTERNAL_DB_URL",
    "RENDER_INTERNAL_DB_URL","RENDER_JOBS_API_KEY","RENDER_PSQL_COMMAND","REDIS_URL",
    "VITE_ANALYTICSBOT_API_URL","VITE_ANALYTICSBOT_PROJECT_ID",
    "DISCORD_BOT_TOKEN","DISCORD_CLIENT_ID","DISCORD_CLIENT_TOKEN","DISCORD_TOKEN",
    "HUBSPOT_ACCOUNT_ID","HUBSPOT_PAT","AWS_ACCESS_KEY_ID","AWS_SECRET_ACCESS_KEY",
    "GITHUB_TOKEN","PORKBUN_API_KEY","PORKBUN_SECRET_API_KEY",
    # Identifiers, not credentials. One Cloudflare account exists, and the
    # zone id names the integritystudio.ai zone (one zone per hostname),
    # so these CANNOT differ; they grant nothing on their own.
    "CLOUDFLARE_ACCOUNT_ID","CF_ACCOUNT_ID","CLOUDFLARE_ZONE_ID_INTEGRITYSTUDIO_AI",
    "CLOUDFLARE_D2_API_ENDPOINT",
    # Auth0 API identifiers. Each tenant registers its own API under the SAME
    # identifier string by design — only issuer/JWKS differ. Flagging these
    # would manufacture a permanent failure; compare issuers, not audiences.
    "VITE_AUTH0_AUDIENCE","AUTH0_CLIENT_AUDIENCE",
    # Recovery codes for the shared Auth0 *account* (not a tenant credential)
    "AUTH0_RECOVER_CODE","AUTH_RECOVERY_CODE","AUTH0_TEST_ORGANIZATION_ID",
    # Plain configuration constants
    "DOPPLER_PROJECT","API_PORT","OTEL_EXPORTER_OTLP_PROTOCOL",
}

# Cross-environment, and NO credential can fix it — the resource scope has no
# selector finer than the account. Documented in BACKLOG.md W09.
ACCEPTED = {
    "CLOUDFLARE_D1_TOKEN":            "D1 has no per-database selector (all 3 D1 permission groups are account-scoped)",
    "CLOUDFLARE_R2_API_KEY":          "R2 tokens are account-scoped",
    "CLOUDFLARE_R2_SECRET_ACCESS_KEY":"R2 tokens are account-scoped",
    "CLOUDFLARE_WORKER_TOKEN":        "Workers Scripts has no per-script selector",
    "CLOUDFLARE_PAGES_DEPLOY_TOKEN":  "Pages tokens are account-scoped",
    "CLOUDFLARE_PAGES_GITHUB_TOKEN":  "Pages tokens are account-scoped",
    "CLOUDFLARE_OAUTH_TOKEN":         "wrangler OAuth is per-user, not per-environment",
    "CLOUDFLARE_REFRESH_TOKEN":       "wrangler OAuth is per-user, not per-environment",
    "AE_SQL_API_TOKEN":               "Analytics Engine SQL API is account-scoped",
    "SUPABASE_ACCESS_TOKEN":          "sbp_ management token spans every project in the account",
    "AUTH0_PERSONAL_PASSWORD":        "production smoke-test login, deliberately in both configs (owner decision 2026-08-22)",
    "AUTH0_PERSONAL_TEST_EMAIL":      "production smoke-test login, deliberately in both configs (owner decision 2026-08-22)",
}

# Wrong, fixable, not yet fixed. Each MUST carry a backlog id.
# All five W12 entries were resolved 2026-08-09 and removed from this map rather
# than left as satisfied baseline rows: IS_PROD_TOKEN / JWT_SECRET /
# OBTOOL_API_KEY_INVENTORY_AI deleted from dev (all three still in prd, so the
# deletes are reversible), and OTEL_EXPORTER_OTLP_ENDPOINT / OBTOOL_INGEST_ROUTE
# repointed at obtool-ingest-dev.
#
# Deliberately left EMPTY rather than deleted as a concept. An empty map means
# "no known-wrong shared values", which is a different and stronger statement
# than "this check has no notion of a known-wrong value" — and the next real gap
# gets recorded here instead of being argued into SHARED_BY_DESIGN, which would
# convert a printed defect into a silent pass.
KNOWN_GAP = {
}

shared = sorted(set(dev) & set(prd))
identical = [k for k in shared if dev[k] == prd[k]]

rows, unclassified = [], []
for k in identical:
    if k in SHARED_BY_DESIGN:
        continue
    if k in ACCEPTED:
        rows.append(("ACCEPTED", k, ACCEPTED[k]))
    elif k in KNOWN_GAP:
        rows.append(("KNOWN GAP", k, KNOWN_GAP[k]))
    else:
        rows.append(("UNCLASSIFIED", k, "shared and nobody has said why - classify or fix"))
        unclassified.append(k)

print(f"SWEEP: {len(shared)} names in both configs, {len(identical)} byte-identical, "
      f"{len(identical) - len(rows)} shared by design.")
print()
if rows:
    print(f"{'VERDICT':<14} {'NAME':<32} WHY")
    print("-" * 118)
    for verdict, name, why in sorted(rows):
        print(f"{verdict:<14} {name:<32} {why}")
    print()
print(f"__UNCLASSIFIED__={len(unclassified)}")
PYSWEEP
)"
  echo "$sweep_out" | grep -v '^__UNCLASSIFIED__='
  sweep_unclassified="$(printf '%s' "$sweep_out" | sed -n 's/^__UNCLASSIFIED__=//p')"
  sweep_unclassified="${sweep_unclassified:-0}"
  (( failures += sweep_unclassified ))
fi

if (( failures > 0 )); then
  cat <<EOF
FAIL: $failures check(s) failed across ${#SECRETS[@]} credentials,
${#STRIPE_MODED_KEYS[@]} Stripe mode assertions, and the full-config sweep.

'--config $BASE_CONFIG' is not a safety boundary. Anything run against it
reads and writes production state. Do not push these values into the *-dev
workers — that yields a second production-capable worker, not a dev
environment. See BACKLOG.md CR11 for the provisioning runbook.

A "HOLDS A LIVE KEY" verdict is the more dangerous one: that credential is
distinct from prd's — so the hash table above may well call it "ok" — while
still authenticating against the production Stripe account. See CR18.
EOF
  exit 1
fi

echo "PASS: ${#SECRETS[@]} credentials differ between $BASE_CONFIG and $PROD_CONFIG,"
echo "      and ${#STRIPE_MODED_KEYS[@]} Stripe keys are test-mode in $BASE_CONFIG / live-mode in $PROD_CONFIG."
