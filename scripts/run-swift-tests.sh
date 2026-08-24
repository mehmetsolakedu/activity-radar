#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
REPOSITORY_ROOT="${SCRIPT_DIR:h}"
cd "$REPOSITORY_ROOT"

KNOWN_SWIFT_TEST='turnLifecycleAndFinalAnswer'
TEST_LIST=''
TEST_LIST_STATUS=0

if TEST_LIST="$(swift test list 2>&1)"; then
  TEST_LIST_STATUS=0
else
  TEST_LIST_STATUS=$?
fi

report_discovery() {
  local listing="$1"
  local discovered_count
  discovered_count="$(print -r -- "$listing" | grep -c 'ActivityRadarCoreTests\.' || true)"
  print -r -- "Verified Swift test discovery: ${discovered_count} ActivityRadarCoreTests entries."
}

if (( TEST_LIST_STATUS == 0 )) \
  && print -r -- "$TEST_LIST" | grep -F "$KNOWN_SWIFT_TEST" >/dev/null; then
  report_discovery "$TEST_LIST"
  exec swift test
fi

CLT_DEVELOPER_DIR='/Library/Developer/CommandLineTools'
ACTIVE_DEVELOPER_DIR="$(xcode-select -p 2>/dev/null || true)"
CLT_FRAMEWORK_DIR="$CLT_DEVELOPER_DIR/Library/Developer/Frameworks"
CLT_INTEROP_DIR="$CLT_DEVELOPER_DIR/Library/Developer/usr/lib"
CLT_TEST_LIST=''
CLT_TEST_LIST_STATUS=1
TEST_SCRATCH="$(mktemp -d "${TMPDIR:-/tmp}/aiwingman-swift-tests.XXXXXX")"
trap 'rm -rf -- "$TEST_SCRATCH"' EXIT

if [[ "$ACTIVE_DEVELOPER_DIR" == "$CLT_DEVELOPER_DIR" \
  && -d "$CLT_FRAMEWORK_DIR/Testing.framework" \
  && -d "$CLT_INTEROP_DIR" ]]; then
  typeset -a CLT_TEST_ARGUMENTS
  CLT_TEST_ARGUMENTS=(
    --scratch-path "$TEST_SCRATCH"
    --disable-xctest
    --enable-swift-testing
    -Xswiftc -F
    -Xswiftc "$CLT_FRAMEWORK_DIR"
    -Xlinker -rpath
    -Xlinker "$CLT_FRAMEWORK_DIR"
    -Xlinker -rpath
    -Xlinker "$CLT_INTEROP_DIR"
  )
  if CLT_TEST_LIST="$(swift test "${CLT_TEST_ARGUMENTS[@]}" list 2>&1)"; then
    CLT_TEST_LIST_STATUS=0
  else
    CLT_TEST_LIST_STATUS=$?
  fi
  if (( CLT_TEST_LIST_STATUS == 0 )) \
    && print -r -- "$CLT_TEST_LIST" | grep -F "$KNOWN_SWIFT_TEST" >/dev/null; then
    report_discovery "$CLT_TEST_LIST"
    swift test "${CLT_TEST_ARGUMENTS[@]}"
    exit 0
  fi
fi

print -u2 -- 'Default Swift test discovery output:'
print -r -- "$TEST_LIST" >&2
if [[ -n "$CLT_TEST_LIST" ]]; then
  print -u2 -- 'Command Line Tools fallback discovery output:'
  print -r -- "$CLT_TEST_LIST" >&2
fi
print -u2 -- "ERROR: no known Swift test was discovered (${KNOWN_SWIFT_TEST})."
exit 1
