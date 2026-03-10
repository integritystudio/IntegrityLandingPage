#!/bin/bash
#
# Find duplicate Dart/Flutter code constructs using text similarity.
# Self-contained — no Python or tree-sitter dependency.
# Compatible with macOS awk.
#
# Usage:
#   ./scripts/repomix/find_duplication.sh [project_folder] [construct] [min_similarity] [min_lines]
#
# Constructs: widget | class | function | method (default: widget)
# min_similarity: 0.0-1.0 Jaccard threshold (default: 0.7)
# min_lines: minimum lines for a construct to be considered (default: 5)
#
# Examples:
#   ./scripts/repomix/find_duplication.sh .
#   ./scripts/repomix/find_duplication.sh . widget 0.8
#   ./scripts/repomix/find_duplication.sh . function 0.7 10
#   ./scripts/repomix/find_duplication.sh lib class 0.75 8

set -euo pipefail

PROJECT_FOLDER="${1:-.}"
CONSTRUCT="${2:-widget}"
MIN_SIMILARITY="${3:-0.7}"
MIN_LINES="${4:-5}"

if [ ! -d "$PROJECT_FOLDER" ]; then
  echo "Error: directory does not exist: $PROJECT_FOLDER"
  exit 1
fi

# Validate construct type
case "$CONSTRUCT" in
  widget|class|function|method) ;;
  *)
    echo "Error: unknown construct '$CONSTRUCT'. Use: widget | class | function | method"
    exit 1
    ;;
esac

# Resolve to absolute path
PROJECT_FOLDER="$(cd "$PROJECT_FOLDER" && pwd)"

TMPDIR_WORK="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_WORK"' EXIT

CONSTRUCTS_FILE="$TMPDIR_WORK/constructs.tsv"
BODIES_DIR="$TMPDIR_WORK/bodies"
mkdir -p "$BODIES_DIR"

echo "Scanning $PROJECT_FOLDER for Dart $CONSTRUCT constructs (min ${MIN_LINES} lines, similarity >= ${MIN_SIMILARITY})..."
echo ""

# Extract constructs from all .dart files using a single awk invocation per file.
# macOS awk doesn't support dynamic regex or capture groups, so we use
# construct_type to branch to hardcoded patterns inside awk.
extract_constructs() {
  local file="$1"
  local rel_path="${file#"$PROJECT_FOLDER"/}"

  awk -v construct_type="$CONSTRUCT" -v min_lines="$MIN_LINES" \
      -v rel="$rel_path" -v bodiesdir="$BODIES_DIR" '
  BEGIN { idx = 0; in_block = 0; depth = 0; block = ""; start = 0; name = "" }

  function is_match(line) {
    if (construct_type == "widget")
      return match(line, /^[[:space:]]*class[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[[:space:]]+extends[[:space:]]+(Stateless|Stateful)Widget/)
    if (construct_type == "class")
      return match(line, /^[[:space:]]*class[[:space:]]+[A-Za-z_]/)
    if (construct_type == "function")
      return match(line, /^[A-Za-z_].*[[:space:]][A-Za-z_][A-Za-z0-9_]*[[:space:]]*\(/)
    if (construct_type == "method")
      return match(line, /^[[:space:]]+[A-Za-z_@].*[[:space:]][A-Za-z_][A-Za-z0-9_]*[[:space:]]*\(/)
    return 0
  }

  {
    if (!in_block && is_match($0)) {
      in_block = 1
      depth = 0
      block = ""
      start = NR
      # Extract name
      name = $0
      if (index(name, "class") > 0) {
        sub(/.*class[[:space:]]+/, "", name)
        sub(/[^A-Za-z0-9_].*/, "", name)
      } else {
        # Function/method: grab identifier before "("
        sub(/[[:space:]]*\(.*/, "", name)
        # Take last word (the function name)
        n_words = split(name, _w, /[[:space:]]+/)
        name = _w[n_words]
      }
    }
    if (in_block) {
      block = block "\n" $0
      n_chars = split($0, chars, "")
      for (i = 1; i <= n_chars; i++) {
        if (chars[i] == "{") depth++
        if (chars[i] == "}") depth--
      }
      if (depth <= 0 && index(block, "{") > 0) {
        lines = NR - start + 1
        if (lines >= min_lines) {
          idx++
          # Use a flat filename with underscores
          outname = rel
          gsub(/\//, "__", outname)
          outfile = bodiesdir "/" outname "___" idx ".txt"
          print block > outfile
          close(outfile)
          printf "%s\t%s\t%d\t%d\t%s\n", rel, name, start, NR, outfile
        }
        in_block = 0
        block = ""
      }
    }
  }
  ' "$file"
}

# Find all .dart files, excluding generated/build dirs
while IFS= read -r -d '' f; do
  extract_constructs "$f"
done < <(find "$PROJECT_FOLDER" -name '*.dart' \
  -not -path '*/.dart_tool/*' \
  -not -path '*/build/*' \
  -not -path '*/.pub-cache/*' \
  -not -path '*/.gen/*' \
  -not -name '*.g.dart' \
  -not -name '*.freezed.dart' \
  -print0 | sort -z) >> "$CONSTRUCTS_FILE"

TOTAL=$(wc -l < "$CONSTRUCTS_FILE" | tr -d ' ')
if [ "$TOTAL" -eq 0 ]; then
  echo "No $CONSTRUCT constructs found with >= $MIN_LINES lines."
  exit 0
fi

echo "Found $TOTAL $CONSTRUCT constructs. Comparing pairs..."
echo ""

# Compare pairs using Jaccard similarity on word tokens
awk -F'\t' -v min_sim="$MIN_SIMILARITY" '
{
  n++
  file[n] = $1
  name[n] = $2
  startl[n] = $3
  endl[n] = $4
  bodyfile[n] = $5

  body = ""
  while ((getline line < bodyfile[n]) > 0) {
    body = body " " line
  }
  close(bodyfile[n])

  # Tokenise: split on non-alphanumeric
  gsub(/[^a-zA-Z0-9_]+/, " ", body)
  num = split(body, words, " ")
  delete tokens
  for (i = 1; i <= num; i++) {
    w = tolower(words[i])
    if (length(w) > 1) tokens[w] = 1
  }
  tset = ""
  for (w in tokens) tset = tset " " w
  tokenset[n] = tset
}
END {
  found = 0
  for (i = 1; i <= n; i++) {
    split(tokenset[i], setA, " ")
    delete mapA
    sizeA = 0
    for (k in setA) {
      if (setA[k] != "") { mapA[setA[k]] = 1; sizeA++ }
    }
    for (j = i + 1; j <= n; j++) {
      if (file[i] == file[j] && name[i] == name[j]) continue

      split(tokenset[j], setB, " ")
      sizeB = 0
      intersection = 0
      for (k in setB) {
        if (setB[k] != "") {
          sizeB++
          if (setB[k] in mapA) intersection++
        }
      }
      union_size = sizeA + sizeB - intersection
      if (union_size == 0) continue
      sim = intersection / union_size

      if (sim >= min_sim) {
        found++
        printf "%.0f%% similar:\n", sim * 100
        printf "  A: %s :: %s (lines %d-%d)\n", file[i], name[i], startl[i], endl[i]
        printf "  B: %s :: %s (lines %d-%d)\n", file[j], name[j], startl[j], endl[j]
        printf "\n"
      }
    }
  }
  if (found == 0) {
    printf "No duplicate pairs found above %.0f%% similarity.\n", min_sim * 100
  } else {
    printf "Found %d similar pairs.\n", found
  }
}
' "$CONSTRUCTS_FILE"
