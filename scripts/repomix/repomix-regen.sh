#!/usr/bin/env bash
# Wrapper: generates token tree + compressed repomix output
set -euo pipefail

# Resolve repo root (two levels up from scripts/repomix/)
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# repomix compression variant names
TREE_FILE="token-tree"
COMPRESSED_FILE="repo-compressed"
LOSSLESS_FILE="repomix"
DOCS_ONLY_FILE="repomix-docs"
GIT_RANKED_FILE="repomix-git-ranked"

# absolute filepaths - output
OUTPUT_PATH="docs/repomix"
OUT_DIR="$ROOT/$OUTPUT_PATH"
TOKEN_TREE_FILE="$OUT_DIR/$TREE_FILE.txt"
COMPRESSED_REPO_FILE="$OUT_DIR/$COMPRESSED_FILE.xml"
LOSSLESS_REPO_FILE="$OUT_DIR/$LOSSLESS_FILE.xml"
DOCS_ONLY_REPO_FILE="$OUT_DIR/$DOCS_ONLY_FILE.xml"
GIT_RANKED_REPO_FILE="$OUT_DIR/$GIT_RANKED_FILE.xml"
GITLOG_TOP_FILE="$OUT_DIR/gitlog-top20.txt"

#relative filepaths - input
TREE_FILE_NAME="$OUTPUT_PATH/$TREE_FILE.txt"
COMPRESSED_FILE_NAME="$OUTPUT_PATH/$COMPRESSED_FILE.xml"
LOSSLESS_FILE_NAME="$OUTPUT_PATH/$LOSSLESS_FILE.xml"
DOCS_ONLY_FILE_NAME="$OUTPUT_PATH/$DOCS_ONLY_FILE.xml"
GIT_RANKED_FILE_NAME="$OUTPUT_PATH/$GIT_RANKED_FILE.xml"
GITLOG_TOP_FILE_NAME="$OUTPUT_PATH/gitlog-top20.txt"
SCRIPT_DIR="$ROOT/scripts/repomix"

# input script paths
TOKEN_TREE_SCRIPT="$SCRIPT_DIR/token-tree.sh"
COMPRESS_SCRIPT="$SCRIPT_DIR/repo-compressed.sh"
LOSSLESS_SCRIPT="$SCRIPT_DIR/repomix.sh"
DOCS_ONLY_SCRIPT="$SCRIPT_DIR/generate-repomix-docs.sh"
GIT_RANKED_SCRIPT="$SCRIPT_DIR/generate-repomix-git-ranked.sh"
GITLOG_TOP_SCRIPT="$SCRIPT_DIR/generate-sidequest-gitlog.sh"
GIT_RANKED_INCLUDE_LOGS_COUNT="${REPOMIX_GIT_RANKED_INCLUDE_LOGS_COUNT:-200}"

echo "File set up..."
# make output dir if not exists
mkdir -p "$OUT_DIR"

# delete only the artifacts this wrapper regenerates
rm -f \
  "$TOKEN_TREE_FILE" \
  "$COMPRESSED_REPO_FILE" \
  "$LOSSLESS_REPO_FILE" \
  "$DOCS_ONLY_REPO_FILE" \
  "$GIT_RANKED_REPO_FILE" \
  "$GITLOG_TOP_FILE"

# project-level logging
PROJECT_DIR="$(basename "$ROOT")"
echo "Creating compressed files for repository $PROJECT_DIR"

echo "Generating token count tree for $PROJECT_DIR at $TREE_FILE_NAME"
bash "$TOKEN_TREE_SCRIPT" "$ROOT" "$TOKEN_TREE_FILE"
echo "Success!"
echo

echo "Generating compressed repomix file for $PROJECT_DIR at $COMPRESSED_FILE_NAME"
bash "$COMPRESS_SCRIPT" "$ROOT" "$COMPRESSED_REPO_FILE"
echo "Success!"
echo

echo "Generating repomix file for $PROJECT_DIR at $LOSSLESS_FILE_NAME"
bash "$LOSSLESS_SCRIPT" "$ROOT" "$LOSSLESS_REPO_FILE"
echo "Success!"
echo

echo "Generating docs-only repomix file for $PROJECT_DIR at $DOCS_ONLY_FILE_NAME"
bash "$DOCS_ONLY_SCRIPT" "$ROOT" "$DOCS_ONLY_REPO_FILE"
echo "Success!"
echo

echo "Generating git-ranked repomix file for $PROJECT_DIR at $GIT_RANKED_FILE_NAME"
bash "$GIT_RANKED_SCRIPT" "$ROOT" "$GIT_RANKED_REPO_FILE" "$GIT_RANKED_INCLUDE_LOGS_COUNT"
echo "Success!"
echo

echo "Generating top-file git history at $GITLOG_TOP_FILE_NAME"
bash "$GITLOG_TOP_SCRIPT" 200 "$GITLOG_TOP_FILE"
echo "Success!"
echo

echo "Artifacts:"

print_artifact() {
  local file_path="$1"
  local display_name="$2"

  if [[ -f "$file_path" ]]; then
    chars=$(wc -c < "$file_path" | tr -d ' ')
    tokens=$((chars / 4))
    echo " - $display_name (~$tokens tokens, $chars chars)"
  else
    echo " - $display_name (missing)"
  fi
}

print_artifact "$TOKEN_TREE_FILE" "$TREE_FILE_NAME"
print_artifact "$COMPRESSED_REPO_FILE" "$COMPRESSED_FILE_NAME"
print_artifact "$LOSSLESS_REPO_FILE" "$LOSSLESS_FILE_NAME"
print_artifact "$DOCS_ONLY_REPO_FILE" "$DOCS_ONLY_FILE_NAME"
print_artifact "$GIT_RANKED_REPO_FILE" "$GIT_RANKED_FILE_NAME"
print_artifact "$GITLOG_TOP_FILE" "$GITLOG_TOP_FILE_NAME"
