#!/usr/bin/env bash
# Runs repomix with workers-only include rules using repomix-workers.json config.
# Lossless (no --compress): worker logic lives in function bodies, which compression drops.
# Tests are excluded here — they live in tests-compressed.xml.
set -euo pipefail

ROOT="${1:?Usage: $0 <root_dir> <output_file>}"
OUTPUT_FILE="${2:?Usage: $0 <root_dir> <output_file>}"
CONFIG="$ROOT/scripts/repomix/repomix-workers.json"

FORCE_COLOR=0 NO_COLOR=1 timeout 120 \
npx repomix "$ROOT" -c "$CONFIG" -o "$OUTPUT_FILE" >/dev/null 2>&1
