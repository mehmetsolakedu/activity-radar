#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
TEMP_ROOT="$(mktemp -d /tmp/activity-radar-release-check.XXXXXX)"
TOPOLOGY_TEST_DEVICE=""

cleanup() {
  if [[ -n "${TOPOLOGY_TEST_DEVICE:-}" ]]; then
    hdiutil detach "$TOPOLOGY_TEST_DEVICE" >/dev/null 2>&1 || true
  fi
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
command -v sqlite3 >/dev/null 2>&1 || fail "Required tool not found: sqlite3"

GIT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -n "$GIT_ROOT" && "${GIT_ROOT:A}" == "$PROJECT_DIR" ]]; then
  note "Checking tracked public files against the explicit manifest"
  TRACKED_FILES="$TEMP_ROOT/tracked-files.txt"
  MANIFEST_FILES="$TEMP_ROOT/manifest-files.txt"
  git ls-files | sort > "$TRACKED_FILES"
  sed '/^[[:space:]]*$/d; /^[[:space:]]*#/d' PUBLIC_SOURCE_MANIFEST.txt \
    | sort > "$MANIFEST_FILES"
  if ! diff -q "$TRACKED_FILES" "$MANIFEST_FILES" >/dev/null; then
    fail "Git tracked files and PUBLIC_SOURCE_MANIFEST.txt do not match exactly"
  fi
fi

note "Checking fail-closed packaging metadata contract"
zsh -n scripts/package-app.sh
zsh -n scripts/publish-github-release.sh
grep -Fxq 'export GIT_NO_REPLACE_OBJECTS=1' scripts/package-app.sh \
  || fail "Public packager does not disable Git replacement objects"
grep -Fxq 'export GIT_NO_REPLACE_OBJECTS=1' scripts/publish-github-release.sh \
  || fail "GitHub publisher does not disable Git replacement objects"
grep -Fq 'dmg-topology-check.swift bundle "$app"' scripts/publish-github-release.sh \
  || fail "GitHub publisher does not use the exact bundle-topology gate"
grep -Fq '((.bypass_actors | type) == \"array\") and' \
  scripts/publish-github-release.sh \
  || fail "GitHub branch-ruleset gate accepts hidden bypass actors"
grep -Fq '((.bypass_actors | type) == "array") and' \
  scripts/publish-github-release.sh \
  || fail "GitHub publisher does not fail closed when ruleset bypass actors are hidden"
./scripts/publish-github-release.sh --help >/dev/null
NOTARY_NULL_LOG="$TEMP_ROOT/notary-null.json"
NOTARY_EMPTY_LOG="$TEMP_ROOT/notary-empty.json"
NOTARY_WARNING_LOG="$TEMP_ROOT/notary-warning.json"
printf '%s\n' '{"status":"Accepted","issues":null}' > "$NOTARY_NULL_LOG"
printf '%s\n' '{"status":"Accepted","issues":[]}' > "$NOTARY_EMPTY_LOG"
printf '%s\n' '{"status":"Accepted","issues":[{"severity":"warning"}]}' > "$NOTARY_WARNING_LOG"
swift scripts/notary-log-check.swift "$NOTARY_NULL_LOG" \
  || fail "Notarization-log checker rejected an Accepted null issues field"
swift scripts/notary-log-check.swift "$NOTARY_EMPTY_LOG" \
  || fail "Notarization-log checker rejected an Accepted empty issues array"
if swift scripts/notary-log-check.swift "$NOTARY_WARNING_LOG"; then
  fail "Notarization-log checker accepted a nonempty issues array"
fi

note "Checking canonical DMG topology contract"
swiftc -typecheck scripts/dmg-topology-check.swift
TOPOLOGY_ROOT="$TEMP_ROOT/dmg-topology"
TOPOLOGY_SOURCE="$TOPOLOGY_ROOT/source"
TOPOLOGY_MOUNT="$TOPOLOGY_ROOT/mount"
TOPOLOGY_DMG="$TOPOLOGY_ROOT/Activity-Radar-test.dmg"
mkdir -p "$TOPOLOGY_SOURCE/Activity Radar.app" "$TOPOLOGY_MOUNT"
ln -s /Applications "$TOPOLOGY_SOURCE/Applications"
COPYFILE_DISABLE=1 hdiutil create \
  -quiet \
  -volname "Activity Radar" \
  -fs HFS+ \
  -format UDZO \
  -srcfolder "$TOPOLOGY_SOURCE" \
  "$TOPOLOGY_DMG"
TOPOLOGY_IMAGEINFO="$TOPOLOGY_ROOT/imageinfo.plist"
hdiutil imageinfo -plist "$TOPOLOGY_DMG" > "$TOPOLOGY_IMAGEINFO"
swift scripts/dmg-topology-check.swift imageinfo "$TOPOLOGY_IMAGEINFO" "$TOPOLOGY_DMG" \
  || fail "Canonical DMG image-info fixture was rejected"
TOPOLOGY_TAMPERED_FREE="$TOPOLOGY_ROOT/imageinfo-tampered-free.plist"
ditto "$TOPOLOGY_IMAGEINFO" "$TOPOLOGY_TAMPERED_FREE"
plutil -replace 'Partition Information.2.Checksum Value' \
  -string '$DEADBEEF' \
  "$TOPOLOGY_TAMPERED_FREE"
if swift scripts/dmg-topology-check.swift \
  imageinfo "$TOPOLOGY_TAMPERED_FREE" "$TOPOLOGY_DMG" >/dev/null 2>&1; then
  fail "DMG topology checker accepted non-zero raw Apple_Free data"
fi
TOPOLOGY_TAMPERED_EXTRA="$TOPOLOGY_ROOT/imageinfo-tampered-extra.plist"
ditto "$TOPOLOGY_IMAGEINFO" "$TOPOLOGY_TAMPERED_EXTRA"
plutil -insert 'partitions.partitions.8' \
  -xml '<dict><key>partition-synthesized</key><true/></dict>' \
  "$TOPOLOGY_TAMPERED_EXTRA"
if swift scripts/dmg-topology-check.swift \
  imageinfo "$TOPOLOGY_TAMPERED_EXTRA" "$TOPOLOGY_DMG" >/dev/null 2>&1; then
  fail "DMG topology checker accepted an extra partition record"
fi
TOPOLOGY_ATTACH="$TOPOLOGY_ROOT/attach.plist"
hdiutil attach \
  -plist \
  -readonly \
  -nobrowse \
  -mountpoint "$TOPOLOGY_MOUNT" \
  "$TOPOLOGY_DMG" > "$TOPOLOGY_ATTACH"
TOPOLOGY_TEST_DEVICE="$TOPOLOGY_MOUNT"
TOPOLOGY_DEVICE_GATE="$(
  swift scripts/dmg-topology-check.swift attach "$TOPOLOGY_ATTACH" "$TOPOLOGY_MOUNT"
)" || fail "Canonical DMG attach fixture was rejected"
TOPOLOGY_LEAF_DEVICE="${TOPOLOGY_DEVICE_GATE%%$'\t'*}"
TOPOLOGY_WHOLE_DEVICE="${TOPOLOGY_DEVICE_GATE#*$'\t'}"
TOPOLOGY_TEST_DEVICE="$TOPOLOGY_LEAF_DEVICE"
TOPOLOGY_DISKUTIL="$TOPOLOGY_ROOT/diskutil.plist"
diskutil info -plist "$TOPOLOGY_LEAF_DEVICE" > "$TOPOLOGY_DISKUTIL"
swift scripts/dmg-topology-check.swift diskutil \
  "$TOPOLOGY_DISKUTIL" \
  "$TOPOLOGY_MOUNT" \
  "$TOPOLOGY_LEAF_DEVICE" \
  "$TOPOLOGY_WHOLE_DEVICE" \
  || fail "Canonical DMG disk-info fixture was rejected"
hdiutil detach "$TOPOLOGY_LEAF_DEVICE" >/dev/null
TOPOLOGY_TEST_DEVICE=""

note "Checking privacy scanner adversarial fixtures"
PRIVACY_CLEAN_ROOT="$TEMP_ROOT/privacy-clean"
PRIVACY_SAME_LINE_PATH_ROOT="$TEMP_ROOT/privacy-same-line-path"
PRIVACY_SAME_LINE_TASK_ROOT="$TEMP_ROOT/privacy-same-line-task"
PRIVACY_ROOT_PATH_ROOT="$TEMP_ROOT/privacy-root-path"
PRIVACY_SPACED_HOME_ROOT="$TEMP_ROOT/privacy-spaced-home"
PRIVACY_UNICODE_HOME_ROOT="$TEMP_ROOT/privacy-unicode-home"
PRIVACY_EDGE_HOME_ROOT="$TEMP_ROOT/privacy-edge-home"
PRIVACY_BINARY_ROOT="$TEMP_ROOT/privacy-binary"
PRIVACY_CREDENTIAL_ROOT="$TEMP_ROOT/privacy-credential"
PRIVACY_RAW_UUID_ROOT="$TEMP_ROOT/privacy-raw-uuid"
mkdir -p \
  "$PRIVACY_CLEAN_ROOT" \
  "$PRIVACY_SAME_LINE_PATH_ROOT" \
  "$PRIVACY_SAME_LINE_TASK_ROOT" \
  "$PRIVACY_ROOT_PATH_ROOT" \
  "$PRIVACY_SPACED_HOME_ROOT" \
  "$PRIVACY_UNICODE_HOME_ROOT" \
  "$PRIVACY_EDGE_HOME_ROOT" \
  "$PRIVACY_BINARY_ROOT" \
  "$PRIVACY_CREDENTIAL_ROOT" \
  "$PRIVACY_RAW_UUID_ROOT"
SYNTHETIC_HOME='/'"Users/example"
PRIVATE_HOME_FIXTURE='/'"Users/private-fixture"
PRIVATE_SPACED_HOME_FIXTURE='/'"Users/example person"
PRIVATE_UNICODE_HOME_FIXTURE='/'"Users/örnek"
PRIVATE_COMBINING_HOME_FIXTURE='/'"Users/mehmet"$'\u0301'
PRIVATE_EMOJI_HOME_FIXTURE='/'"Users/dev😀"
SYNTHETIC_TASK_LINK='codex://threads/'"123e4567-e89b-42d3-a456-426614174000"
PRIVATE_TASK_UUID='aaaaaaaa-bbbb-'"4ccc-8ddd-eeeeeeeeeeee"
PRIVATE_TASK_LINK="codex://threads/${PRIVATE_TASK_UUID}"
PRIVATE_CREDENTIAL_FIXTURE='ghp_'"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
printf '%s\n' "$SYNTHETIC_HOME/project $SYNTHETIC_TASK_LINK" > "$PRIVACY_CLEAN_ROOT/fixture.txt"
zsh scripts/public-privacy-scan.sh "$PRIVACY_CLEAN_ROOT" \
  || fail "Privacy scanner rejected an explicitly synthetic fixture"
printf '%s\n' "$SYNTHETIC_HOME/project $PRIVATE_HOME_FIXTURE/project" \
  > "$PRIVACY_SAME_LINE_PATH_ROOT/fixture.txt"
if zsh scripts/public-privacy-scan.sh "$PRIVACY_SAME_LINE_PATH_ROOT" >/dev/null 2>&1; then
  fail "Privacy scanner missed a real path beside a synthetic same-line path"
fi
printf '%s\n' "$SYNTHETIC_TASK_LINK $PRIVATE_TASK_LINK" \
  > "$PRIVACY_SAME_LINE_TASK_ROOT/fixture.txt"
if zsh scripts/public-privacy-scan.sh "$PRIVACY_SAME_LINE_TASK_ROOT" >/dev/null 2>&1; then
  fail "Privacy scanner missed a real task ID beside a synthetic same-line task ID"
fi
printf 'path: `%s`,\n' "$PRIVATE_HOME_FIXTURE" > "$PRIVACY_ROOT_PATH_ROOT/fixture.txt"
if zsh scripts/public-privacy-scan.sh "$PRIVACY_ROOT_PATH_ROOT" >/dev/null 2>&1; then
  fail "Privacy scanner missed a home-root path without a trailing slash"
fi
printf '%s/private\n' "$PRIVATE_SPACED_HOME_FIXTURE" > "$PRIVACY_SPACED_HOME_ROOT/fixture.txt"
if zsh scripts/public-privacy-scan.sh "$PRIVACY_SPACED_HOME_ROOT" >/dev/null 2>&1; then
  fail "Privacy scanner missed a home path with a space in the user segment"
fi
printf '%s/private\n' "$PRIVATE_UNICODE_HOME_FIXTURE" > "$PRIVACY_UNICODE_HOME_ROOT/fixture.txt"
if zsh scripts/public-privacy-scan.sh "$PRIVACY_UNICODE_HOME_ROOT" >/dev/null 2>&1; then
  fail "Privacy scanner missed a home path with a Unicode user segment"
fi
for edge_home_fixture in \
  "<${PRIVATE_HOME_FIXTURE}>" \
  "${PRIVATE_HOME_FIXTURE}!" \
  "${PRIVATE_HOME_FIXTURE}?" \
  "${PRIVATE_HOME_FIXTURE}=" \
  "${PRIVATE_HOME_FIXTURE}|next" \
  "${PRIVATE_COMBINING_HOME_FIXTURE}/private" \
  "${PRIVATE_EMOJI_HOME_FIXTURE}/private"; do
  printf '%s\n' "$edge_home_fixture" > "$PRIVACY_EDGE_HOME_ROOT/fixture.txt"
  if zsh scripts/public-privacy-scan.sh "$PRIVACY_EDGE_HOME_ROOT" >/dev/null 2>&1; then
    fail "Privacy scanner missed an arbitrary printable home-path segment or delimiter"
  fi
done
printf 'prefix\0%s\0suffix' "$PRIVATE_TASK_LINK" > "$PRIVACY_BINARY_ROOT/fixture.bin"
if zsh scripts/public-privacy-scan.sh "$PRIVACY_BINARY_ROOT" >/dev/null 2>&1; then
  fail "Privacy scanner missed a task identifier in a NUL-containing file"
fi
printf '%s' "$PRIVATE_CREDENTIAL_FIXTURE" > "$PRIVACY_CREDENTIAL_ROOT/fixture.bin"
if zsh scripts/public-privacy-scan.sh "$PRIVACY_CREDENTIAL_ROOT" >/dev/null 2>&1; then
  fail "Privacy scanner missed a credential pattern"
fi
printf '%s' "$PRIVATE_TASK_UUID" > "$PRIVACY_RAW_UUID_ROOT/fixture.txt"
if zsh scripts/public-privacy-scan.sh "$PRIVACY_RAW_UUID_ROOT" >/dev/null 2>&1; then
  fail "Privacy scanner missed a raw UUID"
fi

note "Checking manifest regular-file boundary"
MANIFEST_FIXTURE_ROOT="$TEMP_ROOT/manifest-fixture"
mkdir -p "$MANIFEST_FIXTURE_ROOT/scripts" "$MANIFEST_FIXTURE_ROOT/docs"
ditto --noqtn --noextattr --norsrc \
  scripts/export-public-source.sh \
  "$MANIFEST_FIXTURE_ROOT/scripts/export-public-source.sh"
printf '%s\n' 'docs' > "$MANIFEST_FIXTURE_ROOT/PUBLIC_SOURCE_MANIFEST.txt"
MANIFEST_FIXTURE_LOG="$TEMP_ROOT/manifest-fixture.log"
if zsh "$MANIFEST_FIXTURE_ROOT/scripts/export-public-source.sh" \
  "$TEMP_ROOT/invalid-manifest-export" >"$MANIFEST_FIXTURE_LOG" 2>&1; then
  fail "Public exporter accepted a directory as a manifest entry"
fi
grep -Fq 'Public manifest entry is not a regular non-symlink file: docs' "$MANIFEST_FIXTURE_LOG" \
  || fail "Public exporter fixture failed for a reason other than the regular-file boundary"
MISSING_TAG_LOG="$TEMP_ROOT/missing-release-tag.log"
if ./scripts/package-app.sh \
  --mode public \
  --identity "Developer ID Application: Synthetic (ABCDEFGHIJ)" \
  --notary-profile synthetic \
  --team-id ABCDEFGHIJ \
  --bundle-id io.github.mehmetsolakedu.ActivityRadar \
  --dist-dir "$TEMP_ROOT/missing-tag-dist" >"$MISSING_TAG_LOG" 2>&1; then
  fail "Public packaging accepted a release without an exact tag"
fi
grep -Fq 'Public mode requires --release-tag' "$MISSING_TAG_LOG" \
  || fail "Public packaging did not fail at the missing-tag gate"

MISMATCHED_TAG_LOG="$TEMP_ROOT/mismatched-release-tag.log"
if ./scripts/package-app.sh \
  --mode public \
  --identity "Developer ID Application: Synthetic (ABCDEFGHIJ)" \
  --notary-profile synthetic \
  --release-tag v9.9.9-beta.1 \
  --team-id ABCDEFGHIJ \
  --bundle-id io.github.mehmetsolakedu.ActivityRadar \
  --dist-dir "$TEMP_ROOT/mismatched-tag-dist" >"$MISMATCHED_TAG_LOG" 2>&1; then
  fail "Public packaging accepted a tag that disagrees with Info.plist"
fi
grep -Fq 'does not match CFBundleShortVersionString' "$MISMATCHED_TAG_LOG" \
  || fail "Public packaging did not fail at the tag/version gate"

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
DIAGNOSTIC_HOME="$TEMP_ROOT/activity-radar-diagnostic-home"
DIAGNOSTIC_STATE="$DIAGNOSTIC_HOME/.codex/state_5.sqlite"
DIAGNOSTIC_ROLLOUT="$DIAGNOSTIC_HOME/PRIVATE-PATH-SENTINEL.jsonl"
DIAGNOSTIC_JSON="$TEMP_ROOT/diagnostics.json"
mkdir -p "$DIAGNOSTIC_HOME/.codex"
printf '%s\n' \
  '{"timestamp":"2026-01-01T00:00:00Z","type":"event_msg","payload":{"type":"agent_message","phase":"final_answer","message":"PRIVATE-CHECKPOINT-SENTINEL"}}' \
  '{"timestamp":"2026-01-01T00:00:01Z","type":"response_item","payload":{"type":"function_call","name":"request_user_input","call_id":"PRIVATE-CALL-ID-SENTINEL"}}' \
  > "$DIAGNOSTIC_ROLLOUT"
sqlite3 -batch -bail "$DIAGNOSTIC_STATE" <<SQL
CREATE TABLE threads (
  id TEXT, title TEXT, preview TEXT, cwd TEXT, rollout_path TEXT,
  created_at INTEGER, updated_at INTEGER,
  created_at_ms INTEGER, updated_at_ms INTEGER,
  archived INTEGER, thread_source TEXT, recency_at_ms INTEGER
);
CREATE TABLE thread_spawn_edges (child_thread_id TEXT);
INSERT INTO threads (
  id, title, preview, cwd, rollout_path,
  created_at, updated_at, created_at_ms, updated_at_ms,
  archived, thread_source, recency_at_ms
) VALUES (
  'PRIVATE-RAW-ID-SENTINEL',
  'PRIVATE-TITLE-SENTINEL',
  'PRIVATE-PREVIEW-SENTINEL',
  '$DIAGNOSTIC_HOME/PRIVATE-WORKSPACE-SENTINEL',
  '$DIAGNOSTIC_ROLLOUT',
  1767225600, 1767225600, 1767225600000, 1767225600000,
  0, 'user', 1767225600000
);
SQL
DIAGNOSTIC_FIXTURE_COUNT="$(
  sqlite3 -batch -bail -noheader "$DIAGNOSTIC_STATE" \
    "SELECT COUNT(*) FROM threads WHERE id = 'PRIVATE-RAW-ID-SENTINEL' AND title = 'PRIVATE-TITLE-SENTINEL' AND cwd = '$DIAGNOSTIC_HOME/PRIVATE-WORKSPACE-SENTINEL';"
)"
[[ "$DIAGNOSTIC_FIXTURE_COUNT" == "1" ]] \
  || fail "Synthetic diagnostic database fixture was not created exactly"
rg -Fq 'PRIVATE-CHECKPOINT-SENTINEL' "$DIAGNOSTIC_ROLLOUT" \
  || fail "Synthetic diagnostic checkpoint fixture is missing"
rg -Fq 'PRIVATE-CALL-ID-SENTINEL' "$DIAGNOSTIC_ROLLOUT" \
  || fail "Synthetic diagnostic input fixture is missing"
CFFIXED_USER_HOME="$DIAGNOSTIC_HOME" swift run ActivityRadarDiagnostics > "$DIAGNOSTIC_JSON"
plutil -convert xml1 -o "$TEMP_ROOT/diagnostics.plist" "$DIAGNOSTIC_JSON" \
  || fail "Diagnostics did not emit valid JSON"
DIAGNOSTIC_ITEM_COUNT="$(plutil -extract itemCount raw -o - "$DIAGNOSTIC_JSON")"
[[ "$DIAGNOSTIC_ITEM_COUNT" == "1" ]] \
  || fail "Diagnostics did not read the isolated synthetic state fixture"
DIAGNOSTIC_INPUT_COUNT="$(
  plutil -extract attentionReasonCounts.explicitInput raw -o - "$DIAGNOSTIC_JSON"
)"
[[ "$DIAGNOSTIC_INPUT_COUNT" == "1" ]] \
  || fail "Diagnostics did not reduce the synthetic pending-input event"
DIAGNOSTIC_COMPLETE_COUNT="$(plutil -extract completeHistoryCount raw -o - "$DIAGNOSTIC_JSON")"
DIAGNOSTIC_PARTIAL_COUNT="$(plutil -extract partialHistoryCount raw -o - "$DIAGNOSTIC_JSON")"
[[ "$DIAGNOSTIC_COMPLETE_COUNT" == "1" && "$DIAGNOSTIC_PARTIAL_COUNT" == "0" ]] \
  || fail "Diagnostics did not consume the complete synthetic rollout"
for key in \
  includesTaskIdentifiers \
  includesTitlesOrMessages \
  includesFilePaths \
  includesCheckpoints; do
  VALUE="$(plutil -extract "privacy.$key" raw -expect bool -o - "$DIAGNOSTIC_JSON")"
  [[ "$VALUE" == "false" ]] || fail "Diagnostic privacy flag $key is not false"
done
PRIVATE_HOME_PREFIX='/'"Users/"
TASK_LINK_PREFIX='codex://threads/'
if rg -q "(${PRIVATE_HOME_PREFIX}|${TASK_LINK_PREFIX}|\"title\"[[:space:]]*:|\"cwd\"[[:space:]]*:|\"checkpoint\"[[:space:]]*:|\"id\"[[:space:]]*:)" "$DIAGNOSTIC_JSON"; then
  fail "Content-free diagnostics exposed a forbidden task-level field"
else
  DIAGNOSTIC_FIELD_SCAN_STATUS=$?
  [[ "$DIAGNOSTIC_FIELD_SCAN_STATUS" == "1" ]] \
    || fail "Content-free diagnostic field scan did not complete"
fi
if rg -q 'PRIVATE-' "$DIAGNOSTIC_JSON"; then
  fail "Content-free diagnostics exposed synthetic private content"
else
  DIAGNOSTIC_SENTINEL_SCAN_STATUS=$?
  [[ "$DIAGNOSTIC_SENTINEL_SCAN_STATUS" == "1" ]] \
    || fail "Content-free diagnostic sentinel scan did not complete"
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

note "Rejecting newline-confusable bundle payloads"
swift "$PUBLIC_SOURCE/scripts/dmg-topology-check.swift" bundle "$LOCAL_APP" \
  || fail "Canonical local bundle was rejected by the exact topology gate"
TAMPERED_APP="$TEMP_ROOT/Tampered Activity Radar.app"
ditto --norsrc --noextattr --noacl "$LOCAL_APP" "$TAMPERED_APP"
touch "$TAMPERED_APP/Contents/Resources/ActivityRadar.icns"$'\n'
codesign --force --deep --sign - "$TAMPERED_APP" >/dev/null
codesign --verify --deep --strict --verbose=2 "$TAMPERED_APP"
if swift "$PUBLIC_SOURCE/scripts/dmg-topology-check.swift" bundle "$TAMPERED_APP" \
  >/dev/null 2>&1; then
  fail "Bundle topology gate accepted a newline-confusable signed payload"
fi

note "Verifying the canonical metadata-free ZIP contract"
CANONICAL_ZIP_A="$TEMP_ROOT/canonical-a.zip"
CANONICAL_ZIP_B="$TEMP_ROOT/canonical-b.zip"
(
  cd "$TEMP_ROOT"
  /usr/bin/zip -X -q -r "$CANONICAL_ZIP_A" "Activity Radar.app"
  /usr/bin/zip -X -q -r "$CANONICAL_ZIP_B" "Activity Radar.app"
)
cmp -s "$CANONICAL_ZIP_A" "$CANONICAL_ZIP_B" \
  || fail "Canonical ZIP creation was not byte-for-byte stable"
if unzip -Z1 "$CANONICAL_ZIP_A" | grep -q '^__MACOSX/'; then
  fail "Canonical ZIP unexpectedly contains AppleDouble metadata"
fi
ZIP_ENTRY_COUNT="$(unzip -Z1 "$CANONICAL_ZIP_A" | wc -l | tr -d '[:space:]')"
ZIP_ZERO_EXTRA_COUNT="$(unzip -Z -v "$CANONICAL_ZIP_A" | grep -Ec 'length of extra field:[[:space:]]+0 bytes$' || true)"
ZIP_ZERO_COMMENT_COUNT="$(unzip -Z -v "$CANONICAL_ZIP_A" | grep -Ec 'length of file comment:[[:space:]]+0 characters$' || true)"
[[ "$ZIP_ENTRY_COUNT" == "$ZIP_ZERO_EXTRA_COUNT" && "$ZIP_ENTRY_COUNT" == "$ZIP_ZERO_COMMENT_COUNT" ]] \
  || fail "Canonical ZIP contains per-entry extra fields or comments"

note "Public-source preparation checks passed"
print "PASS  Activity Radar public-source preparation"
