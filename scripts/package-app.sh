#!/bin/zsh
set -euo pipefail

# Activity Radar macOS packager
#
# local  : repeatable Universal 2 app bundle, ad-hoc signed unless an identity
#          is explicitly supplied. This mode is never described as public.
# public : Universal 2 + Developer ID + hardened runtime + notarized/stapled
#          app and DMG + Gatekeeper checks + ZIP/DMG SHA-256 checksums.

umask 022
export SWIFT_DETERMINISTIC_HASHING=1
export ZERO_AR_DATE=1

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
DEFAULT_LOCAL_APP="${PROJECT_DIR:h}/Activity Radar.app"
DEFAULT_DIST_DIR="$PROJECT_DIR/dist"
SOURCE_ICON="$PROJECT_DIR/Assets/ActivityRadar-Source.png"
INFO_PLIST="$PROJECT_DIR/Packaging/Info.plist"
ENTITLEMENTS="$PROJECT_DIR/Packaging/ActivityRadar.entitlements"

MODE="local"
OUTPUT_APP=""
DIST_DIR="$DEFAULT_DIST_DIR"
SIGNING_IDENTITY="${DEVELOPER_ID_APPLICATION:-}"
NOTARY_PROFILE="${NOTARY_KEYCHAIN_PROFILE:-}"
NOTARY_KEYCHAIN="${NOTARY_KEYCHAIN_PATH:-}"
BUNDLE_IDENTIFIER="${ACTIVITY_RADAR_BUNDLE_ID:-}"
BUILD_EPOCH="${SOURCE_DATE_EPOCH:-946684800}"
OVERWRITE=0
LEGACY_OUTPUT_SEEN=0

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/package-app.sh [local-output.app]
  ./scripts/package-app.sh --mode local [options]
  ./scripts/package-app.sh --mode public [options]

Modes:
  local                 Build a Universal 2 app for local development. This is
                        the default. Without --identity it is ad-hoc signed and
                        is explicitly not a public release.
  public                Build public ZIP and DMG artifacts. Developer ID,
                        notarization, stapling, and Gatekeeper checks are hard
                        requirements; there is no ad-hoc fallback.

Options:
  --output-app PATH     Local-mode app destination (default: ../Activity Radar.app)
  --dist-dir PATH       Public-mode release root (default: ./dist)
  --identity NAME       Developer ID Application identity. May also be supplied
                        via DEVELOPER_ID_APPLICATION.
  --notary-profile NAME notarytool Keychain profile. May also be supplied via
                        NOTARY_KEYCHAIN_PROFILE.
  --notary-keychain PATH
                        Optional Keychain file containing the notary profile.
                        May also be supplied via NOTARY_KEYCHAIN_PATH.
  --bundle-id ID        Override CFBundleIdentifier in the staged bundle. May
                        also be supplied via ACTIVITY_RADAR_BUNDLE_ID.
  --source-date-epoch N Normalize bundle/archive mtimes to this Unix timestamp.
                        Default: 946684800 (2000-01-01T00:00:00Z).
  --overwrite           Replace only the exact local app or versioned public
                        release directory that this invocation targets.
  -h, --help            Show this help.

Public example (placeholder values only):
  ./scripts/package-app.sh --mode public \
    --identity "Developer ID Application: Example Org (TEAMID)" \
    --notary-profile "activity-radar-notary" \
    --bundle-id "com.example.activityradar"

The public mode never accepts Apple ID passwords or API private keys on its
command line. Store notarization credentials with `xcrun notarytool
store-credentials` and pass only the Keychain profile name here.
USAGE
}

fail() {
  print -u2 -- "ERROR: $*"
  exit 1
}

note() {
  print -u2 -- "==> $*"
}

need_tool() {
  command -v "$1" >/dev/null 2>&1 || fail "Required tool not found: $1"
}

while (( $# > 0 )); do
  case "$1" in
    --mode)
      (( $# >= 2 )) || fail "--mode requires local or public"
      MODE="$2"
      shift 2
      ;;
    --output-app)
      (( $# >= 2 )) || fail "--output-app requires a path"
      OUTPUT_APP="$2"
      shift 2
      ;;
    --dist-dir)
      (( $# >= 2 )) || fail "--dist-dir requires a path"
      DIST_DIR="$2"
      shift 2
      ;;
    --identity)
      (( $# >= 2 )) || fail "--identity requires a value"
      SIGNING_IDENTITY="$2"
      shift 2
      ;;
    --notary-profile)
      (( $# >= 2 )) || fail "--notary-profile requires a value"
      NOTARY_PROFILE="$2"
      shift 2
      ;;
    --notary-keychain)
      (( $# >= 2 )) || fail "--notary-keychain requires a path"
      NOTARY_KEYCHAIN="$2"
      shift 2
      ;;
    --bundle-id)
      (( $# >= 2 )) || fail "--bundle-id requires a value"
      BUNDLE_IDENTIFIER="$2"
      shift 2
      ;;
    --source-date-epoch)
      (( $# >= 2 )) || fail "--source-date-epoch requires an integer"
      BUILD_EPOCH="$2"
      shift 2
      ;;
    --overwrite)
      OVERWRITE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      fail "Unknown option: $1"
      ;;
    *)
      if (( LEGACY_OUTPUT_SEEN )); then
        fail "Unexpected positional argument: $1"
      fi
      OUTPUT_APP="$1"
      LEGACY_OUTPUT_SEEN=1
      shift
      ;;
  esac
done

(( $# == 0 )) || fail "Unexpected trailing arguments: $*"
[[ "$MODE" == "local" || "$MODE" == "public" ]] || fail "--mode must be local or public"
[[ "$BUILD_EPOCH" == <-> ]] || fail "SOURCE_DATE_EPOCH must contain decimal digits only"
(( BUILD_EPOCH >= 315532800 )) || fail "SOURCE_DATE_EPOCH must be 1980-01-01 or later for ZIP compatibility"

for tool in swift xcrun lipo vtool codesign ditto plutil sips iconutil find touch date awk grep sed security mkdir mktemp cp chmod rm mv ln basename cat; do
  need_tool "$tool"
done

[[ -f "$INFO_PLIST" ]] || fail "Missing Info.plist: $INFO_PLIST"
[[ -f "$SOURCE_ICON" ]] || fail "Missing source icon: $SOURCE_ICON"
[[ -f "$ENTITLEMENTS" ]] || fail "Missing entitlements file: $ENTITLEMENTS"
plutil -lint "$INFO_PLIST" >/dev/null || fail "Invalid Info.plist"
plutil -lint "$ENTITLEMENTS" >/dev/null || fail "Invalid entitlements plist"

VERSION="$(plutil -extract CFBundleShortVersionString raw -o - "$INFO_PLIST")"
BUILD_NUMBER="$(plutil -extract CFBundleVersion raw -o - "$INFO_PLIST")"
MIN_MACOS="$(plutil -extract LSMinimumSystemVersion raw -o - "$INFO_PLIST")"
PLIST_BUNDLE_IDENTIFIER="$(plutil -extract CFBundleIdentifier raw -o - "$INFO_PLIST")"
[[ -n "$BUNDLE_IDENTIFIER" ]] || BUNDLE_IDENTIFIER="$PLIST_BUNDLE_IDENTIFIER"

print -r -- "$VERSION" | grep -Eq '^[0-9]+(\.[0-9]+)*$' || fail "Unsafe CFBundleShortVersionString: $VERSION"
print -r -- "$BUILD_NUMBER" | grep -Eq '^[0-9]+$' || fail "CFBundleVersion must contain decimal digits: $BUILD_NUMBER"
print -r -- "$MIN_MACOS" | grep -Eq '^[0-9]+\.[0-9]+(\.[0-9]+)?$' || fail "Invalid LSMinimumSystemVersion: $MIN_MACOS"
print -r -- "$BUNDLE_IDENTIFIER" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9-]*(\.[A-Za-z0-9][A-Za-z0-9-]*)+$' || fail "Invalid bundle identifier: $BUNDLE_IDENTIFIER"
[[ "$BUNDLE_IDENTIFIER" == *.* ]] || fail "Bundle identifier must use reverse-DNS form: $BUNDLE_IDENTIFIER"

RELEASE_STEM="Activity-Radar-${VERSION}-macOS-universal2"
FINAL_RELEASE_DIR="$DIST_DIR/$RELEASE_STEM"

if [[ "$MODE" == "public" ]]; then
  (( LEGACY_OUTPUT_SEEN == 0 )) || fail "A positional app path is local-only; use --dist-dir for public mode"
  [[ -z "$OUTPUT_APP" ]] || fail "--output-app is local-only; use --dist-dir for public mode"
  [[ -n "$SIGNING_IDENTITY" ]] || fail "Public mode requires --identity (Developer ID Application); refusing ad-hoc public release"
  [[ -n "$NOTARY_PROFILE" ]] || fail "Public mode requires --notary-profile; refusing an unnotarized public release"
  [[ "$BUNDLE_IDENTIFIER" != local.* ]] || fail "Public mode refuses a local.* bundle identifier; pass --bundle-id"
  [[ "$DIST_DIR" != "/" && "$DIST_DIR" != "$HOME" && -n "$DIST_DIR" ]] || fail "Refusing unsafe dist directory: $DIST_DIR"
  for tool in security hdiutil shasum unzip spctl; do
    need_tool "$tool"
  done
  xcrun --find notarytool >/dev/null 2>&1 || fail "notarytool is unavailable"
  xcrun --find stapler >/dev/null 2>&1 || fail "stapler is unavailable"

  IDENTITIES="$(security find-identity -v -p codesigning 2>&1 || true)"
  [[ "$IDENTITIES" == *"$SIGNING_IDENTITY"* ]] || fail "Signing identity is not a valid codesigning identity in the current Keychain"
  MATCHED_IDENTITY_LINE="$(print -r -- "$IDENTITIES" | grep -F "$SIGNING_IDENTITY" | sed -n '1p')"
  [[ "$MATCHED_IDENTITY_LINE" == *"Developer ID Application:"* ]] || fail "Public mode requires a Developer ID Application identity"
  if [[ -e "$FINAL_RELEASE_DIR" && "$OVERWRITE" == "0" ]]; then
    fail "Release directory exists; pass --overwrite to replace: $FINAL_RELEASE_DIR"
  fi
else
  [[ -z "$NOTARY_PROFILE" ]] || fail "--notary-profile is valid only in public mode"
  [[ -z "$NOTARY_KEYCHAIN" ]] || fail "--notary-keychain is valid only in public mode"
  [[ -n "$OUTPUT_APP" ]] || OUTPUT_APP="$DEFAULT_LOCAL_APP"
  [[ "$OUTPUT_APP" == *.app && "$OUTPUT_APP" != "/" && "$OUTPUT_APP" != "$HOME" ]] || fail "Refusing unsafe output app path: $OUTPUT_APP"
  if [[ -e "$OUTPUT_APP" && "$OVERWRITE" == "0" ]]; then
    fail "Output exists; pass --overwrite to replace: $OUTPUT_APP"
  fi
fi

SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"
SDK_VERSION="$(xcrun --sdk macosx --show-sdk-version)"
TOUCH_STAMP="$(date -u -r "$BUILD_EPOCH" '+%Y%m%d%H%M.%S')"
STAGE_DIR="$(mktemp -d /tmp/activity-radar-package.XXXXXX)"
[[ "$STAGE_DIR" == /tmp/activity-radar-package.* ]] || fail "Unexpected temporary directory: $STAGE_DIR"

cleanup() {
  if [[ -n "${STAGE_DIR:-}" && "$STAGE_DIR" == /tmp/activity-radar-package.* && -d "$STAGE_DIR" ]]; then
    rm -rf -- "$STAGE_DIR"
  fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

normalize_tree_times() {
  local root="$1"
  find "$root" -exec touch -h -t "$TOUCH_STAMP" {} +
}

swift_build_arch() {
  local arch="$1"
  local triple="${arch}-apple-macosx${MIN_MACOS}"
  local scratch="$STAGE_DIR/build-$arch"

  note "Building ActivityRadar for $triple"
  swift build \
    --package-path "$PROJECT_DIR" \
    --scratch-path "$scratch" \
    --configuration release \
    --product ActivityRadar \
    --triple "$triple" \
    --sdk "$SDK_PATH" >&2

  local bin_dir
  bin_dir="$(swift build \
    --package-path "$PROJECT_DIR" \
    --scratch-path "$scratch" \
    --configuration release \
    --show-bin-path \
    --triple "$triple" \
    --sdk "$SDK_PATH")"

  local binary="$bin_dir/ActivityRadar"
  [[ -x "$binary" ]] || fail "SwiftPM did not produce $arch ActivityRadar binary"
  lipo "$binary" -verify_arch "$arch" >/dev/null || fail "$binary is not $arch"
  print -r -- "$binary"
}

verify_universal_binary() {
  local binary="$1"
  lipo "$binary" -verify_arch arm64 x86_64 >/dev/null || fail "Universal binary is missing arm64 or x86_64"

  local arch_words
  arch_words="$(lipo -archs "$binary")"
  local arch_count
  arch_count="$(print -r -- "$arch_words" | awk '{print NF}')"
  [[ "$arch_count" == "2" ]] || fail "Unexpected architectures in universal binary: $arch_words"

  local arch minos
  for arch in arm64 x86_64; do
    minos="$(vtool -arch "$arch" -show-build "$binary" | awk '/^[[:space:]]*minos / {print $2; exit}')"
    [[ "$minos" == "$MIN_MACOS" ]] || fail "$arch minimum macOS is $minos, expected $MIN_MACOS"
  done
}

sign_app() {
  local app="$1"
  if [[ -n "$SIGNING_IDENTITY" ]]; then
    note "Signing app with Developer ID and hardened runtime"
    codesign --force \
      --sign "$SIGNING_IDENTITY" \
      --options runtime \
      --timestamp \
      --entitlements "$ENTITLEMENTS" \
      "$app"
  else
    note "Applying ad-hoc signature (local mode only)"
    codesign --force --sign - --timestamp=none "$app"
  fi
  codesign --verify --deep --strict --verbose=2 "$app"
}

verify_developer_id_app() {
  local app="$1"
  local details
  details="$(codesign -d --verbose=4 "$app" 2>&1)"
  print -r -- "$details" | grep -F "Authority=Developer ID Application:" >/dev/null || fail "App is not signed by Developer ID Application"
  print -r -- "$details" | grep -E '^TeamIdentifier=[A-Z0-9]+$' >/dev/null || fail "App signature has no TeamIdentifier"
  print -r -- "$details" | grep -F 'runtime' >/dev/null || fail "App signature does not enable hardened runtime"
}

archive_app_zip() {
  local app="$1"
  local archive="$2"
  # Apple's recommended ditto ZIP form preserves any notarization ticket
  # metadata attached to the bundle. The source app is assembled in a clean
  # temporary directory, so no unrelated Finder metadata enters the archive.
  ditto -c -k --sequesterRsrc --keepParent "$app" "$archive"
  unzip -tq "$archive" >/dev/null || fail "ZIP integrity check failed: $archive"
}

notary_auth_args=()
if [[ -n "$NOTARY_PROFILE" ]]; then
  notary_auth_args+=(--keychain-profile "$NOTARY_PROFILE")
  if [[ -n "$NOTARY_KEYCHAIN" ]]; then
    notary_auth_args+=(--keychain "$NOTARY_KEYCHAIN")
  fi
fi

notarize_and_require_accepted() {
  local artifact="$1"
  local result_file="$2"
  note "Submitting $(basename "$artifact") to Apple notary service"
  if ! xcrun notarytool submit "$artifact" \
    "${notary_auth_args[@]}" \
    --wait \
    --no-progress \
    --output-format json >"$result_file"; then
    print -u2 -- "notarytool submission failed:"
    sed -n '1,220p' "$result_file" >&2 || true
    fail "Notarization command failed"
  fi

  local notary_status
  notary_status="$(plutil -extract status raw -o - "$result_file" 2>/dev/null || true)"
  if [[ "$notary_status" != "Accepted" ]]; then
    print -u2 -- "Notarization result:"
    sed -n '1,220p' "$result_file" >&2 || true
    fail "Apple notarization status is ${notary_status:-unknown}, expected Accepted"
  fi
}

ARM_BINARY="$(swift_build_arch arm64)"
X86_BINARY="$(swift_build_arch x86_64)"

STAGED_APP="$STAGE_DIR/Activity Radar.app"
CONTENTS="$STAGED_APP/Contents"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
lipo -create "$ARM_BINARY" "$X86_BINARY" -output "$CONTENTS/MacOS/ActivityRadar"
chmod 755 "$CONTENTS/MacOS/ActivityRadar"
cp "$INFO_PLIST" "$CONTENTS/Info.plist"
plutil -replace CFBundleIdentifier -string "$BUNDLE_IDENTIFIER" "$CONTENTS/Info.plist"

ICONSET="$STAGE_DIR/ActivityRadar.iconset"
mkdir -p "$ICONSET"
sips -z 16 16 "$SOURCE_ICON" --out "$ICONSET/icon_16x16.png" >/dev/null
sips -z 32 32 "$SOURCE_ICON" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$SOURCE_ICON" --out "$ICONSET/icon_32x32.png" >/dev/null
sips -z 64 64 "$SOURCE_ICON" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$SOURCE_ICON" --out "$ICONSET/icon_128x128.png" >/dev/null
sips -z 256 256 "$SOURCE_ICON" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$SOURCE_ICON" --out "$ICONSET/icon_256x256.png" >/dev/null
sips -z 512 512 "$SOURCE_ICON" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$SOURCE_ICON" --out "$ICONSET/icon_512x512.png" >/dev/null
sips -z 1024 1024 "$SOURCE_ICON" --out "$ICONSET/icon_512x512@2x.png" >/dev/null
iconutil -c icns "$ICONSET" -o "$CONTENTS/Resources/ActivityRadar.icns"

plutil -lint "$CONTENTS/Info.plist" >/dev/null
verify_universal_binary "$CONTENTS/MacOS/ActivityRadar"
normalize_tree_times "$STAGED_APP"
sign_app "$STAGED_APP"

if [[ "$MODE" == "local" ]]; then
  if [[ -e "$OUTPUT_APP" ]]; then
    (( OVERWRITE )) || fail "Output exists; pass --overwrite to replace: $OUTPUT_APP"
    [[ "$OUTPUT_APP" == *.app && "$OUTPUT_APP" != "/" && "$OUTPUT_APP" != "$HOME" ]] || fail "Refusing unsafe replacement: $OUTPUT_APP"
    rm -rf -- "$OUTPUT_APP"
  fi
  mkdir -p "${OUTPUT_APP:h}"
  ditto --norsrc --noextattr "$STAGED_APP" "$OUTPUT_APP"
  codesign --verify --deep --strict --verbose=2 "$OUTPUT_APP"
  verify_universal_binary "$OUTPUT_APP/Contents/MacOS/ActivityRadar"

  if [[ -n "$SIGNING_IDENTITY" ]]; then
    verify_developer_id_app "$OUTPUT_APP"
    print -- "LOCAL SIGNED BUILD (not notarized; not a public release):"
  else
    print -- "LOCAL AD-HOC BUILD (not a public release):"
  fi
  print -- "$OUTPUT_APP"
  exit 0
fi

verify_developer_id_app "$STAGED_APP"

# First notarize a ZIP containing the signed app so the app itself receives a
# ticket, then staple and validate that ticket before producing either public
# artifact.
NOTARY_APP_ZIP="$STAGE_DIR/notary-app.zip"
archive_app_zip "$STAGED_APP" "$NOTARY_APP_ZIP"
notarize_and_require_accepted "$NOTARY_APP_ZIP" "$STAGE_DIR/notary-app-result.json"
xcrun stapler staple -v "$STAGED_APP"
xcrun stapler validate -v "$STAGED_APP"
codesign --verify --deep --strict --verbose=2 "$STAGED_APP"
spctl --assess --type execute --verbose=4 "$STAGED_APP"

# Normalizing file mtimes does not change signed content. It keeps the final ZIP
# metadata stable while preserving the Developer ID signature and stapled ticket.
normalize_tree_times "$STAGED_APP"
codesign --verify --deep --strict --verbose=2 "$STAGED_APP"

RELEASE_STAGE="$STAGE_DIR/$RELEASE_STEM"
mkdir -p "$RELEASE_STAGE"
ditto --rsrc --extattr "$STAGED_APP" "$RELEASE_STAGE/Activity Radar.app"
xcrun stapler validate -v "$RELEASE_STAGE/Activity Radar.app"
codesign --verify --deep --strict --verbose=2 "$RELEASE_STAGE/Activity Radar.app"

ZIP_NAME="$RELEASE_STEM.zip"
DMG_NAME="$RELEASE_STEM.dmg"
archive_app_zip "$RELEASE_STAGE/Activity Radar.app" "$RELEASE_STAGE/$ZIP_NAME"
ZIP_VERIFY_DIR="$STAGE_DIR/zip-verify"
mkdir -p "$ZIP_VERIFY_DIR"
ditto -x -k "$RELEASE_STAGE/$ZIP_NAME" "$ZIP_VERIFY_DIR"
xcrun stapler validate -v "$ZIP_VERIFY_DIR/Activity Radar.app"
codesign --verify --deep --strict --verbose=2 "$ZIP_VERIFY_DIR/Activity Radar.app"
spctl --assess --type execute --verbose=4 "$ZIP_VERIFY_DIR/Activity Radar.app"

DMG_ROOT="$STAGE_DIR/dmg-root"
mkdir -p "$DMG_ROOT"
ditto --rsrc --extattr "$STAGED_APP" "$DMG_ROOT/Activity Radar.app"
ln -s /Applications "$DMG_ROOT/Applications"
normalize_tree_times "$DMG_ROOT"

note "Creating compressed DMG"
hdiutil create \
  -srcfolder "$DMG_ROOT" \
  -volname "Activity Radar" \
  -fs HFS+ \
  -format UDZO \
  -imagekey zlib-level=9 \
  -ov \
  "$RELEASE_STAGE/$DMG_NAME" >/dev/null
hdiutil verify "$RELEASE_STAGE/$DMG_NAME" >/dev/null

note "Signing DMG with Developer ID"
codesign --force --sign "$SIGNING_IDENTITY" --timestamp "$RELEASE_STAGE/$DMG_NAME"
codesign --verify --strict --verbose=2 "$RELEASE_STAGE/$DMG_NAME"
notarize_and_require_accepted "$RELEASE_STAGE/$DMG_NAME" "$STAGE_DIR/notary-dmg-result.json"
xcrun stapler staple -v "$RELEASE_STAGE/$DMG_NAME"
xcrun stapler validate -v "$RELEASE_STAGE/$DMG_NAME"
codesign --verify --strict --verbose=2 "$RELEASE_STAGE/$DMG_NAME"
hdiutil verify "$RELEASE_STAGE/$DMG_NAME" >/dev/null
spctl --assess --type open --context context:primary-signature --verbose=4 "$RELEASE_STAGE/$DMG_NAME"

cat >"$RELEASE_STAGE/RELEASE-MANIFEST.txt" <<MANIFEST
Product: Activity Radar
Version: $VERSION
Build: $BUILD_NUMBER
Bundle identifier: $BUNDLE_IDENTIFIER
Architectures: arm64 x86_64
Minimum macOS: $MIN_MACOS
SDK: macOS $SDK_VERSION
Build epoch: $BUILD_EPOCH
Signing: Developer ID Application, hardened runtime, secure timestamp
Application notarization: Accepted and stapled
Disk image notarization: Accepted and stapled
Artifacts: $ZIP_NAME, $DMG_NAME
MANIFEST
touch -h -t "$TOUCH_STAMP" "$RELEASE_STAGE/RELEASE-MANIFEST.txt"

(
  cd "$RELEASE_STAGE"
  shasum -a 256 "$ZIP_NAME" "$DMG_NAME" > SHA256SUMS
  shasum -a 256 -c SHA256SUMS
)

if [[ -e "$FINAL_RELEASE_DIR" ]]; then
  (( OVERWRITE )) || fail "Release directory exists; pass --overwrite to replace: $FINAL_RELEASE_DIR"
  [[ "$FINAL_RELEASE_DIR" == "$DIST_DIR"/Activity-Radar-*-macOS-universal2 ]] || fail "Refusing unsafe release replacement: $FINAL_RELEASE_DIR"
  rm -rf -- "$FINAL_RELEASE_DIR"
fi
mkdir -p "$DIST_DIR"
mv "$RELEASE_STAGE" "$FINAL_RELEASE_DIR"

# Verify the actual delivered paths too. This catches a cross-volume move that
# failed to preserve a signature or stapled ticket.
codesign --verify --deep --strict --verbose=2 "$FINAL_RELEASE_DIR/Activity Radar.app"
xcrun stapler validate -v "$FINAL_RELEASE_DIR/Activity Radar.app"
spctl --assess --type execute --verbose=4 "$FINAL_RELEASE_DIR/Activity Radar.app"
codesign --verify --strict --verbose=2 "$FINAL_RELEASE_DIR/$DMG_NAME"
xcrun stapler validate -v "$FINAL_RELEASE_DIR/$DMG_NAME"
hdiutil verify "$FINAL_RELEASE_DIR/$DMG_NAME" >/dev/null
spctl --assess --type open --context context:primary-signature --verbose=4 "$FINAL_RELEASE_DIR/$DMG_NAME"
(
  cd "$FINAL_RELEASE_DIR"
  unzip -tq "$ZIP_NAME" >/dev/null
  shasum -a 256 -c SHA256SUMS
)

note "Public release gates passed"
print -- "$FINAL_RELEASE_DIR"
print -- "  $ZIP_NAME"
print -- "  $DMG_NAME"
print -- "  SHA256SUMS"
