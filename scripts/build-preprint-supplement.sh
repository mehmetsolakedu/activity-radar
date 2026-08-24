#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
OUTPUT_PATH="${1:-$PROJECT_DIR/output/supplement/aiwingman-research-supplement-v1.zip}"
TEMP_ROOT="$(mktemp -d /tmp/aiwingman-preprint-supplement.XXXXXX)"
ARCHIVE_ROOT="$TEMP_ROOT/AiWingman-research-supplement-v1"
TEMP_ZIP="$TEMP_ROOT/aiwingman-research-supplement-v1.zip"

cleanup() {
  if [[ "$TEMP_ROOT" == /tmp/aiwingman-preprint-supplement.* && -d "$TEMP_ROOT" ]]; then
    rm -rf -- "$TEMP_ROOT"
  fi
}
trap cleanup EXIT INT TERM

command -v zip >/dev/null 2>&1 || {
  print -u2 -- "Required tool not found: zip"
  exit 1
}

if [[ "$OUTPUT_PATH" != /* ]]; then
  OUTPUT_PATH="$PROJECT_DIR/$OUTPUT_PATH"
fi

FILES=(
  paper/SUPPLEMENT_README.md
  Research/protocol/FREEZE_MANIFEST_V1.json
  Research/protocol/SPECIFICATION_V1.md
  Research/fixtures/continuity-policy-corpus-v1.json
  Research/results/POST_FREEZE_RULE_OBSERVABILITY_V1.md
  Research/results/RESULTS_ERRATA_V1.md
  Research/results/RESULTS_MANIFEST_V1.json
  Research/results/continuity-benchmark-v1-arm64.json
  Research/results/cross-process-determinism-v1-arm64.json
  Research/results/post-freeze-rule-observability-v1.json
)

mkdir -p "$ARCHIVE_ROOT"
for relative_path in "${FILES[@]}"; do
  source_path="$PROJECT_DIR/$relative_path"
  [[ -f "$source_path" && ! -L "$source_path" ]] || {
    print -u2 -- "Supplement source is not a regular non-symlink file: $relative_path"
    exit 1
  }
  if [[ "$relative_path" == paper/SUPPLEMENT_README.md ]]; then
    destination_path="$ARCHIVE_ROOT/README.md"
  else
    destination_path="$ARCHIVE_ROOT/$relative_path"
  fi
  mkdir -p "${destination_path:h}"
  cp "$source_path" "$destination_path"
done

find "$ARCHIVE_ROOT" -exec touch -t 202608240000 {} +
(
  cd "$TEMP_ROOT"
  COPYFILE_DISABLE=1 zip -X -q -r "$TEMP_ZIP" "${ARCHIVE_ROOT:t}"
)

mkdir -p "${OUTPUT_PATH:h}"
mv -f "$TEMP_ZIP" "$OUTPUT_PATH"
print -r -- "$OUTPUT_PATH"
