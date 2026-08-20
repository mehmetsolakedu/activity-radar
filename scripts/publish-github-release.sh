#!/bin/zsh
set -euo pipefail

# Verify an already signed/notarized release directory and upload its exact
# public files to a new draft GitHub Release. In explicit finalization mode it
# requires a release-bound, content-free clean-machine acceptance record, then
# re-runs every gate and publishes that exact draft. This script never receives
# or exports signing credentials.

umask 022
export GIT_NO_REPLACE_OBJECTS=1

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
TAG=""
RELEASE_DIR=""
NOTES_FILE=""
ACCEPTANCE_FILE=""
REPOSITORY=""
TITLE=""
EXPECTED_TEAM_ID="${DEVELOPER_TEAM_ID:-}"
FINALIZE_EXISTING=0

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/publish-github-release.sh \
    --tag v1.2.0-beta.2 \
    --team-id TEAMID1234 \
    --release-dir ./dist/Activity-Radar-1.2.0-beta.2-macOS-universal2 \
    --notes-file /absolute/path/to/release-notes.md \
    [--repo owner/repository] [--title "Release title"] \
    [--finalize-existing-draft \
      --acceptance-file /absolute/path/to/Activity-Radar-1.2.0-beta.2-CLEAN-MACHINE-ACCEPTANCE.json]

The command re-verifies the exact tag, source commit, successful CI, app/DMG
signatures, stapled tickets, Gatekeeper assessments, ZIP/DMG integrity, and
SHA256SUMS before creating a draft release. Finalization is a separate explicit
mode that requires a content-free clean-machine acceptance record, re-verifies
the same local snapshot and remote draft, uploads that record as the fifth
asset, and only then publishes.
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

require_exact_repository_identity() {
  local expected_gate name_gate id_gate
  expected_gate="${REPOSITORY_ID}"$'\t'"${REPOSITORY}"
  name_gate="$(gh api "repos/$REPOSITORY" --jq '[.id, .full_name] | @tsv')"
  id_gate="$(gh api "repositories/$REPOSITORY_ID" --jq '[.id, .full_name] | @tsv')"
  [[ "$name_gate" == "$expected_gate" && "$id_gate" == "$expected_gate" ]] \
    || fail "GitHub repository identity changed during release verification"
}

require_exact_source_checkout() {
  require_exact_repository_identity
  [[ "$(git rev-parse HEAD)" == "$SOURCE_REVISION" ]] \
    || fail "Release source checkout changed during verification"
  [[ "$(git rev-parse -q --verify "refs/tags/${TAG}^{commit}" 2>/dev/null || true)" == "$SOURCE_REVISION" ]] \
    || fail "Local release tag changed during verification"
  [[ -z "$(git status --porcelain --untracked-files=all)" ]] \
    || fail "Release source worktree changed during verification"
  [[ "$(git remote get-url origin 2>/dev/null || true)" == "$ORIGIN_URL" ]] \
    || fail "Git origin URL changed during release verification"
  [[ "$(gh repo view "$ORIGIN_URL" --json nameWithOwner --jq .nameWithOwner)" == "$REPOSITORY" ]] \
    || fail "Git origin no longer resolves to the verified GitHub repository"
}

remote_tag_revision() {
  local object_gate object_type object_sha depth
  require_exact_repository_identity
  object_gate="$(gh api "repos/$REPOSITORY/git/ref/tags/$TAG" --jq '[.object.type, .object.sha] | @tsv')"
  object_type="$(print -r -- "$object_gate" | awk -F '\t' '{print $1}')"
  object_sha="$(print -r -- "$object_gate" | awk -F '\t' '{print $2}')"
  for depth in {1..8}; do
    if [[ "$object_type" == "commit" ]]; then
      print -r -- "$object_sha"
      return 0
    fi
    [[ "$object_type" == "tag" ]] || return 1
    object_gate="$(gh api "repos/$REPOSITORY/git/tags/$object_sha" --jq '[.object.type, .object.sha] | @tsv')"
    object_type="$(print -r -- "$object_gate" | awk -F '\t' '{print $1}')"
    object_sha="$(print -r -- "$object_gate" | awk -F '\t' '{print $2}')"
  done
  return 1
}

release_id_for_tag() {
  require_exact_repository_identity
  gh release view "$TAG" \
    --repo "$REPOSITORY" \
    --json databaseId \
    --jq .databaseId
}

require_remote_asset_names() {
  local include_acceptance="$1"
  local expected_names actual_names
  expected_names="$(
    print -r -- "$ZIP_NAME"
    print -r -- "$DMG_NAME"
    print -r -- "SHA256SUMS"
    print -r -- "RELEASE-MANIFEST.txt"
    if (( include_acceptance )); then
      print -r -- "$ACCEPTANCE_NAME"
    fi
  )"
  expected_names="$(print -r -- "$expected_names" | LC_ALL=C sort)"
  actual_names="$(
    gh api "repos/$REPOSITORY/releases/$REMOTE_RELEASE_ID" \
      --jq '.assets[].name' \
      | LC_ALL=C sort
  )"
  [[ "$actual_names" == "$expected_names" ]] \
    || fail "GitHub Release asset names do not match the exact public set"
}

require_remote_asset_digest() {
  local asset_name="$1"
  local expected_digest="$2"
  local remote_digest
  remote_digest="$(
    gh api "repos/$REPOSITORY/releases/$REMOTE_RELEASE_ID" \
      --jq ".assets[] | select(.name == \"$asset_name\") | .digest"
  )"
  [[ "$remote_digest" == "$expected_digest" ]] \
    || fail "GitHub asset digest mismatch: $asset_name"
}

require_remote_core_asset_digests() {
  require_remote_asset_digest "$ZIP_NAME" "$VERIFIED_ZIP_DIGEST"
  require_remote_asset_digest "$DMG_NAME" "$VERIFIED_DMG_DIGEST"
  require_remote_asset_digest "SHA256SUMS" "$VERIFIED_CHECKSUMS_DIGEST"
  require_remote_asset_digest "RELEASE-MANIFEST.txt" "$VERIFIED_MANIFEST_DIGEST"
}

fail_acceptance_asset_recovery() {
  local reason="$1"
  print -u2 -- "ERROR: $reason"
  if (( ${ALREADY_PUBLISHED:-0} )); then
    print -u2 -- "The release is already immutable; do not try to replace or delete an asset. Publish a corrected new tag."
  else
    print -u2 -- "The draft was not published. First rerun the same finalization command; it accepts only the exact verified digest."
    print -u2 -- "If the retry reports the same incomplete or mismatched asset, inspect draft release ID $REMOTE_RELEASE_ID,"
    print -u2 -- "confirm that it is still a draft for $TAG, then manually delete only $ACCEPTANCE_NAME and rerun."
    print -u2 -- "Never use --clobber. This publisher does not delete release assets automatically."
  fi
  exit 1
}

require_remote_acceptance_asset() {
  local asset_gate asset_state asset_size asset_digest
  asset_gate="$(
    gh api "repos/$REPOSITORY/releases/$REMOTE_RELEASE_ID" \
      --jq ".assets[] | select(.name == \"$ACCEPTANCE_NAME\") | [.state, (.size | tostring), (.digest // \"\")] | @tsv"
  )"
  asset_state="$(print -r -- "$asset_gate" | awk -F '\t' '{print $1}')"
  asset_size="$(print -r -- "$asset_gate" | awk -F '\t' '{print $2}')"
  asset_digest="$(print -r -- "$asset_gate" | awk -F '\t' '{print $3}')"
  [[ "$asset_state" == "uploaded" ]] \
    || fail_acceptance_asset_recovery "Clean-machine acceptance asset is missing or incomplete (state: ${asset_state:-unavailable})"
  [[ "$asset_size" == "$VERIFIED_ACCEPTANCE_SIZE" ]] \
    || fail_acceptance_asset_recovery "Clean-machine acceptance asset size does not match the frozen local record"
  [[ "$asset_digest" == "$VERIFIED_ACCEPTANCE_DIGEST" ]] \
    || fail_acceptance_asset_recovery "Clean-machine acceptance asset digest does not match the frozen local record"
}

require_frozen_release_notes() {
  [[ "sha256:$(shasum -a 256 "$NOTES_FILE" | awk '{print $1}')" == "$VERIFIED_NOTES_DIGEST" ]] \
    || fail "Frozen release notes changed during verification"
  [[ "$(<"$NOTES_FILE")" == "$EXPECTED_RELEASE_BODY" ]] \
    || fail "Frozen release-notes body changed during verification"
}

verify_public_metadata_policy() {
  local root="$1"
  local label="$2"
  local node flags acl_entry attrs attr_name
  while IFS= read -r -d '' node; do
    flags="$(stat -f %Sf "$node")"
    [[ "$flags" == "-" ]] || fail "$label contains unexpected file flags"
    acl_entry="$(ls -lde "$node" | sed -n '2p')"
    [[ -z "$acl_entry" ]] || fail "$label contains an ACL"
    if [[ -L "$node" ]]; then
      if ! attrs="$(xattr -s "$node" 2>/dev/null)"; then
        fail "$label symbolic-link attributes could not be inspected"
      fi
    elif ! attrs="$(xattr "$node" 2>/dev/null)"; then
      fail "$label extended attributes could not be inspected"
    fi
    while IFS= read -r attr_name; do
      [[ -z "$attr_name" ]] && continue
      [[ "$attr_name" == "com.apple.provenance" ]] \
        || fail "$label contains an unexpected extended attribute"
      [[ -n "$EXPECTED_PROVENANCE_HEX" ]] \
        || fail "$label unexpectedly contains provenance metadata"
      local actual_provenance_hex
      if [[ -L "$node" ]]; then
        actual_provenance_hex="$(xattr -px -s com.apple.provenance "$node" | tr -d '[:space:]')"
      else
        actual_provenance_hex="$(xattr -px com.apple.provenance "$node" | tr -d '[:space:]')"
      fi
      [[ "$actual_provenance_hex" == "$EXPECTED_PROVENANCE_HEX" ]] \
        || fail "$label provenance metadata differs from the local system value"
    done <<< "$attrs"
  done < <(find "$root" -print0)
}

bundle_mode_inventory() {
  local app="$1"
  local relative_path
  (
    cd "$app"
    find . -print | LC_ALL=C sort | while IFS= read -r relative_path; do
      print -r -- "$(stat -f '%Sp|%Sf' "$relative_path")|$relative_path"
    done
  )
}

code_directory_hashes() {
  local app="$1"
  local binary_arch details cdhash
  for binary_arch in arm64 x86_64; do
    details="$(codesign -d --arch "$binary_arch" --verbose=4 "$app" 2>&1)"
    cdhash="$(print -r -- "$details" | sed -n 's/^CDHash=//p' | sed -n '1p')"
    print -r -- "$cdhash" | grep -Eqi '^[0-9a-f]{40,64}$' \
      || fail "Could not read the $binary_arch CodeDirectory hash"
    print -r -- "$binary_arch:$cdhash"
  done
}

verify_release_app() {
  local app="$1"
  local label="$2"
  [[ -d "$app" && -x "$app/Contents/MacOS/ActivityRadar" ]] || fail "$label is missing its executable"
  [[ -z "$(find "$app" -type l -print -quit)" ]] || fail "$label contains a symbolic link"
  verify_public_metadata_policy "$app" "$label"
  swift scripts/dmg-topology-check.swift bundle "$app" \
    || fail "$label contains a missing or unexpected bundle entry"
  [[ "$(plutil -extract CFBundleIdentifier raw -o - "$app/Contents/Info.plist")" == "$BUNDLE_IDENTIFIER" ]] \
    || fail "$label bundle identifier mismatch"
  [[ "$(plutil -extract CFBundleShortVersionString raw -o - "$app/Contents/Info.plist")" == "$VERSION" ]] \
    || fail "$label version mismatch"
  [[ "$(plutil -extract CFBundleVersion raw -o - "$app/Contents/Info.plist")" == "$BUILD_NUMBER" ]] \
    || fail "$label build number mismatch"
  [[ "$(plutil -extract LSMinimumSystemVersion raw -o - "$app/Contents/Info.plist")" == "$MIN_MACOS" ]] \
    || fail "$label minimum macOS mismatch"
  [[ "$(plutil -extract CFBundleExecutable raw -o - "$app/Contents/Info.plist")" == "ActivityRadar" ]] \
    || fail "$label executable name mismatch"
  [[ "$(plutil -extract ActivityRadarSourceRevision raw -o - "$app/Contents/Info.plist")" == "$SOURCE_REVISION" ]] \
    || fail "$label signed source revision mismatch"
  [[ "$(plutil -extract ActivityRadarReleaseTag raw -o - "$app/Contents/Info.plist")" == "$TAG" ]] \
    || fail "$label signed release tag mismatch"
  [[ "$(plutil -convert xml1 -o - "$app/Contents/Info.plist")" == "$EXPECTED_INFO_PLIST_XML" ]] \
    || fail "$label Info.plist differs from the tagged release metadata"

  lipo "$app/Contents/MacOS/ActivityRadar" -verify_arch arm64 x86_64
  [[ "$(lipo -archs "$app/Contents/MacOS/ActivityRadar" | awk '{print NF}')" == "2" ]] \
    || fail "$label contains unexpected executable architectures"
  local binary_arch binary_minos
  for binary_arch in arm64 x86_64; do
    binary_minos="$(
      vtool -arch "$binary_arch" -show-build "$app/Contents/MacOS/ActivityRadar" \
        | awk '/^[[:space:]]*minos / {print $2; exit}'
    )"
    [[ "$binary_minos" == "$MIN_MACOS" ]] \
      || fail "$label $binary_arch deployment target is $binary_minos, expected $MIN_MACOS"
  done

  codesign --verify --deep --strict --verbose=2 "$app"
  local signature
  signature="$(codesign -d --verbose=4 "$app" 2>&1)"
  print -r -- "$signature" | grep -Fq "Authority=Developer ID Application:" \
    || fail "$label is not signed with Developer ID Application"
  print -r -- "$signature" | grep -Fxq "TeamIdentifier=$EXPECTED_TEAM_ID" \
    || fail "$label signature has the wrong Apple Team ID"
  print -r -- "$signature" | grep -Fxq "Identifier=$BUNDLE_IDENTIFIER" \
    || fail "$label signature has the wrong bundle identifier"
  print -r -- "$signature" | grep -Fq 'runtime' \
    || fail "$label signature does not enable hardened runtime"
  print -r -- "$signature" | grep -Eq '^Timestamp=' \
    || fail "$label signature has no secure timestamp"
  local embedded_entitlements canonical_entitlements
  embedded_entitlements="$(codesign -d --entitlements :- "$app" 2>&1 | sed -n '/<?xml/,$p')"
  [[ -n "$embedded_entitlements" ]] || fail "$label embedded entitlements are unreadable"
  canonical_entitlements="$(print -r -- "$embedded_entitlements" | plutil -convert xml1 -o - -)"
  [[ "$canonical_entitlements" == "$EXPECTED_ENTITLEMENTS_XML" ]] \
    || fail "$label embedded entitlements differ from the tagged entitlement set"
  xcrun stapler validate -v "$app"
  spctl --assess --type execute --verbose=4 "$app"
}

while (( $# > 0 )); do
  case "$1" in
    --tag)
      (( $# >= 2 )) || fail "--tag requires a value"
      TAG="$2"
      shift 2
      ;;
    --team-id)
      (( $# >= 2 )) || fail "--team-id requires a value"
      EXPECTED_TEAM_ID="$2"
      shift 2
      ;;
    --release-dir)
      (( $# >= 2 )) || fail "--release-dir requires a path"
      RELEASE_DIR="$2"
      shift 2
      ;;
    --notes-file)
      (( $# >= 2 )) || fail "--notes-file requires a path"
      NOTES_FILE="$2"
      shift 2
      ;;
    --acceptance-file)
      (( $# >= 2 )) || fail "--acceptance-file requires a path"
      ACCEPTANCE_FILE="$2"
      shift 2
      ;;
    --repo)
      (( $# >= 2 )) || fail "--repo requires owner/repository"
      REPOSITORY="$2"
      shift 2
      ;;
    --title)
      (( $# >= 2 )) || fail "--title requires a value"
      TITLE="$2"
      shift 2
      ;;
    --finalize-existing-draft)
      FINALIZE_EXISTING=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "Unknown argument: $1"
      ;;
  esac
done

[[ -n "$TAG" ]] || fail "--tag is required"
[[ -n "$EXPECTED_TEAM_ID" ]] || fail "--team-id is required"
[[ -n "$RELEASE_DIR" ]] || fail "--release-dir is required"
[[ -n "$NOTES_FILE" ]] || fail "--notes-file is required"
if (( FINALIZE_EXISTING )); then
  [[ -n "$ACCEPTANCE_FILE" ]] \
    || fail "Finalization requires --acceptance-file"
elif [[ -n "$ACCEPTANCE_FILE" ]]; then
  fail "--acceptance-file is valid only with --finalize-existing-draft"
fi
[[ "$TAG" == v* ]] || fail "Release tag must begin with v"
print -r -- "$TAG" | grep -Eq '^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?$' \
  || fail "Unsafe release tag: $TAG"
print -r -- "$EXPECTED_TEAM_ID" | grep -Eq '^[A-Z0-9]{10}$' \
  || fail "Apple Team ID must be 10 uppercase letters or digits"
if [[ -n "$REPOSITORY" ]]; then
  print -r -- "$REPOSITORY" | grep -Eq '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$' \
    || fail "Unsafe GitHub repository name: $REPOSITORY"
fi

for tool in git gh rg plutil shasum unzip ditto codesign lipo vtool hdiutil diskutil spctl xcrun mktemp grep sed awk wc tr rm find diff readlink stat sort uniq swift zip cmp xattr ls date; do
  need_tool "$tool"
done
xcrun --find stapler >/dev/null 2>&1 || fail "stapler is unavailable"

cd "$PROJECT_DIR"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
[[ -n "$REPO_ROOT" && "${REPO_ROOT:A}" == "$PROJECT_DIR" ]] || fail "Run from the root of the public Git checkout"
[[ -z "$(git for-each-ref --format='%(refname)' refs/replace | sed -n '1p')" ]] \
  || fail "Release publication refuses a checkout with Git replacement refs"
[[ -z "$(git status --porcelain --untracked-files=all)" ]] || fail "Draft publication requires a clean Git worktree"

VERSION="$(plutil -extract CFBundleShortVersionString raw -o - Packaging/Info.plist)"
BUILD_NUMBER="$(plutil -extract CFBundleVersion raw -o - Packaging/Info.plist)"
BUNDLE_IDENTIFIER="$(plutil -extract CFBundleIdentifier raw -o - Packaging/Info.plist)"
MIN_MACOS="$(plutil -extract LSMinimumSystemVersion raw -o - Packaging/Info.plist)"
RELEASE_LABEL="${TAG#v}"
[[ "$RELEASE_LABEL" == "$VERSION" || "$RELEASE_LABEL" == "$VERSION"-* ]] \
  || fail "Release tag $TAG does not match app version $VERSION"

SOURCE_REVISION="$(git rev-parse HEAD)"
TAG_REVISION="$(git rev-parse -q --verify "refs/tags/${TAG}^{commit}" 2>/dev/null || true)"
[[ -n "$TAG_REVISION" && "$TAG_REVISION" == "$SOURCE_REVISION" ]] \
  || fail "Local release tag must point exactly at HEAD"
UNSAFE_TREE_ENTRY="$(
  git ls-tree -r "$SOURCE_REVISION" \
    | awk '$1 == "120000" || $1 == "160000" { print "unsafe"; exit }'
)"
[[ -z "$UNSAFE_TREE_ENTRY" ]] || fail "Release source tree contains a symlink or submodule"

gh auth status >/dev/null 2>&1 || fail "GitHub CLI is not authenticated"
ORIGIN_URL="$(git remote get-url origin 2>/dev/null || true)"
[[ -n "$ORIGIN_URL" ]] || fail "Git origin remote is unavailable"
ORIGIN_REPOSITORY="$(gh repo view "$ORIGIN_URL" --json nameWithOwner --jq .nameWithOwner)"
if [[ -z "$REPOSITORY" ]]; then
  REPOSITORY="$ORIGIN_REPOSITORY"
fi
[[ "$REPOSITORY" == "$ORIGIN_REPOSITORY" ]] \
  || fail "--repo must match the checkout's origin repository"
REPOSITORY_GATE="$(gh api "repos/$REPOSITORY" --jq '[.id, .full_name] | @tsv')"
REPOSITORY_ID="$(print -r -- "$REPOSITORY_GATE" | awk -F '\t' '{print $1}')"
REPOSITORY_FULL_NAME="$(print -r -- "$REPOSITORY_GATE" | awk -F '\t' '{print $2}')"
print -r -- "$REPOSITORY_ID" | grep -Eq '^[0-9]+$' \
  || fail "GitHub repository ID is unavailable"
[[ "$REPOSITORY_FULL_NAME" == "$REPOSITORY" ]] \
  || fail "GitHub repository name is not canonical"
require_exact_repository_identity

DEFAULT_BRANCH="$(gh repo view "$REPOSITORY" --json defaultBranchRef --jq .defaultBranchRef.name)"
print -r -- "$DEFAULT_BRANCH" | grep -Eq '^[A-Za-z0-9._/-]+$' \
  || fail "GitHub default branch name is unsafe or unavailable"
[[ "$DEFAULT_BRANCH" != -* && "$DEFAULT_BRANCH" != *..* ]] \
  || fail "GitHub default branch name is unsafe"
DEFAULT_BRANCH_GATE="$(
  gh api "repos/$REPOSITORY/branches/$DEFAULT_BRANCH" \
    --jq '[.protected, .commit.sha] | @tsv'
)"
DEFAULT_BRANCH_PROTECTED="$(print -r -- "$DEFAULT_BRANCH_GATE" | awk -F '\t' '{print $1}')"
API_DEFAULT_REVISION="$(print -r -- "$DEFAULT_BRANCH_GATE" | awk -F '\t' '{print $2}')"
[[ "$DEFAULT_BRANCH_PROTECTED" == "true" ]] \
  || fail "GitHub default branch is not protected"
print -r -- "$API_DEFAULT_REVISION" | grep -Eq '^[0-9a-f]{40}$' \
  || fail "GitHub default branch revision is invalid"
[[ "$(gh api "repos/$REPOSITORY/immutable-releases" --jq .enabled)" == "true" ]] \
  || fail "GitHub immutable releases are not enabled"

BRANCH_REF="refs/heads/$DEFAULT_BRANCH"
BRANCH_RULESET_OK=0
for ruleset_id in $(gh api "repos/$REPOSITORY/rulesets" --jq '.[] | select(.target == "branch" and .enforcement == "active") | .id'); do
  if [[ "$(gh api "repos/$REPOSITORY/rulesets/$ruleset_id" --jq "
    (.target == \"branch\") and
    (.enforcement == \"active\") and
    ((.bypass_actors | type) == \"array\") and
    ((.bypass_actors | length) == 0) and
    (((.conditions.ref_name.include | index(\"$BRANCH_REF\")) != null) or
      ((.conditions.ref_name.include | index(\"~DEFAULT_BRANCH\")) != null)) and
    ((.conditions.ref_name.exclude | length) == 0) and
    (([.rules[].type] | index(\"deletion\")) != null) and
    (([.rules[].type] | index(\"non_fast_forward\")) != null) and
    (any(.rules[]; .type == \"pull_request\" and
      (.parameters.required_review_thread_resolution == true))) and
    (any(.rules[]; .type == \"required_status_checks\" and
      (.parameters.strict_required_status_checks_policy == true) and
      (([.parameters.required_status_checks[].context] | index(\"macOS verification\")) != null) and
      (([.parameters.required_status_checks[].context] | index(\"Intel runtime\")) != null))
  ")" == "true" ]]; then
    BRANCH_RULESET_OK=1
    break
  fi
done
(( BRANCH_RULESET_OK == 1 )) \
  || fail "No bypass-free active ruleset fully protects the default branch and both required CI checks"

TAG_RULESET_OK=0
for ruleset_id in $(gh api "repos/$REPOSITORY/rulesets" --jq '.[] | select(.target == "tag" and .enforcement == "active") | .id'); do
  if [[ "$(gh api "repos/$REPOSITORY/rulesets/$ruleset_id" --jq '
    (.target == "tag") and
    (.enforcement == "active") and
    ((.bypass_actors | type) == "array") and
    ((.bypass_actors | length) == 0) and
    ((.conditions.ref_name.include | index("refs/tags/v*")) != null) and
    ((.conditions.ref_name.exclude | length) == 0) and
    (([.rules[].type] | index("update")) != null) and
    (([.rules[].type] | index("deletion")) != null) and
    (([.rules[].type] | index("non_fast_forward")) != null)
  ')" == "true" ]]; then
    TAG_RULESET_OK=1
    break
  fi
done
(( TAG_RULESET_OK == 1 )) || fail "No bypass-free active ruleset protects refs/tags/v*"

DEFAULT_BRANCH_ANCESTRY="$(
  gh api "repos/$REPOSITORY/compare/$SOURCE_REVISION...$API_DEFAULT_REVISION" \
    --jq '[.status, .base_commit.sha, .merge_base_commit.sha] | @tsv'
)"
if [[ "$DEFAULT_BRANCH_ANCESTRY" != "ahead"$'\t'"$SOURCE_REVISION"$'\t'"$SOURCE_REVISION" \
  && "$DEFAULT_BRANCH_ANCESTRY" != "identical"$'\t'"$SOURCE_REVISION"$'\t'"$SOURCE_REVISION" ]]; then
  fail "Release commit is not an ancestor of the canonical GitHub default branch"
fi

REMOTE_REVISION="$(remote_tag_revision)"
[[ -n "$REMOTE_REVISION" && "$REMOTE_REVISION" == "$SOURCE_REVISION" ]] \
  || fail "Remote release tag does not resolve to the local source revision"

CI_RUN_ID="$(
  gh api --method GET "repos/$REPOSITORY/actions/workflows/ci.yml/runs" \
    -f head_sha="$SOURCE_REVISION" \
    -f branch="$DEFAULT_BRANCH" \
    -f event=push \
    -f status=success \
    -f per_page=20 \
    --jq '.workflow_runs[0].id // empty'
)"
[[ -n "$CI_RUN_ID" ]] || fail "No successful default-branch push CI run was found for the release commit"
CI_RUN_GATE="$(
  gh api "repos/$REPOSITORY/actions/runs/$CI_RUN_ID" \
    --jq '[.head_sha, .event, .head_branch, .path, .status, .conclusion] | @tsv'
)"
EXPECTED_CI_RUN_GATE="${SOURCE_REVISION}"$'\t'"push"$'\t'"${DEFAULT_BRANCH}"$'\t'".github/workflows/ci.yml"$'\t'"completed"$'\t'"success"
[[ "$CI_RUN_GATE" == "$EXPECTED_CI_RUN_GATE" ]] \
  || fail "The selected CI run does not exactly match the release commit and default-branch push"

CI_JOB_ROWS="$(
  gh api --method GET "repos/$REPOSITORY/actions/runs/$CI_RUN_ID/jobs" \
    -f filter=latest \
    -f per_page=100 \
    --jq '.jobs[] | [.name, .head_sha, .status, .conclusion] | @tsv'
)"
for required_job in "macOS verification" "Intel runtime"; do
  REQUIRED_JOB_COUNT="$(
    print -r -- "$CI_JOB_ROWS" | awk -F '\t' \
      -v expected_name="$required_job" \
      -v expected_sha="$SOURCE_REVISION" '
        $1 == expected_name && $2 == expected_sha && $3 == "completed" && $4 == "success" { count += 1 }
        END { print count + 0 }
      '
  )"
  [[ "$REQUIRED_JOB_COUNT" == "1" ]] \
    || fail "Required CI job did not succeed exactly once for the release commit: $required_job"
done

RELEASE_DIR="${RELEASE_DIR:A}"
EXPECTED_DIR_NAME="Activity-Radar-${RELEASE_LABEL}-macOS-universal2"
[[ -d "$RELEASE_DIR" && "${RELEASE_DIR:t}" == "$EXPECTED_DIR_NAME" ]] \
  || fail "Release directory name does not match tag: $EXPECTED_DIR_NAME"
NOTES_FILE="${NOTES_FILE:A}"
[[ -f "$NOTES_FILE" && -s "$NOTES_FILE" && ! -L "$NOTES_FILE" ]] \
  || fail "Release notes file is missing, empty, or is a symlink"
[[ -n "$TITLE" ]] || TITLE="Activity Radar $TAG"

ZIP_NAME="$EXPECTED_DIR_NAME.zip"
DMG_NAME="$EXPECTED_DIR_NAME.dmg"
ACCEPTANCE_NAME="Activity-Radar-${RELEASE_LABEL}-CLEAN-MACHINE-ACCEPTANCE.json"
if (( FINALIZE_EXISTING )); then
  ACCEPTANCE_FILE="${ACCEPTANCE_FILE:A}"
  [[ -f "$ACCEPTANCE_FILE" && -s "$ACCEPTANCE_FILE" && ! -L "$ACCEPTANCE_FILE" ]] \
    || fail "Clean-machine acceptance file is missing, empty, or is a symlink"
  [[ "${ACCEPTANCE_FILE:t}" == "$ACCEPTANCE_NAME" ]] \
    || fail "Clean-machine acceptance file must be named $ACCEPTANCE_NAME"
  (( $(stat -f %z "$ACCEPTANCE_FILE") <= 65536 )) \
    || fail "Clean-machine acceptance file exceeds 64 KiB"
fi
ORIGINAL_APP="$RELEASE_DIR/Activity Radar.app"
ORIGINAL_ZIP="$RELEASE_DIR/$ZIP_NAME"
ORIGINAL_DMG="$RELEASE_DIR/$DMG_NAME"
ORIGINAL_CHECKSUMS="$RELEASE_DIR/SHA256SUMS"
ORIGINAL_MANIFEST="$RELEASE_DIR/RELEASE-MANIFEST.txt"

[[ -d "$ORIGINAL_APP" && ! -L "$ORIGINAL_APP" ]] || fail "Release app is missing or is a symlink"
for release_file in "$ORIGINAL_ZIP" "$ORIGINAL_DMG" "$ORIGINAL_CHECKSUMS" "$ORIGINAL_MANIFEST"; do
  [[ -f "$release_file" && ! -L "$release_file" ]] || fail "Release file is missing or is a symlink: ${release_file:t}"
done

VERIFY_ROOT="$(mktemp -d /tmp/activity-radar-release-publish.XXXXXX)"
[[ "$VERIFY_ROOT" == /tmp/activity-radar-release-publish.* ]] \
  || fail "Unexpected verification directory"
PROVENANCE_SENTINEL="$VERIFY_ROOT/provenance-sentinel"
touch "$PROVENANCE_SENTINEL"
EXPECTED_PROVENANCE_HEX="$(xattr -px com.apple.provenance "$PROVENANCE_SENTINEL" 2>/dev/null | tr -d '[:space:]' || true)"
DMG_ATTACHED=0
DMG_DEVICE=""
DMG_MOUNT="$VERIFY_ROOT/dmg-mount"
cleanup() {
  if (( ${DMG_ATTACHED:-0} )); then
    hdiutil detach "$DMG_DEVICE" >/dev/null 2>&1 || true
  fi
  if [[ -n "${VERIFY_ROOT:-}" && "$VERIFY_ROOT" == /tmp/activity-radar-release-publish.* && -d "$VERIFY_ROOT" ]]; then
    chmod -R u+w "$VERIFY_ROOT" >/dev/null 2>&1 || true
    rm -rf -- "$VERIFY_ROOT"
  fi
}
trap cleanup EXIT INT TERM

note "Freezing release artifacts and notes into a private verification snapshot"
SNAPSHOT_DIR="$VERIFY_ROOT/snapshot"
mkdir -p "$SNAPSHOT_DIR"
chmod 700 "$VERIFY_ROOT" "$SNAPSHOT_DIR"
ditto --rsrc --extattr "$ORIGINAL_APP" "$SNAPSHOT_DIR/Activity Radar.app"
ditto --noqtn --noextattr --norsrc "$ORIGINAL_ZIP" "$SNAPSHOT_DIR/$ZIP_NAME"
ditto --noqtn --noextattr --norsrc "$ORIGINAL_DMG" "$SNAPSHOT_DIR/$DMG_NAME"
ditto --noqtn --noextattr --norsrc "$ORIGINAL_CHECKSUMS" "$SNAPSHOT_DIR/SHA256SUMS"
ditto --noqtn --noextattr --norsrc "$ORIGINAL_MANIFEST" "$SNAPSHOT_DIR/RELEASE-MANIFEST.txt"
ditto --noqtn --noextattr --norsrc "$NOTES_FILE" "$SNAPSHOT_DIR/release-notes.md"
if (( FINALIZE_EXISTING )); then
  ditto --noqtn --noextattr --norsrc "$ACCEPTANCE_FILE" "$SNAPSHOT_DIR/$ACCEPTANCE_NAME"
fi
print -rn -- "$TITLE" > "$SNAPSHOT_DIR/release-title.txt"
CANONICAL_ZIP="$VERIFY_ROOT/canonical-$ZIP_NAME"
(
  cd "$SNAPSHOT_DIR"
  /usr/bin/zip -X -q -r "$CANONICAL_ZIP" "Activity Radar.app"
)
cmp -s "$CANONICAL_ZIP" "$SNAPSHOT_DIR/$ZIP_NAME" \
  || fail "Release ZIP is not the canonical metadata-free archive of the frozen app"

RELEASE_DIR="$SNAPSHOT_DIR"
APP="$SNAPSHOT_DIR/Activity Radar.app"
ZIP="$SNAPSHOT_DIR/$ZIP_NAME"
DMG="$SNAPSHOT_DIR/$DMG_NAME"
CHECKSUMS="$SNAPSHOT_DIR/SHA256SUMS"
MANIFEST="$SNAPSHOT_DIR/RELEASE-MANIFEST.txt"
NOTES_FILE="$SNAPSHOT_DIR/release-notes.md"
ACCEPTANCE=""
if (( FINALIZE_EXISTING )); then
  ACCEPTANCE="$SNAPSHOT_DIR/$ACCEPTANCE_NAME"
fi
swift scripts/release-notes-check.swift \
  "$NOTES_FILE" \
  "$REPOSITORY" \
  "$TAG" \
  "$ZIP_NAME" \
  "$DMG_NAME" \
  "$ACCEPTANCE_NAME" \
  || fail "Frozen release notes do not satisfy the installable-public-beta contract"
EXPECTED_RELEASE_BODY="$(<"$NOTES_FILE")"
VERIFIED_NOTES_DIGEST="sha256:$(shasum -a 256 "$NOTES_FILE" | awk '{print $1}')"
chmod a-w "$NOTES_FILE"
require_frozen_release_notes

EXPECTED_INFO_PLIST="$VERIFY_ROOT/expected-info.plist"
EXPECTED_ENTITLEMENTS="$VERIFY_ROOT/expected-entitlements.plist"
git show "$SOURCE_REVISION:Packaging/Info.plist" > "$EXPECTED_INFO_PLIST"
git show "$SOURCE_REVISION:Packaging/ActivityRadar.entitlements" > "$EXPECTED_ENTITLEMENTS"
plutil -replace CFBundleIdentifier -string "$BUNDLE_IDENTIFIER" "$EXPECTED_INFO_PLIST"
plutil -insert ActivityRadarSourceRevision -string "$SOURCE_REVISION" "$EXPECTED_INFO_PLIST"
plutil -insert ActivityRadarReleaseTag -string "$TAG" "$EXPECTED_INFO_PLIST"
EXPECTED_INFO_PLIST_XML="$(plutil -convert xml1 -o - "$EXPECTED_INFO_PLIST")"
EXPECTED_ENTITLEMENTS_XML="$(plutil -convert xml1 -o - "$EXPECTED_ENTITLEMENTS")"

EXPECTED_CHECKSUMS="$(
  cd "$RELEASE_DIR"
  shasum -a 256 "$ZIP_NAME" "$DMG_NAME" RELEASE-MANIFEST.txt
)"
ACTUAL_CHECKSUMS="$(<"$CHECKSUMS")"
[[ "$ACTUAL_CHECKSUMS" == "$EXPECTED_CHECKSUMS" ]] \
  || fail "SHA256SUMS is not the canonical ZIP, DMG, and manifest checksum set"
(
  cd "$RELEASE_DIR"
  shasum -a 256 -c SHA256SUMS
)

[[ "$(wc -l < "$MANIFEST" | tr -d '[:space:]')" == "17" ]] \
  || fail "Release manifest does not have the exact expected schema"
for manifest_key in \
  Product Version Build "Release tag" "Source revision" "Source state" \
  "Bundle identifier" Architectures "Minimum macOS" SDK "Swift toolchain" \
  "Build host architecture" "Build epoch" Signing \
  "Application notarization" "Disk image notarization" Artifacts; do
  [[ "$(grep -c "^${manifest_key}: " "$MANIFEST")" == "1" ]] \
    || fail "Release manifest field is missing or duplicated: $manifest_key"
done
grep -Fxq "Product: Activity Radar" "$MANIFEST" || fail "Manifest product mismatch"
grep -Fxq "Release tag: $TAG" "$MANIFEST" || fail "Manifest release tag mismatch"
grep -Fxq "Source revision: $SOURCE_REVISION" "$MANIFEST" || fail "Manifest source revision mismatch"
grep -Fxq "Source state: clean exact-tag checkout" "$MANIFEST" || fail "Manifest source state mismatch"
grep -Fxq "Version: $VERSION" "$MANIFEST" || fail "Manifest version mismatch"
grep -Fxq "Build: $BUILD_NUMBER" "$MANIFEST" || fail "Manifest build mismatch"
grep -Fxq "Bundle identifier: $BUNDLE_IDENTIFIER" "$MANIFEST" || fail "Manifest bundle identifier mismatch"
grep -Fxq "Architectures: arm64 x86_64" "$MANIFEST" || fail "Manifest architecture mismatch"
grep -Fxq "Minimum macOS: $MIN_MACOS" "$MANIFEST" || fail "Manifest deployment target mismatch"
grep -Eq '^SDK: macOS [0-9]+\.[0-9]+(\.[0-9]+)?$' "$MANIFEST" || fail "Manifest SDK value is invalid"
grep -Eq '^Swift toolchain: .+$' "$MANIFEST" || fail "Manifest Swift toolchain is missing"
grep -Eq '^Build host architecture: (arm64|x86_64)$' "$MANIFEST" || fail "Manifest build-host architecture is invalid"
grep -Eq '^Build epoch: [0-9]+$' "$MANIFEST" || fail "Manifest build epoch is invalid"
grep -Fxq "Signing: Developer ID Application, Apple Team $EXPECTED_TEAM_ID, hardened runtime, secure timestamp" "$MANIFEST" \
  || fail "Manifest signing identity mismatch"
grep -Fxq "Application notarization: Accepted, zero reported issues, stapled" "$MANIFEST" \
  || fail "Manifest does not record accepted app notarization"
grep -Fxq "Disk image notarization: Accepted, zero reported issues, stapled" "$MANIFEST" \
  || fail "Manifest does not record accepted DMG notarization"
grep -Fxq "Artifacts: $ZIP_NAME, $DMG_NAME" "$MANIFEST" || fail "Manifest artifact list mismatch"

note "Re-verifying delivered signatures and tickets"
verify_release_app "$APP" "Loose release app"
REFERENCE_CDHASHES="$(code_directory_hashes "$APP")"
REFERENCE_MODE_INVENTORY="$(bundle_mode_inventory "$APP")"

unzip -tq "$ZIP"
ZIP_ENTRIES="$(unzip -Z1 "$ZIP")"
[[ -n "$ZIP_ENTRIES" ]] || fail "ZIP central directory is empty"
ZIP_UNSAFE_ENTRY="$(
  print -r -- "$ZIP_ENTRIES" | awk '
    index($0, "\\") > 0 || $0 ~ /^\// || $0 ~ /(^|\/)\.\.($|\/)/ { print "unsafe"; exit }
    $0 == "Activity Radar.app/" { next }
    index($0, "Activity Radar.app/") == 1 { next }
    { print "unsafe"; exit }
  '
)"
[[ -z "$ZIP_UNSAFE_ENTRY" ]] || fail "ZIP central directory contains an unsafe or unexpected path"
[[ -z "$(print -r -- "$ZIP_ENTRIES" | sort | uniq -d | sed -n '1p')" ]] \
  || fail "ZIP central directory contains a duplicate entry"
ZIP_STRUCTURE="$(unzip -Z -v "$ZIP")"
ZIP_COMMENT_LENGTH="$(print -r -- "$ZIP_STRUCTURE" | sed -n 's/^[[:space:]]*The zipfile comment is \([0-9][0-9]*\) bytes long.*/\1/p' | sed -n '1p')"
[[ -n "$ZIP_COMMENT_LENGTH" ]] || ZIP_COMMENT_LENGTH=0
[[ "$ZIP_COMMENT_LENGTH" == "0" ]] || fail "ZIP contains an unexpected archive comment"
ZIP_EOCD_OFFSET="$(print -r -- "$ZIP_STRUCTURE" | sed -n 's/^[[:space:]]*Actual end-cent-dir record offset:[[:space:]]*\([0-9][0-9]*\).*/\1/p' | sed -n '1p')"
print -r -- "$ZIP_EOCD_OFFSET" | grep -Eq '^[0-9]+$' || fail "ZIP end-of-central-directory offset is unavailable"
ZIP_SIZE="$(stat -f %z "$ZIP")"
(( ZIP_SIZE == ZIP_EOCD_OFFSET + 22 )) || fail "ZIP contains bytes after its end-of-central-directory record"

codesign --verify --strict --verbose=2 "$DMG"
DMG_SIGNATURE="$(codesign -d --verbose=4 "$DMG" 2>&1)"
print -r -- "$DMG_SIGNATURE" | grep -Fq "Authority=Developer ID Application:" \
  || fail "Delivered DMG is not signed with Developer ID Application"
print -r -- "$DMG_SIGNATURE" | grep -Fxq "TeamIdentifier=$EXPECTED_TEAM_ID" \
  || fail "Delivered DMG signature has the wrong Apple Team ID"
print -r -- "$DMG_SIGNATURE" | grep -Eq '^Timestamp=' \
  || fail "Delivered DMG signature has no secure timestamp"
xcrun stapler validate -v "$DMG"
hdiutil verify "$DMG" >/dev/null
spctl --assess --type open --context context:primary-signature --verbose=4 "$DMG"

DMG_IMAGEINFO_PLIST="$VERIFY_ROOT/dmg-imageinfo.plist"
hdiutil imageinfo -plist "$DMG" > "$DMG_IMAGEINFO_PLIST"
swift scripts/dmg-topology-check.swift imageinfo "$DMG_IMAGEINFO_PLIST" "$DMG" \
  || fail "DMG format or partition topology is not the canonical UDZO/HFS+ layout"

ZIP_VERIFY_ROOT="$VERIFY_ROOT/zip"
mkdir -p "$ZIP_VERIFY_ROOT"
ditto -x -k "$ZIP" "$ZIP_VERIFY_ROOT"
[[ "$(find "$ZIP_VERIFY_ROOT" -mindepth 1 -maxdepth 1 -print | wc -l | tr -d '[:space:]')" == "1" ]] \
  || fail "ZIP contains unexpected top-level payloads"
ZIP_APP="$ZIP_VERIFY_ROOT/Activity Radar.app"
verify_release_app "$ZIP_APP" "ZIP application"
[[ "$(code_directory_hashes "$ZIP_APP")" == "$REFERENCE_CDHASHES" ]] \
  || fail "ZIP application CodeDirectory hashes do not match the loose release app"
[[ "$(bundle_mode_inventory "$ZIP_APP")" == "$REFERENCE_MODE_INVENTORY" ]] \
  || fail "ZIP application modes or flags do not match the loose release app"
diff -qr "$APP" "$ZIP_APP" >/dev/null \
  || fail "ZIP application content does not exactly match the loose release app"

mkdir -p "$DMG_MOUNT"
DMG_ATTACH_PLIST="$VERIFY_ROOT/dmg-attach.plist"
hdiutil attach -plist -readonly -nobrowse -mountpoint "$DMG_MOUNT" "$DMG" > "$DMG_ATTACH_PLIST"
DMG_DEVICE="$DMG_MOUNT"
DMG_ATTACHED=1
DMG_DEVICE_GATE="$(
  swift scripts/dmg-topology-check.swift attach "$DMG_ATTACH_PLIST" "$DMG_MOUNT"
)" || fail "DMG did not attach with exactly one GUID scheme and one HFS+ filesystem"
DMG_DEVICE="${DMG_DEVICE_GATE%%$'\t'*}"
DMG_WHOLE_DEVICE="${DMG_DEVICE_GATE#*$'\t'}"
[[ -n "$DMG_DEVICE" && -n "$DMG_WHOLE_DEVICE" && "$DMG_DEVICE" != "$DMG_WHOLE_DEVICE" ]] \
  || fail "DMG device topology could not be resolved"

DMG_DISKUTIL_PLIST="$VERIFY_ROOT/dmg-diskutil.plist"
diskutil info -plist "$DMG_DEVICE" > "$DMG_DISKUTIL_PLIST"
swift scripts/dmg-topology-check.swift diskutil \
  "$DMG_DISKUTIL_PLIST" "$DMG_MOUNT" "$DMG_DEVICE" "$DMG_WHOLE_DEVICE" \
  || fail "Mounted DMG filesystem identity or read-only policy is invalid"
verify_public_metadata_policy "$DMG_MOUNT" "DMG filesystem"
[[ "$(find "$DMG_MOUNT" -mindepth 1 -maxdepth 1 -print | wc -l | tr -d '[:space:]')" == "2" ]] \
  || fail "DMG contains unexpected top-level payloads"
[[ -L "$DMG_MOUNT/Applications" && "$(readlink "$DMG_MOUNT/Applications")" == "/Applications" ]] \
  || fail "DMG Applications link is missing or unsafe"
DMG_APP="$DMG_MOUNT/Activity Radar.app"
verify_release_app "$DMG_APP" "DMG application"
[[ "$(code_directory_hashes "$DMG_APP")" == "$REFERENCE_CDHASHES" ]] \
  || fail "DMG application CodeDirectory hashes do not match the loose release app"
[[ "$(bundle_mode_inventory "$DMG_APP")" == "$REFERENCE_MODE_INVENTORY" ]] \
  || fail "DMG application modes or flags do not match the loose release app"
diff -qr "$APP" "$DMG_APP" >/dev/null \
  || fail "DMG application content does not exactly match the loose release app"

zsh scripts/public-privacy-scan.sh "$SNAPSHOT_DIR"

hdiutil detach "$DMG_DEVICE" >/dev/null
DMG_ATTACHED=0

VERIFIED_ZIP_DIGEST="sha256:$(shasum -a 256 "$ZIP" | awk '{print $1}')"
VERIFIED_DMG_DIGEST="sha256:$(shasum -a 256 "$DMG" | awk '{print $1}')"
VERIFIED_CHECKSUMS_DIGEST="sha256:$(shasum -a 256 "$CHECKSUMS" | awk '{print $1}')"
VERIFIED_MANIFEST_DIGEST="sha256:$(shasum -a 256 "$MANIFEST" | awk '{print $1}')"
VERIFIED_ACCEPTANCE_DIGEST=""
VERIFIED_ACCEPTANCE_SIZE=""
if (( FINALIZE_EXISTING )); then
  VERIFIED_ACCEPTANCE_DIGEST="sha256:$(shasum -a 256 "$ACCEPTANCE" | awk '{print $1}')"
  VERIFIED_ACCEPTANCE_SIZE="$(stat -f %z "$ACCEPTANCE")"
fi
chmod a-w "$ZIP" "$DMG" "$CHECKSUMS" "$MANIFEST" "$SNAPSHOT_DIR/release-title.txt"
if (( FINALIZE_EXISTING )); then
  chmod a-w "$ACCEPTANCE"
fi

RELEASE_EXISTS=0
if gh release view "$TAG" --repo "$REPOSITORY" >/dev/null 2>&1; then
  RELEASE_EXISTS=1
fi
if (( FINALIZE_EXISTING )); then
  (( RELEASE_EXISTS == 1 )) || fail "No existing GitHub draft was found to finalize"
else
  (( RELEASE_EXISTS == 0 )) || fail "A GitHub Release already exists for $TAG; refusing to mutate it"
fi

release_flags=(--draft)
if [[ "$RELEASE_LABEL" == *-* ]]; then
  release_flags+=(--prerelease)
fi

require_exact_source_checkout
require_frozen_release_notes
[[ "$(remote_tag_revision)" == "$SOURCE_REVISION" ]] \
  || fail "Remote release tag changed before the release operation"

if (( FINALIZE_EXISTING )); then
  note "Re-verifying the existing draft before explicit publication"
else
  note "Creating immutable-ready draft GitHub Release"
  RELEASE_URL="$(
    gh release create "$TAG" \
      "$ZIP" \
      "$DMG" \
      "$CHECKSUMS" \
      "$MANIFEST" \
      --repo "$REPOSITORY" \
      --verify-tag \
      --title "$TITLE" \
      --notes-file "$NOTES_FILE" \
      "${release_flags[@]}"
  )"
fi

[[ "$(remote_tag_revision)" == "$SOURCE_REVISION" ]] \
  || fail "Remote release tag changed during the release operation"
REMOTE_RELEASE_ID="$(release_id_for_tag)"
print -r -- "$REMOTE_RELEASE_ID" | grep -Eq '^[0-9]+$' \
  || fail "GitHub did not return a stable numeric release ID"
REMOTE_RELEASE_RECORD="$(
  gh api "repos/$REPOSITORY/releases/$REMOTE_RELEASE_ID" \
    --jq '[(.id | tostring), .tag_name, .created_at, .html_url] | @tsv'
)"
REMOTE_RECORD_ID="$(print -r -- "$REMOTE_RELEASE_RECORD" | awk -F '\t' '{print $1}')"
REMOTE_RECORD_TAG="$(print -r -- "$REMOTE_RELEASE_RECORD" | awk -F '\t' '{print $2}')"
RELEASE_CREATED_AT="$(print -r -- "$REMOTE_RELEASE_RECORD" | awk -F '\t' '{print $3}')"
RELEASE_URL="$(print -r -- "$REMOTE_RELEASE_RECORD" | awk -F '\t' '{print $4}')"
[[ "$REMOTE_RECORD_ID" == "$REMOTE_RELEASE_ID" && "$REMOTE_RECORD_TAG" == "$TAG" ]] \
  || fail "GitHub numeric release record does not belong to the verified tag"
print -r -- "$RELEASE_CREATED_AT" | grep -Eq \
  '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$' \
  || fail "GitHub release created_at is not canonical UTC with whole seconds"
[[ "$(
  LC_ALL=C date -j -u \
    -f '%Y-%m-%dT%H:%M:%SZ' \
    "$RELEASE_CREATED_AT" \
    '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || true
)" == "$RELEASE_CREATED_AT" ]] \
  || fail "GitHub release created_at is not a valid canonical UTC timestamp"
[[ -n "$RELEASE_URL" ]] || fail "GitHub did not return a release URL"

EXPECTED_PRERELEASE=false
[[ "$RELEASE_LABEL" == *-* ]] && EXPECTED_PRERELEASE=true
REMOTE_RELEASE_GATE="$(
  gh api "repos/$REPOSITORY/releases/$REMOTE_RELEASE_ID" \
    --jq '[.tag_name, .name, (.draft | tostring), (.prerelease | tostring), (.immutable | tostring)] | @tsv'
)"
EXPECTED_DRAFT_GATE="${TAG}"$'\t'"${TITLE}"$'\t'"true"$'\t'"${EXPECTED_PRERELEASE}"$'\t'"false"
EXPECTED_PUBLISHED_GATE="${TAG}"$'\t'"${TITLE}"$'\t'"false"$'\t'"${EXPECTED_PRERELEASE}"$'\t'"true"
ALREADY_PUBLISHED=0
if [[ "$REMOTE_RELEASE_GATE" == "$EXPECTED_PUBLISHED_GATE" ]]; then
  (( FINALIZE_EXISTING )) \
    || fail "An immutable release already exists for this tag"
  ALREADY_PUBLISHED=1
elif [[ "$REMOTE_RELEASE_GATE" != "$EXPECTED_DRAFT_GATE" ]]; then
  fail "GitHub Release is neither the exact draft nor the exact immutable release"
fi
REMOTE_RELEASE_BODY="$(gh api "repos/$REPOSITORY/releases/$REMOTE_RELEASE_ID" --jq '.body // ""')"
[[ "$REMOTE_RELEASE_BODY" == "$EXPECTED_RELEASE_BODY" ]] \
  || fail "GitHub Release body does not match the verified release notes"

if (( FINALIZE_EXISTING )); then
  swift scripts/clean-machine-acceptance-check.swift \
    "$ACCEPTANCE" \
    "$REPOSITORY" \
    "$TAG" \
    "$REMOTE_RELEASE_ID" \
    "$RELEASE_CREATED_AT" \
    "$DMG_NAME" \
    "${VERIFIED_DMG_DIGEST#sha256:}" \
    || fail "Clean-machine acceptance does not match the verified release"

  REMOTE_ASSET_COUNT="$(gh api "repos/$REPOSITORY/releases/$REMOTE_RELEASE_ID" --jq '.assets | length')"
  if (( ALREADY_PUBLISHED )); then
    [[ "$REMOTE_ASSET_COUNT" == "5" ]] \
      || fail "Immutable release does not contain exactly five assets"
    require_remote_asset_names 1
    require_remote_core_asset_digests
    require_remote_acceptance_asset
    [[ "$(remote_tag_revision)" == "$SOURCE_REVISION" ]] \
      || fail "Immutable release tag does not resolve to the verified source revision"
    [[ "$(release_id_for_tag)" == "$REMOTE_RELEASE_ID" ]] \
      || fail "Immutable tag does not resolve to the verified release ID"
    print -- "IMMUTABLE RELEASE ALREADY PUBLISHED AND RE-VERIFIED:"
    print -- "$RELEASE_URL"
    exit 0
  fi

  case "$REMOTE_ASSET_COUNT" in
    4)
      require_remote_asset_names 0
      require_remote_core_asset_digests
      require_exact_source_checkout
      [[ "$(remote_tag_revision)" == "$SOURCE_REVISION" ]] \
        || fail "Remote release tag changed before acceptance upload"
      [[ "$(release_id_for_tag)" == "$REMOTE_RELEASE_ID" ]] \
        || fail "GitHub tag no longer resolves to the verified draft release ID"
      note "Uploading the verified content-free clean-machine acceptance record"
      if ! gh release upload "$TAG" "$ACCEPTANCE" --repo "$REPOSITORY"; then
        fail_acceptance_asset_recovery "GitHub did not confirm a complete clean-machine acceptance upload"
      fi
      ;;
    5)
      require_remote_asset_names 1
      require_remote_core_asset_digests
      require_remote_acceptance_asset
      ;;
    *)
      fail "GitHub draft must contain the four base assets and at most one acceptance asset"
      ;;
  esac

  require_exact_source_checkout
  [[ "$(remote_tag_revision)" == "$SOURCE_REVISION" ]] \
    || fail "Remote release tag changed before publication"
  [[ "$(release_id_for_tag)" == "$REMOTE_RELEASE_ID" ]] \
    || fail "GitHub tag no longer resolves to the verified draft release ID"
  [[ "$(
    gh api "repos/$REPOSITORY/releases/$REMOTE_RELEASE_ID" \
      --jq '[.tag_name, .name, (.draft | tostring), (.prerelease | tostring), (.immutable | tostring)] | @tsv'
  )" == "$EXPECTED_DRAFT_GATE" ]] \
    || fail "GitHub draft metadata changed before publication"
  [[ "$(gh api "repos/$REPOSITORY/releases/$REMOTE_RELEASE_ID" --jq '.body // ""')" == "$EXPECTED_RELEASE_BODY" ]] \
    || fail "GitHub draft body changed before publication"
  require_remote_asset_names 1
  require_remote_core_asset_digests
  require_remote_acceptance_asset
  require_frozen_release_notes
  note "Publishing the fully re-verified draft"
  gh api --method PATCH "repos/$REPOSITORY/releases/$REMOTE_RELEASE_ID" \
    -f name="$TITLE" \
    -f body="$EXPECTED_RELEASE_BODY" \
    -F draft=false \
    -F prerelease="$EXPECTED_PRERELEASE" >/dev/null
  PUBLISHED_GATE="$(
    gh api "repos/$REPOSITORY/releases/$REMOTE_RELEASE_ID" \
      --jq '[.tag_name, .name, (.draft | tostring), (.prerelease | tostring), (.immutable | tostring)] | @tsv'
  )"
  [[ "$PUBLISHED_GATE" == "$EXPECTED_PUBLISHED_GATE" ]] \
    || fail "Published release did not become immutable with the expected metadata"
  [[ "$(remote_tag_revision)" == "$SOURCE_REVISION" ]] \
    || fail "Published release tag does not resolve to the verified source revision"
  [[ "$(release_id_for_tag)" == "$REMOTE_RELEASE_ID" ]] \
    || fail "Immutable tag does not resolve to the published release ID"
  [[ "$(gh api "repos/$REPOSITORY/releases/$REMOTE_RELEASE_ID" --jq '.body // ""')" == "$EXPECTED_RELEASE_BODY" ]] \
    || fail "Immutable release body differs from the verified release notes"
  [[ "$(gh api "repos/$REPOSITORY/releases/$REMOTE_RELEASE_ID" --jq '.assets | length')" == "5" ]] \
    || fail "Immutable release does not contain exactly five assets"
  require_remote_asset_names 1
  require_remote_core_asset_digests
  require_remote_acceptance_asset
  print -- "IMMUTABLE RELEASE PUBLISHED:"
  print -- "$RELEASE_URL"
else
  require_remote_asset_names 0
  require_remote_core_asset_digests
  print -- "DRAFT RELEASE CREATED (not published):"
  print -- "$RELEASE_URL"
  print -- "Download this draft's DMG on clean Apple Silicon and Intel Macs,"
  print -- "complete the quarantine/install checklist, fill the canonical acceptance"
  print -- "JSON, then rerun with --finalize-existing-draft --acceptance-file PATH."
fi
