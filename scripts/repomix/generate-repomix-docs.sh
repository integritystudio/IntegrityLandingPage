#!/usr/bin/env bash
# Runs repomix with docs-only include rules and writes a docs-focused XML bundle.
set -euo pipefail

ROOT="${1:?Usage: $0 <root_dir> <output_file>}"
OUTPUT_FILE="${2:?Usage: $0 <root_dir> <output_file>}"

FORCE_COLOR=0 NO_COLOR=1 timeout 60 \
npx repomix "$ROOT" \
  --include "docs/**/*,*.md,CLAUDE.md" \
  --ignore "docs/repomix/**" \
  -o "$OUTPUT_FILE" >/dev/null 2>&1
