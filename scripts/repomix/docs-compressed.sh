#!/usr/bin/env bash
# Runs repomix --compress with docs-only include rules (bypasses root config).
set -euo pipefail

ROOT="${1:?Usage: $0 <root_dir> <output_file>}"
OUTPUT_FILE="${2:?Usage: $0 <root_dir> <output_file>}"

TMP_CONFIG="$(mktemp "${TMPDIR:-/tmp}/repomix-docs-compressed.XXXXXX.json")"
trap 'rm -f "$TMP_CONFIG"' EXIT

cat > "$TMP_CONFIG" <<'JSON'
{
  "output": {
    "parsableStyle": true,
    "showLineNumbers": true,
    "compress": true
  },
  "include": ["docs/**/*", "CLAUDE.md", "README.md"],
  "ignore": {
    "useDefaultPatterns": true,
    "customPatterns": ["docs/repomix/**", "docs/changelog/**", "docs/archive/**"]
  }
}
JSON

FORCE_COLOR=0 NO_COLOR=1 timeout 60 \
npx repomix "$ROOT" -c "$TMP_CONFIG" -o "$OUTPUT_FILE" >/dev/null 2>&1
