#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
TEMP_ROOT="$(mktemp -d /tmp/activity-radar-release-check.XXXXXX)"

cleanup() {
  if [[ "$TEMP_ROOT" == /tmp/activity-radar-release-check.* && -d "$TEMP_ROOT" ]]; then
    rm -rf -- "$TEMP_ROOT"
  fi
}
trap cleanup EXIT INT TERM

note() {
  print -u2 -- "==> $*"
}

fail() {
  print -u2 -- "ERROR: $*"
  exit 1
}

cd "$PROJECT_DIR"

command -v rg >/dev/null 2>&1 || fail "Required tool not found: rg (ripgrep)"

note "Running deterministic core contracts"
swift run ActivityRadarSelfTest

note "Running continuity-store privacy and retention contract"
STORE_TEST="$TEMP_ROOT/activity-radar-continuity-store-self-test"
swiftc -parse-as-library \
  Sources/ActivityRadar/RadarContinuityStore.swift \
  scripts/continuity-store-self-test.swift \
  -o "$STORE_TEST"
"$STORE_TEST"

note "Checking whether the standard Swift test runner is available"
TEST_LIST="$(swift test list 2>&1 || true)"
if print -r -- "$TEST_LIST" | grep -F 'turnLifecycleAndFinalAnswer' >/dev/null; then
  swift test
elif [[ "${REQUIRE_STANDARD_TESTS:-0}" == "1" ]]; then
  print -r -- "$TEST_LIST" >&2
  fail "Standard tests were required but no known test was discovered"
else
  print -u2 -- "NOTICE: Standard tests were not discovered by this toolchain; CI must run them before a public binary release."
fi

note "Building release products"
swift build -c release --product ActivityRadar
swift build -c release --product ActivityRadarDiagnostics

note "Verifying content-free diagnostics"
DIAGNOSTIC_JSON="$TEMP_ROOT/diagnostics.json"
swift run ActivityRadarDiagnostics > "$DIAGNOSTIC_JSON"
plutil -convert xml1 -o "$TEMP_ROOT/diagnostics.plist" "$DIAGNOSTIC_JSON" \
  || fail "Diagnostics did not emit valid JSON"
for key in \
  includesTaskIdentifiers \
  includesTitlesOrMessages \
  includesFilePaths \
  includesCheckpoints; do
  VALUE="$(plutil -extract "privacy.$key" raw -o - "$DIAGNOSTIC_JSON")"
  [[ "$VALUE" == "false" ]] || fail "Diagnostic privacy flag $key is not false"
done
if rg -q '(/Users/|codex://threads/|"title"[[:space:]]*:|"cwd"[[:space:]]*:|"checkpoint"[[:space:]]*:|"id"[[:space:]]*:)' "$DIAGNOSTIC_JSON"; then
  fail "Content-free diagnostics exposed a forbidden task-level field"
fi

note "Rejecting network-capable application source"
if rg -q '(URLSession|URLRequest|NWConnection|WebSocket|wss?://)' Sources; then
  fail "Network-capable source requires an explicit privacy-contract review"
fi

note "Exporting the explicit public-source manifest"
PUBLIC_SOURCE="$TEMP_ROOT/activity-radar-public"
./scripts/export-public-source.sh "$PUBLIC_SOURCE" >/dev/null
[[ -f "$PUBLIC_SOURCE/LICENSE" ]] || fail "Public source is missing LICENSE"
[[ -f "$PUBLIC_SOURCE/PRIVACY.md" ]] || fail "Public source is missing PRIVACY.md"
[[ ! -e "$PUBLIC_SOURCE/VERIFICATION.md" ]] || fail "Private verification record entered public source"
[[ ! -e "$PUBLIC_SOURCE/design-qa.md" ]] || fail "Private design QA entered public source"
if find "$PUBLIC_SOURCE" -maxdepth 1 -name 'audit-*' -print -quit | grep -q .; then
  fail "Private audit capture entered public source"
fi
swift package --package-path "$PUBLIC_SOURCE" dump-package >/dev/null

note "Building and verifying a local Universal 2 bundle from the public source"
LOCAL_APP="$TEMP_ROOT/Activity Radar.app"
"$PUBLIC_SOURCE/scripts/package-app.sh" \
  --mode local \
  --output-app "$LOCAL_APP"
lipo "$LOCAL_APP/Contents/MacOS/ActivityRadar" -verify_arch arm64 x86_64
[[ "$(plutil -extract CFBundleIdentifier raw -o - "$LOCAL_APP/Contents/Info.plist")" == "io.github.mehmetsolakedu.ActivityRadar" ]] \
  || fail "Packaged bundle identifier changed"
codesign --verify --deep --strict --verbose=2 "$LOCAL_APP"

note "Public-source preparation checks passed"
print "PASS  Activity Radar public-source preparation"
