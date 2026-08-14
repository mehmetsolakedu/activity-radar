#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
MANIFEST="$PROJECT_DIR/PUBLIC_SOURCE_MANIFEST.txt"
TARGET="${1:-}"

command -v rg >/dev/null 2>&1 || {
  print -u2 "Required tool not found: rg (ripgrep)"
  exit 2
}

if [[ -z "$TARGET" ]]; then
  print -u2 "Usage: $0 /absolute/path/to/new-public-source-directory"
  exit 2
fi

TARGET="${TARGET:A}"
if [[ "$TARGET" == "/" || "$TARGET" == "$HOME" || "$TARGET" == "$PROJECT_DIR"* ]]; then
  print -u2 "Refusing unsafe public-source target: $TARGET"
  exit 2
fi
if [[ -e "$TARGET" ]]; then
  print -u2 "Target already exists; refusing to merge or overwrite: $TARGET"
  exit 2
fi

STAGE_ROOT="$(mktemp -d /tmp/activity-radar-public-source.XXXXXX)"
trap 'rm -rf "$STAGE_ROOT"' EXIT
STAGE="$STAGE_ROOT/activity-radar"
mkdir -p "$STAGE"

while IFS= read -r relative_path; do
  [[ -z "$relative_path" || "$relative_path" == \#* ]] && continue
  if [[ "$relative_path" == /* || "$relative_path" == *".."* ]]; then
    print -u2 "Unsafe manifest entry: $relative_path"
    exit 2
  fi
  SOURCE="$PROJECT_DIR/$relative_path"
  if [[ ! -f "$SOURCE" || -L "$SOURCE" ]]; then
    print -u2 "Public manifest entry is not a regular non-symlink file: $relative_path"
    exit 3
  fi
  mkdir -p "$STAGE/${relative_path:h}"
  ditto --noqtn --noextattr --norsrc "$SOURCE" "$STAGE/$relative_path"
done < "$MANIFEST"

if find "$STAGE" -type l | grep -q .; then
  print -u2 "Public source contains a symbolic link; refusing export."
  exit 4
fi

FORBIDDEN_FILES=(
  '.DS_Store'
  '*.app'
  '*.dmg'
  '*.zip'
  '*.xcarchive'
  '*.mobileprovision'
  '*.p12'
  '*.cer'
)
for pattern in "${FORBIDDEN_FILES[@]}"; do
  if find "$STAGE" -name "$pattern" -print -quit | grep -q .; then
    print -u2 "Forbidden generated or credential file matched: $pattern"
    exit 4
  fi
done

if find "$STAGE" -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' \) \
  ! -path "$STAGE/Assets/ActivityRadar-Source.png" -print -quit | grep -q .; then
  print -u2 "Public source contains an unapproved bitmap."
  exit 4
fi

zsh "$STAGE/scripts/public-privacy-scan.sh" "$STAGE"

mkdir -p "${TARGET:h}"
mv "$STAGE" "$TARGET"
print "$TARGET"
