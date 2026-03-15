#!/usr/bin/env bash
set -euo pipefail

# Generate top-20 most-changed files with recent commit context.
# Usage: generate-gitlog-top20.sh [COMMITS] [OUT_FILE]

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
COMMITS="${1:-200}"
OUT="${2:-"$REPO_ROOT/docs/repomix/gitlog-top20.txt"}"
mkdir -p "$(dirname "$OUT")"

TMP_OUT="$(mktemp)"
trap 'rm -f "$TMP_OUT"' EXIT

# Top 20 files by commit frequency
top_files=$(
  git -C "$REPO_ROOT" log -n "$COMMITS" --name-only --pretty=format: \
    | grep -v '^$' \
    | grep -v '^docs/' \
    | sort \
    | uniq -c \
    | sort -rn \
    | head -20
)

{
  echo "# Top 20 most-changed files (last $COMMITS commits)"
  echo "# commits  file"
  echo "$top_files"
  echo
  echo "# Recent commits touching these files"
  echo

  # Extract just the file paths
  files=$(echo "$top_files" | awk '{print $2}')

  for f in $files; do
    echo "## $f"
    git -C "$REPO_ROOT" log -n 5 --date=short \
      --pretty='format:  %h %ad %s' \
      -- "$f"
    echo
    echo
  done
} > "$TMP_OUT"

cp "$TMP_OUT" "$OUT"
echo "Wrote: $OUT"
