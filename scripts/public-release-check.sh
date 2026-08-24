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
command -v python3 >/dev/null 2>&1 || fail "Required tool not found: python3"

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

note "Checking installable release-notes and clean-machine acceptance contracts"
swiftc -typecheck scripts/release-notes-check.swift
swiftc -typecheck scripts/clean-machine-acceptance-check.swift
plutil -convert xml1 -o /dev/null Packaging/CLEAN_MACHINE_ACCEPTANCE.schema.json \
  || fail "Clean-machine acceptance schema is not valid JSON"
plutil -convert xml1 -o /dev/null Packaging/CLEAN_MACHINE_ACCEPTANCE.template.json \
  || fail "Clean-machine acceptance template is not valid JSON"
[[ "$(plutil -extract 'properties.records.minItems' raw -o - Packaging/CLEAN_MACHINE_ACCEPTANCE.schema.json)" == "2" \
  && "$(plutil -extract 'properties.records.maxItems' raw -o - Packaging/CLEAN_MACHINE_ACCEPTANCE.schema.json)" == "2" ]] \
  || fail "Clean-machine acceptance schema does not require exactly two records"

if ! python3 - Packaging/CLEAN_MACHINE_ACCEPTANCE.schema.json <<'PY'; then
import json
import sys

schema_path = sys.argv[1]
with open(schema_path, encoding="utf-8") as schema_file:
    schema = json.load(schema_file)

base_record = schema.get("$defs", {}).get("baseRecord", {})
required = base_record.get("required")
if not isinstance(required, list) or not all(isinstance(item, str) for item in required):
    raise SystemExit("baseRecord.required must be an array of strings")

expected_required = (
    "aboutReleaseIdentityVerified",
    "applicationCopiedToApplications",
    "applicationReplacementSucceeded",
    "architecture",
    "browserDownloadQuarantineObserved",
    "checksumVerified",
    "dmgEjected",
    "dmgMountedReadOnly",
    "downloadedFromGitHubRelease",
    "gatekeeperLaunchSucceeded",
    "interfaceLanguageSwitchPersisted",
    "macOSBuild",
    "macOSVersion",
    "machineDidNotBuildRelease",
    "menuBarItemVisible",
    "supportInformationContentFree",
    "syntheticCodexDeepLinkSucceeded",
    "testedAt",
    "uninstallSucceeded",
    "wingmanCLIUnavailableFallbackVerified",
    "wingmanConsentPreviewVerified",
    "wingmanRemoteReviewSucceeded",
)
if len(required) != len(expected_required) or set(required) != set(expected_required):
    missing = sorted(set(expected_required) - set(required))
    unexpected = sorted(set(required) - set(expected_required))
    raise SystemExit(
        f"baseRecord.required mismatch; missing={missing}, unexpected={unexpected}"
    )

boolean_keys = (
    "aboutReleaseIdentityVerified",
    "applicationCopiedToApplications",
    "applicationReplacementSucceeded",
    "browserDownloadQuarantineObserved",
    "checksumVerified",
    "dmgEjected",
    "dmgMountedReadOnly",
    "downloadedFromGitHubRelease",
    "gatekeeperLaunchSucceeded",
    "interfaceLanguageSwitchPersisted",
    "machineDidNotBuildRelease",
    "menuBarItemVisible",
    "supportInformationContentFree",
    "syntheticCodexDeepLinkSucceeded",
    "uninstallSucceeded",
    "wingmanCLIUnavailableFallbackVerified",
    "wingmanConsentPreviewVerified",
    "wingmanRemoteReviewSucceeded",
)
properties = base_record.get("properties", {})
for key in boolean_keys:
    if properties.get(key, {}).get("const") is not True:
        raise SystemExit(f"baseRecord.properties.{key}.const must be true")
PY
  fail "Clean-machine acceptance schema record contract is invalid"
fi

RELEASE_NOTES_VALID="$TEMP_ROOT/release-notes-valid.md"
sed \
  -e 's/REPLACE_WITH_RELEASE_TAG/v1.2.0-beta.3/g' \
  -e 's/REPLACE_WITH_CONCISE_USER_VISIBLE_CHANGE/Fixed-schema acceptance evidence without task text or raw task identifiers is now required./g' \
  -e 's/REPLACE_WITH_RELEASE_SPECIFIC_LIMITATION/Native macOS file-panel chrome follows the system language./g' \
  -e 's/REPLACE_WITH_DMG_ASSET_NAME/AiWingman-1.2.0-beta.3-macOS-universal2.dmg/g' \
  -e 's/REPLACE_WITH_ZIP_ASSET_NAME/AiWingman-1.2.0-beta.3-macOS-universal2.zip/g' \
  -e 's/REPLACE_WITH_ACCEPTANCE_ASSET_NAME/AiWingman-1.2.0-beta.3-CLEAN-MACHINE-ACCEPTANCE.json/g' \
  Packaging/RELEASE_NOTES_TEMPLATE.md > "$RELEASE_NOTES_VALID"
swift scripts/release-notes-check.swift \
  "$RELEASE_NOTES_VALID" \
  mehmetsolakedu/activity-radar \
  v1.2.0-beta.3 \
  AiWingman-1.2.0-beta.3-macOS-universal2.zip \
  AiWingman-1.2.0-beta.3-macOS-universal2.dmg \
  AiWingman-1.2.0-beta.3-CLEAN-MACHINE-ACCEPTANCE.json \
  || fail "Canonical release-notes fixture was rejected"
if swift scripts/release-notes-check.swift \
  Packaging/RELEASE_NOTES_TEMPLATE.md \
  mehmetsolakedu/activity-radar \
  v1.2.0-beta.3 \
  AiWingman-1.2.0-beta.3-macOS-universal2.zip \
  AiWingman-1.2.0-beta.3-macOS-universal2.dmg \
  AiWingman-1.2.0-beta.3-CLEAN-MACHINE-ACCEPTANCE.json >/dev/null 2>&1; then
  fail "Release-notes checker accepted unresolved placeholders"
fi
RELEASE_NOTES_MISSING_HEADING="$TEMP_ROOT/release-notes-missing-heading.md"
grep -v '^## Verify$' "$RELEASE_NOTES_VALID" > "$RELEASE_NOTES_MISSING_HEADING"
if swift scripts/release-notes-check.swift \
  "$RELEASE_NOTES_MISSING_HEADING" \
  mehmetsolakedu/activity-radar \
  v1.2.0-beta.3 \
  AiWingman-1.2.0-beta.3-macOS-universal2.zip \
  AiWingman-1.2.0-beta.3-macOS-universal2.dmg \
  AiWingman-1.2.0-beta.3-CLEAN-MACHINE-ACCEPTANCE.json >/dev/null 2>&1; then
  fail "Release-notes checker accepted a missing required heading"
fi

RELEASE_NOTES_EMPTY_CHANGES="$TEMP_ROOT/release-notes-empty-changes.md"
sed \
  -e '/^- Fixed-schema acceptance evidence without task text or raw task identifiers is now required\.$/d' \
  -e '/^- The dashboard and status menu can switch instantly between Turkish and English, and the selection persists across launches\.$/d' \
  "$RELEASE_NOTES_VALID" > "$RELEASE_NOTES_EMPTY_CHANGES"
if swift scripts/release-notes-check.swift \
  "$RELEASE_NOTES_EMPTY_CHANGES" \
  mehmetsolakedu/activity-radar \
  v1.2.0-beta.3 \
  AiWingman-1.2.0-beta.3-macOS-universal2.zip \
  AiWingman-1.2.0-beta.3-macOS-universal2.dmg \
  AiWingman-1.2.0-beta.3-CLEAN-MACHINE-ACCEPTANCE.json >/dev/null 2>&1; then
  fail "Release-notes checker accepted an empty Changes section"
fi

RELEASE_NOTES_EMPTY_LIMITATIONS="$TEMP_ROOT/release-notes-empty-limitations.md"
sed '/^- Native macOS file-panel chrome follows the system language\.$/d' \
  "$RELEASE_NOTES_VALID" > "$RELEASE_NOTES_EMPTY_LIMITATIONS"
if swift scripts/release-notes-check.swift \
  "$RELEASE_NOTES_EMPTY_LIMITATIONS" \
  mehmetsolakedu/activity-radar \
  v1.2.0-beta.3 \
  AiWingman-1.2.0-beta.3-macOS-universal2.zip \
  AiWingman-1.2.0-beta.3-macOS-universal2.dmg \
  AiWingman-1.2.0-beta.3-CLEAN-MACHINE-ACCEPTANCE.json >/dev/null 2>&1; then
  fail "Release-notes checker accepted an empty Known limitations section"
fi

RELEASE_NOTES_FIXME="$TEMP_ROOT/release-notes-fixme.md"
sed 's/Fixed-schema acceptance evidence without task text or raw task identifiers is now required\./FIXME/g' \
  "$RELEASE_NOTES_VALID" > "$RELEASE_NOTES_FIXME"
if swift scripts/release-notes-check.swift \
  "$RELEASE_NOTES_FIXME" \
  mehmetsolakedu/activity-radar \
  v1.2.0-beta.3 \
  AiWingman-1.2.0-beta.3-macOS-universal2.zip \
  AiWingman-1.2.0-beta.3-macOS-universal2.dmg \
  AiWingman-1.2.0-beta.3-CLEAN-MACHINE-ACCEPTANCE.json >/dev/null 2>&1; then
  fail "Release-notes checker accepted a FIXME placeholder"
fi

ACCEPTANCE_WORKING="$TEMP_ROOT/acceptance-working.json"
ACCEPTANCE_VALID="$TEMP_ROOT/AiWingman-1.2.0-beta.3-CLEAN-MACHINE-ACCEPTANCE.json"
ditto --noqtn --noextattr --norsrc \
  Packaging/CLEAN_MACHINE_ACCEPTANCE.template.json \
  "$ACCEPTANCE_WORKING"
plutil -replace dmgAssetName \
  -string AiWingman-1.2.0-beta.3-macOS-universal2.dmg \
  "$ACCEPTANCE_WORKING"
plutil -replace dmgSHA256 \
  -string 0000000000000000000000000000000000000000000000000000000000000000 \
  "$ACCEPTANCE_WORKING"
plutil -replace releaseID -integer 123456789 "$ACCEPTANCE_WORKING"
plutil -replace releaseTag -string v1.2.0-beta.3 "$ACCEPTANCE_WORKING"
plutil -replace releaseCreatedAt \
  -string 2026-08-19T23:59:00Z "$ACCEPTANCE_WORKING"
for acceptance_index in 0 1; do
  if [[ "$acceptance_index" == "0" ]]; then
    ACCEPTANCE_MACOS_VERSION=13.7.8
    ACCEPTANCE_MACOS_BUILD=22H730
    ACCEPTANCE_TESTED_AT=2026-08-20T00:00:00Z
  else
    ACCEPTANCE_MACOS_VERSION=15.6
    ACCEPTANCE_MACOS_BUILD=24G84
    ACCEPTANCE_TESTED_AT=2026-08-20T00:01:00Z
  fi
  plutil -replace "records.$acceptance_index.macOSVersion" \
    -string "$ACCEPTANCE_MACOS_VERSION" "$ACCEPTANCE_WORKING"
  plutil -replace "records.$acceptance_index.macOSBuild" \
    -string "$ACCEPTANCE_MACOS_BUILD" "$ACCEPTANCE_WORKING"
  plutil -replace "records.$acceptance_index.testedAt" \
    -string "$ACCEPTANCE_TESTED_AT" "$ACCEPTANCE_WORKING"
  for acceptance_boolean in \
    aboutReleaseIdentityVerified \
    applicationCopiedToApplications \
    applicationReplacementSucceeded \
    browserDownloadQuarantineObserved \
    checksumVerified \
    dmgEjected \
    dmgMountedReadOnly \
    downloadedFromGitHubRelease \
    gatekeeperLaunchSucceeded \
    interfaceLanguageSwitchPersisted \
    machineDidNotBuildRelease \
    menuBarItemVisible \
    supportInformationContentFree \
    syntheticCodexDeepLinkSucceeded \
    uninstallSucceeded \
    wingmanCLIUnavailableFallbackVerified \
    wingmanConsentPreviewVerified \
    wingmanRemoteReviewSucceeded; do
    plutil -replace "records.$acceptance_index.$acceptance_boolean" \
      -bool true "$ACCEPTANCE_WORKING"
  done
done
swift scripts/clean-machine-acceptance-check.swift \
  --canonicalize \
  "$ACCEPTANCE_WORKING" \
  mehmetsolakedu/activity-radar \
  v1.2.0-beta.3 \
  123456789 \
  2026-08-19T23:59:00Z \
  AiWingman-1.2.0-beta.3-macOS-universal2.dmg \
  0000000000000000000000000000000000000000000000000000000000000000 \
  > "$ACCEPTANCE_VALID"
swift scripts/clean-machine-acceptance-check.swift \
  "$ACCEPTANCE_VALID" \
  mehmetsolakedu/activity-radar \
  v1.2.0-beta.3 \
  123456789 \
  2026-08-19T23:59:00Z \
  AiWingman-1.2.0-beta.3-macOS-universal2.dmg \
  0000000000000000000000000000000000000000000000000000000000000000 \
  || fail "Canonical clean-machine acceptance fixture was rejected"
ACCEPTANCE_PRIVACY_ROOT="$TEMP_ROOT/acceptance-privacy"
mkdir -p "$ACCEPTANCE_PRIVACY_ROOT"
ditto --noqtn --noextattr --norsrc \
  "$ACCEPTANCE_VALID" "$ACCEPTANCE_PRIVACY_ROOT/${ACCEPTANCE_VALID:t}"
zsh scripts/public-privacy-scan.sh "$ACCEPTANCE_PRIVACY_ROOT" \
  || fail "Fixed-schema clean-machine acceptance fixture failed the privacy scan"
if swift scripts/clean-machine-acceptance-check.swift \
  "$ACCEPTANCE_VALID" \
  mehmetsolakedu/activity-radar \
  v1.2.0-beta.3 \
  987654321 \
  2026-08-19T23:59:00Z \
  AiWingman-1.2.0-beta.3-macOS-universal2.dmg \
  0000000000000000000000000000000000000000000000000000000000000000 >/dev/null 2>&1; then
  fail "Clean-machine acceptance checker accepted the wrong release ID"
fi
if swift scripts/clean-machine-acceptance-check.swift \
  "$ACCEPTANCE_VALID" \
  mehmetsolakedu/activity-radar \
  v1.2.0-beta.3 \
  123456789 \
  2026-08-19T23:58:59Z \
  AiWingman-1.2.0-beta.3-macOS-universal2.dmg \
  0000000000000000000000000000000000000000000000000000000000000000 >/dev/null 2>&1; then
  fail "Clean-machine acceptance checker accepted the wrong release creation time"
fi

ACCEPTANCE_FALSE="$TEMP_ROOT/acceptance-false.json"
ditto --noqtn --noextattr --norsrc "$ACCEPTANCE_VALID" "$ACCEPTANCE_FALSE"
plutil -replace records.0.gatekeeperLaunchSucceeded -bool false "$ACCEPTANCE_FALSE"
if swift scripts/clean-machine-acceptance-check.swift \
  "$ACCEPTANCE_FALSE" \
  mehmetsolakedu/activity-radar \
  v1.2.0-beta.3 \
  123456789 \
  2026-08-19T23:59:00Z \
  AiWingman-1.2.0-beta.3-macOS-universal2.dmg \
  0000000000000000000000000000000000000000000000000000000000000000 >/dev/null 2>&1; then
  fail "Clean-machine acceptance checker accepted a failed Gatekeeper test"
fi

ACCEPTANCE_NO_VENTURA="$TEMP_ROOT/acceptance-no-ventura.json"
ditto --noqtn --noextattr --norsrc "$ACCEPTANCE_VALID" "$ACCEPTANCE_NO_VENTURA"
plutil -replace records.0.macOSVersion -string 14.7.8 "$ACCEPTANCE_NO_VENTURA"
if swift scripts/clean-machine-acceptance-check.swift \
  "$ACCEPTANCE_NO_VENTURA" \
  mehmetsolakedu/activity-radar \
  v1.2.0-beta.3 \
  123456789 \
  2026-08-19T23:59:00Z \
  AiWingman-1.2.0-beta.3-macOS-universal2.dmg \
  0000000000000000000000000000000000000000000000000000000000000000 >/dev/null 2>&1; then
  fail "Clean-machine acceptance checker accepted no macOS 13.x runtime result"
fi

ACCEPTANCE_UNKNOWN_FIELD="$TEMP_ROOT/acceptance-unknown-field.json"
ditto --noqtn --noextattr --norsrc "$ACCEPTANCE_VALID" "$ACCEPTANCE_UNKNOWN_FIELD"
plutil -insert records.0.tester -string private-person "$ACCEPTANCE_UNKNOWN_FIELD"
if swift scripts/clean-machine-acceptance-check.swift \
  "$ACCEPTANCE_UNKNOWN_FIELD" \
  mehmetsolakedu/activity-radar \
  v1.2.0-beta.3 \
  123456789 \
  2026-08-19T23:59:00Z \
  AiWingman-1.2.0-beta.3-macOS-universal2.dmg \
  0000000000000000000000000000000000000000000000000000000000000000 >/dev/null 2>&1; then
  fail "Clean-machine acceptance checker accepted a free-text tester field"
fi

ACCEPTANCE_BEFORE_DRAFT="$TEMP_ROOT/acceptance-before-draft.json"
ditto --noqtn --noextattr --norsrc "$ACCEPTANCE_VALID" "$ACCEPTANCE_BEFORE_DRAFT"
plutil -replace records.0.testedAt -string 2026-08-19T23:58:59Z "$ACCEPTANCE_BEFORE_DRAFT"
if swift scripts/clean-machine-acceptance-check.swift \
  --canonicalize \
  "$ACCEPTANCE_BEFORE_DRAFT" \
  mehmetsolakedu/activity-radar \
  v1.2.0-beta.3 \
  123456789 \
  2026-08-19T23:59:00Z \
  AiWingman-1.2.0-beta.3-macOS-universal2.dmg \
  0000000000000000000000000000000000000000000000000000000000000000 >/dev/null 2>&1; then
  fail "Clean-machine acceptance checker accepted a test before draft creation"
fi

ACCEPTANCE_INVALID_HOUR="$TEMP_ROOT/acceptance-invalid-hour.json"
ditto --noqtn --noextattr --norsrc "$ACCEPTANCE_VALID" "$ACCEPTANCE_INVALID_HOUR"
plutil -replace records.0.testedAt -string 2026-08-19T24:00:00Z "$ACCEPTANCE_INVALID_HOUR"
if swift scripts/clean-machine-acceptance-check.swift \
  --canonicalize \
  "$ACCEPTANCE_INVALID_HOUR" \
  mehmetsolakedu/activity-radar \
  v1.2.0-beta.3 \
  123456789 \
  2026-08-19T23:59:00Z \
  AiWingman-1.2.0-beta.3-macOS-universal2.dmg \
  0000000000000000000000000000000000000000000000000000000000000000 >/dev/null 2>&1; then
  fail "Clean-machine acceptance canonicalizer normalized an invalid 24:00 timestamp"
fi

ACCEPTANCE_INVALID_DATE="$TEMP_ROOT/acceptance-invalid-date.json"
ditto --noqtn --noextattr --norsrc "$ACCEPTANCE_VALID" "$ACCEPTANCE_INVALID_DATE"
plutil -replace releaseCreatedAt -string 2026-02-28T23:59:00Z "$ACCEPTANCE_INVALID_DATE"
plutil -replace records.0.testedAt -string 2026-02-30T00:00:00Z "$ACCEPTANCE_INVALID_DATE"
plutil -replace records.1.testedAt -string 2026-03-03T00:01:00Z "$ACCEPTANCE_INVALID_DATE"
if swift scripts/clean-machine-acceptance-check.swift \
  --canonicalize \
  "$ACCEPTANCE_INVALID_DATE" \
  mehmetsolakedu/activity-radar \
  v1.2.0-beta.3 \
  123456789 \
  2026-02-28T23:59:00Z \
  AiWingman-1.2.0-beta.3-macOS-universal2.dmg \
  0000000000000000000000000000000000000000000000000000000000000000 >/dev/null 2>&1; then
  fail "Clean-machine acceptance canonicalizer normalized an invalid calendar date"
fi

ACCEPTANCE_DUPLICATE_KEY="$TEMP_ROOT/acceptance-duplicate-key.json"
awk '
  { print }
  /"gatekeeperLaunchSucceeded" : true,/ && !inserted {
    print "      \"gatekeeperLaunchSucceeded\" : false,"
    inserted = 1
  }
' "$ACCEPTANCE_VALID" > "$ACCEPTANCE_DUPLICATE_KEY"
if swift scripts/clean-machine-acceptance-check.swift \
  "$ACCEPTANCE_DUPLICATE_KEY" \
  mehmetsolakedu/activity-radar \
  v1.2.0-beta.3 \
  123456789 \
  2026-08-19T23:59:00Z \
  AiWingman-1.2.0-beta.3-macOS-universal2.dmg \
  0000000000000000000000000000000000000000000000000000000000000000 >/dev/null 2>&1; then
  fail "Clean-machine acceptance checker accepted a duplicate JSON key"
fi
if swift scripts/clean-machine-acceptance-check.swift \
  --canonicalize \
  "$ACCEPTANCE_DUPLICATE_KEY" \
  mehmetsolakedu/activity-radar \
  v1.2.0-beta.3 \
  123456789 \
  2026-08-19T23:59:00Z \
  AiWingman-1.2.0-beta.3-macOS-universal2.dmg \
  0000000000000000000000000000000000000000000000000000000000000000 >/dev/null 2>&1; then
  fail "Clean-machine acceptance canonicalizer accepted conflicting duplicate keys"
fi

ACCEPTANCE_ESCAPED_DUPLICATE_KEY="$TEMP_ROOT/acceptance-escaped-duplicate-key.json"
awk '
  { print }
  /"gatekeeperLaunchSucceeded" : true,/ && !inserted {
    print "      \"\\u0067atekeeperLaunchSucceeded\" : false,"
    inserted = 1
  }
' "$ACCEPTANCE_VALID" > "$ACCEPTANCE_ESCAPED_DUPLICATE_KEY"
if swift scripts/clean-machine-acceptance-check.swift \
  --canonicalize \
  "$ACCEPTANCE_ESCAPED_DUPLICATE_KEY" \
  mehmetsolakedu/activity-radar \
  v1.2.0-beta.3 \
  123456789 \
  2026-08-19T23:59:00Z \
  AiWingman-1.2.0-beta.3-macOS-universal2.dmg \
  0000000000000000000000000000000000000000000000000000000000000000 >/dev/null 2>&1; then
  fail "Clean-machine acceptance canonicalizer accepted an escaped duplicate key"
fi

note "Checking canonical DMG topology contract"
swiftc -typecheck scripts/dmg-topology-check.swift
TOPOLOGY_ROOT="$TEMP_ROOT/dmg-topology"
TOPOLOGY_SOURCE="$TOPOLOGY_ROOT/source"
TOPOLOGY_MOUNT="$TOPOLOGY_ROOT/mount"
TOPOLOGY_DMG="$TOPOLOGY_ROOT/AiWingman-test.dmg"
mkdir -p "$TOPOLOGY_SOURCE/AiWingman.app" "$TOPOLOGY_MOUNT"
ln -s /Applications "$TOPOLOGY_SOURCE/Applications"
COPYFILE_DISABLE=1 hdiutil create \
  -quiet \
  -volname "AiWingman" \
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

note "Checking compressed artifact privacy fixtures"
COMPRESSED_PRIVACY_ROOT="$TEMP_ROOT/privacy-compressed"
python3 - "$COMPRESSED_PRIVACY_ROOT" <<'PY'
import base64
import sys
import zipfile
import zlib
from pathlib import Path
from xml.sax.saxutils import escape

root = Path(sys.argv[1])
root.mkdir(parents=True)

synthetic_uuid = "123e4567-e89b-42d3-a456-426614174000"
synthetic_payload = (
    "/" + "Users/example/project "
    + "codex://threads/" + synthetic_uuid + " "
    + synthetic_uuid
).encode("utf-8")
private_uuid = "aaaaaaaa-bbbb-" + "4ccc-8ddd-eeeeeeeeeeee"
private_payloads = {
    "private-path": ("/" + "Users/private-fixture/project").encode("utf-8"),
    "task-uri": ("codex://threads/" + private_uuid).encode("utf-8"),
    "credential": ("ghp_" + "A" * 30).encode("utf-8"),
    "uuid": private_uuid.encode("utf-8"),
}


def fixture_directory(name):
    directory = root / name
    directory.mkdir()
    return directory


def write_docx(directory, payload):
    document = (
        '<?xml version="1.0" encoding="UTF-8"?>'
        '<document><text>' + escape(payload.decode("utf-8")) + '</text></document>'
    ).encode("utf-8")
    content_types = (
        '<?xml version="1.0" encoding="UTF-8"?>'
        '<Types><Default Extension="xml" ContentType="application/xml"/></Types>'
    ).encode("utf-8")
    with zipfile.ZipFile(
        directory / "fixture.docx", "w", zipfile.ZIP_DEFLATED, compresslevel=9
    ) as archive:
        archive.writestr("[Content_Types].xml", content_types)
        archive.writestr("word/document.xml", document)


def write_pdf(directory, payload, use_ascii85=False, filter_name=None):
    if filter_name is not None:
        encoded = payload
        filter_declaration = b"/" + filter_name
    else:
        encoded = zlib.compress(payload, level=9)
        filter_declaration = b"/FlateDecode"
        if use_ascii85:
            encoded = base64.a85encode(encoded, adobe=False) + b"~>"
            filter_declaration = b"[ /ASCII85Decode /FlateDecode ]"
    pdf = (
        b"%PDF-1.4\n1 0 obj\n<< /Filter "
        + filter_declaration
        + b" /Length "
        + str(len(encoded)).encode("ascii")
        + b" >>\nstream\n"
        + encoded
        + b"\nendstream\nendobj\n%%EOF\n"
    )
    (directory / "fixture.pdf").write_bytes(pdf)


clean = fixture_directory("clean")
write_docx(clean, synthetic_payload)
write_pdf(clean, synthetic_payload, use_ascii85=True)

for index, (name, payload) in enumerate(private_payloads.items()):
    write_docx(fixture_directory("docx-" + name), payload)
    write_pdf(
        fixture_directory("pdf-" + name),
        payload,
        use_ascii85=bool(index % 2),
    )

malformed_docx = fixture_directory("malformed-docx")
(malformed_docx / "fixture.docx").write_bytes(zlib.compress(b"not a ZIP archive"))
write_pdf(
    fixture_directory("unsupported-pdf-filter"),
    b"content-free fixture",
    filter_name=b"LZWDecode",
)
PY

zsh scripts/public-privacy-scan.sh "$COMPRESSED_PRIVACY_ROOT/clean" \
  || fail "Privacy scanner rejected clean compressed artifacts with synthetic identifiers"
for compressed_private_fixture in \
  docx-private-path \
  docx-task-uri \
  docx-credential \
  docx-uuid \
  pdf-private-path \
  pdf-task-uri \
  pdf-credential \
  pdf-uuid; do
  COMPRESSED_FIXTURE_LOG="$TEMP_ROOT/${compressed_private_fixture}.log"
  if zsh scripts/public-privacy-scan.sh \
    "$COMPRESSED_PRIVACY_ROOT/$compressed_private_fixture" \
    >"$COMPRESSED_FIXTURE_LOG" 2>&1; then
    fail "Privacy scanner accepted a private pattern inside a compressed artifact"
  fi
  grep -Fq 'Compressed artifact privacy scan found' "$COMPRESSED_FIXTURE_LOG" \
    || fail "Compressed privacy fixture failed outside the decoded-content gate"
  if rg -Fq \
    -e "$PRIVATE_HOME_FIXTURE" \
    -e "$PRIVATE_TASK_LINK" \
    -e "$PRIVATE_CREDENTIAL_FIXTURE" \
    -e "$PRIVATE_TASK_UUID" \
    "$COMPRESSED_FIXTURE_LOG"; then
    fail "Compressed privacy scanner echoed matched private content"
  fi
done

for malformed_compressed_fixture in malformed-docx unsupported-pdf-filter; do
  COMPRESSED_FIXTURE_LOG="$TEMP_ROOT/${malformed_compressed_fixture}.log"
  if zsh scripts/public-privacy-scan.sh \
    "$COMPRESSED_PRIVACY_ROOT/$malformed_compressed_fixture" \
    >"$COMPRESSED_FIXTURE_LOG" 2>&1; then
    fail "Privacy scanner accepted an unscannable compressed artifact"
  fi
  grep -Fq 'Compressed artifact privacy scan failed closed' "$COMPRESSED_FIXTURE_LOG" \
    || fail "Malformed compressed artifact did not fail at the compressed scanner"
done

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
printf '%s\n' 'synthetic unexpected archive' > "$MANIFEST_FIXTURE_ROOT/unexpected.zip"
printf '%s\n' 'unexpected.zip' > "$MANIFEST_FIXTURE_ROOT/PUBLIC_SOURCE_MANIFEST.txt"
UNEXPECTED_ZIP_LOG="$TEMP_ROOT/unexpected-zip.log"
if zsh "$MANIFEST_FIXTURE_ROOT/scripts/export-public-source.sh" \
  "$TEMP_ROOT/unexpected-zip-export" >"$UNEXPECTED_ZIP_LOG" 2>&1; then
  fail "Public exporter accepted an unreviewed ZIP path"
fi
grep -Fq 'Forbidden generated ZIP outside the reviewed research supplement path.' \
  "$UNEXPECTED_ZIP_LOG" \
  || fail "Unreviewed ZIP fixture failed for a reason other than the ZIP allowlist"
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
KNOWN_SWIFT_TEST='turnLifecycleAndFinalAnswer'
STANDARD_TESTS_RAN=0
TEST_LIST=''
TEST_LIST_STATUS=0
if TEST_LIST="$(swift test list 2>&1)"; then
  TEST_LIST_STATUS=0
else
  TEST_LIST_STATUS=$?
fi

if (( TEST_LIST_STATUS == 0 )) \
  && print -r -- "$TEST_LIST" | grep -F "$KNOWN_SWIFT_TEST" >/dev/null; then
  swift test
  STANDARD_TESTS_RAN=1
else
  CLT_DEVELOPER_DIR='/Library/Developer/CommandLineTools'
  ACTIVE_DEVELOPER_DIR="$(xcode-select -p 2>/dev/null || true)"
  CLT_FRAMEWORK_DIR="$CLT_DEVELOPER_DIR/Library/Developer/Frameworks"
  CLT_INTEROP_DIR="$CLT_DEVELOPER_DIR/Library/Developer/usr/lib"
  CLT_TEST_LIST=''
  CLT_TEST_LIST_STATUS=1

  if [[ "$ACTIVE_DEVELOPER_DIR" == "$CLT_DEVELOPER_DIR" \
    && -d "$CLT_FRAMEWORK_DIR/Testing.framework" \
    && -d "$CLT_INTEROP_DIR" ]]; then
    note "Retrying standard tests with the bundled Command Line Tools Testing framework"
    typeset -a CLT_TEST_ARGUMENTS
    CLT_TEST_ARGUMENTS=(
      --scratch-path "$TEMP_ROOT/swift-testing-clt"
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
      swift test "${CLT_TEST_ARGUMENTS[@]}"
      STANDARD_TESTS_RAN=1
    fi
  fi

  if (( STANDARD_TESTS_RAN == 0 )); then
    if [[ "${REQUIRE_STANDARD_TESTS:-0}" == "1" ]]; then
      print -u2 -- "Default test discovery output:"
      print -r -- "$TEST_LIST" >&2
      if [[ -n "$CLT_TEST_LIST" ]]; then
        print -u2 -- "Command Line Tools fallback discovery output:"
        print -r -- "$CLT_TEST_LIST" >&2
      fi
      fail "Standard tests were required but no known test was discovered"
    else
      print -u2 -- "NOTICE: Standard tests were not discovered by this toolchain; CI must run them before a public binary release."
    fi
  fi
fi

note "Building release products"
swift build -c release --product ActivityRadar
swift build -c release --product ActivityRadarDiagnostics

note "Verifying fixed-schema diagnostics without task text or raw task identifiers"
DIAGNOSTIC_HOME="$TEMP_ROOT/activity-radar-diagnostic-home"
DIAGNOSTIC_STATE="$DIAGNOSTIC_HOME/.codex/state_5.sqlite"
DIAGNOSTIC_ROLLOUT="$DIAGNOSTIC_HOME/.codex/PRIVATE-PATH-SENTINEL.jsonl"
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
  fail "Fixed-schema diagnostics exposed a forbidden task-level field"
else
  DIAGNOSTIC_FIELD_SCAN_STATUS=$?
  [[ "$DIAGNOSTIC_FIELD_SCAN_STATUS" == "1" ]] \
    || fail "Fixed-schema diagnostic field scan did not complete"
fi
if rg -q 'PRIVATE-' "$DIAGNOSTIC_JSON"; then
  fail "Fixed-schema diagnostics exposed synthetic private content"
else
  DIAGNOSTIC_SENTINEL_SCAN_STATUS=$?
  [[ "$DIAGNOSTIC_SENTINEL_SCAN_STATUS" == "1" ]] \
    || fail "Fixed-schema diagnostic sentinel scan did not complete"
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
LOCAL_APP="$TEMP_ROOT/AiWingman.app"
ACTIVITY_RADAR_BUNDLE_ID=io.github.mehmetsolakedu.ActivityRadar \
  "$PUBLIC_SOURCE/scripts/package-app.sh" \
  --mode local \
  --output-app "$LOCAL_APP"
lipo "$LOCAL_APP/Contents/MacOS/ActivityRadar" -verify_arch arm64 x86_64
[[ "$(plutil -extract CFBundleIdentifier raw -o - "$LOCAL_APP/Contents/Info.plist")" == "local.mehmet.activityradar" ]] \
  || fail "Local package did not retain the legacy bundle identifier"
codesign --verify --deep --strict --verbose=2 "$LOCAL_APP"

note "Rejecting newline-confusable bundle payloads"
swift "$PUBLIC_SOURCE/scripts/dmg-topology-check.swift" bundle "$LOCAL_APP" \
  || fail "Canonical local bundle was rejected by the exact topology gate"
TAMPERED_APP="$TEMP_ROOT/Tampered AiWingman.app"
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
  /usr/bin/zip -X -q -r "$CANONICAL_ZIP_A" "AiWingman.app"
  /usr/bin/zip -X -q -r "$CANONICAL_ZIP_B" "AiWingman.app"
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
print "PASS  AiWingman public-source preparation"
