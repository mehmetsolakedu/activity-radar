#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
ROOT="${1:-}"
[[ -n "$ROOT" && -d "$ROOT" ]] || {
  print -u2 "Usage: $0 /path/to/public-tree"
  exit 2
}
ROOT="${ROOT:A}"
shift
(( $# == 0 )) || {
  print -u2 "The public privacy scanner accepts no data allowlist options."
  exit 2
}
command -v rg >/dev/null 2>&1 || {
  print -u2 "Required tool not found: rg (ripgrep)"
  exit 2
}
command -v python3 >/dev/null 2>&1 || {
  print -u2 "Required tool not found: python3"
  exit 2
}
COMPRESSED_ARTIFACT_SCANNER="$SCRIPT_DIR/compressed-artifact-privacy-scan.py"
[[ -f "$COMPRESSED_ARTIFACT_SCANNER" && ! -L "$COMPRESSED_ARTIFACT_SCANNER" ]] || {
  print -u2 "Compressed artifact privacy scanner is missing or unsafe."
  exit 2
}

PRIVATE_HOME_PATTERN='/'"(Users|home)/"'[^/[:cntrl:]]+'
TASK_ID_PATTERN='codex://threads/'"[0-9a-fA-F-]{24,}"
UUID_PATTERN='[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}'
SYNTHETIC_HOME_PATTERN='^/'"(Users|home)/(example|private-person|synthetic-user|test-user)"'$'
SYNTHETIC_TASK_PATTERN='^codex://threads/'"123e4567-e89b-42d3-a456-426614174000"'$'
PATH_OR_ID_PATTERN="(${PRIVATE_HOME_PATTERN}|${TASK_ID_PATTERN})"
SYNTHETIC_ALLOW_PATTERN="(${SYNTHETIC_HOME_PATTERN}|${SYNTHETIC_TASK_PATTERN})"
CREDENTIAL_PATTERN='(gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,}|sk-[A-Za-z0-9_-]{20,}|AKIA[0-9A-Z]{16}|BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY)'
ALLOWED_UUIDS=("123e4567-e89b-42d3-a456-426614174000")

APPROVED_BITMAP="$ROOT/Assets/ActivityRadar-Source.png"
if [[ -e "$APPROVED_BITMAP" ]]; then
  command -v shasum >/dev/null 2>&1 || {
    print -u2 "Required tool not found: shasum"
    exit 2
  }
  [[ -f "$APPROVED_BITMAP" && ! -L "$APPROVED_BITMAP" ]] || {
    print -u2 "Approved public bitmap path is not a regular file."
    exit 5
  }
  [[ "$(shasum -a 256 "$APPROVED_BITMAP" | awk '{print $1}')" == "6beb176ae1b1098d1e65283b7b3b1f9c6c5fb8f776f7c2e7df7967c4b696bf04" ]] || {
    print -u2 "Approved public bitmap hash changed."
    exit 5
  }
fi

cd "$ROOT"

set +e
PATH_AND_ID_MATCHES="$(
  rg -a -o --no-filename --hidden --no-ignore \
    --glob '!.git/**' \
    "$PATH_OR_ID_PATTERN" .
)"
PATH_SCAN_STATUS=$?
set -e
if (( PATH_SCAN_STATUS > 1 )); then
  print -u2 "Public privacy path scanner failed."
  exit 6
fi
UNSAFE_PATH_AND_ID_MATCHES="$(
  print -r -- "$PATH_AND_ID_MATCHES" | grep -Ev "$SYNTHETIC_ALLOW_PATTERN" || true
)"
if [[ -n "$UNSAFE_PATH_AND_ID_MATCHES" ]]; then
  print -u2 "Public privacy scan found a non-synthetic home path or task identifier."
  exit 5
fi

set +e
rg -a -q --hidden --no-ignore \
  --glob '!.git/**' \
  "$CREDENTIAL_PATTERN" .
CREDENTIAL_SCAN_STATUS=$?
set -e
if (( CREDENTIAL_SCAN_STATUS == 0 )); then
  print -u2 "Public privacy scan found a credential pattern."
  exit 5
fi
if (( CREDENTIAL_SCAN_STATUS > 1 )); then
  print -u2 "Public privacy credential scanner failed."
  exit 6
fi

set +e
UUID_MATCHES="$(
  rg -a -o --no-filename --hidden --no-ignore \
    --glob '!.git/**' \
    --glob '!Assets/ActivityRadar-Source.png' \
    "$UUID_PATTERN" .
)"
UUID_SCAN_STATUS=$?
set -e
if (( UUID_SCAN_STATUS > 1 )); then
  print -u2 "Public privacy UUID scanner failed."
  exit 6
fi
UNSAFE_UUID_FOUND=0
while IFS= read -r matched_uuid; do
  [[ -n "$matched_uuid" ]] || continue
  UUID_ALLOWED=0
  for allowed_uuid in "${ALLOWED_UUIDS[@]}"; do
    if [[ "${matched_uuid:l}" == "${allowed_uuid:l}" ]]; then
      UUID_ALLOWED=1
      break
    fi
  done
  if (( UUID_ALLOWED == 0 )); then
    UNSAFE_UUID_FOUND=1
    break
  fi
done <<< "$UUID_MATCHES"
if (( UNSAFE_UUID_FOUND )); then
  print -u2 "Public privacy scan found a non-synthetic raw UUID."
  exit 5
fi

python3 "$COMPRESSED_ARTIFACT_SCANNER" "$ROOT"
