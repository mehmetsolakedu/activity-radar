# macOS distribution contract

`scripts/package-app.sh` has two deliberately separate modes.

## Local build

```sh
./scripts/package-app.sh --mode local --output-app "/tmp/Activity Radar.app"
```

The local mode always builds both `arm64` and `x86_64`, combines them as a
Universal 2 executable, checks the deployment target in both slices, and signs
the bundle ad-hoc unless `--identity` is supplied. An ad-hoc or merely signed
local build is explicitly **not** a public release.

Pass `--overwrite` to replace an existing output app.

## Public release

First store notarization credentials in Keychain. Do not put an Apple ID
password or API private key in this repository or in the packaging command.

```sh
xcrun notarytool store-credentials "activity-radar-notary"
```

Then run the release with values belonging to the publisher:

```sh
./scripts/package-app.sh --mode public \
  --identity "Developer ID Application: Example Publisher (TEAMID1234)" \
  --notary-profile "activity-radar-notary" \
  --release-tag "v1.2.0-beta.2" \
  --team-id "TEAMID1234" \
  --bundle-id "io.github.mehmetsolakedu.ActivityRadar" \
  --dist-dir ./dist
```

Run public mode only from a clean Git checkout whose exact `--release-tag`
points at `HEAD`. The numeric app version stays in `Info.plist`; the release tag
carries the prerelease label used in the directory, ZIP, and DMG names.

The tagged output directory contains the stapled app, a ZIP, a signed and
stapled DMG, `SHA256SUMS`, and `RELEASE-MANIFEST.txt`. The public command fails
instead of falling back when any of these gates is missing or fails:

- both `arm64` and `x86_64` builds at the declared minimum macOS version;
- a clean exact-tag Git checkout and matching `Info.plist` version;
- an available Developer ID Application identity belonging to the expected
  Apple Team ID;
- hardened-runtime signing with a secure timestamp and exact bundle ID;
- a usable Keychain notarization profile before either architecture is built;
- accepted app and DMG notarizations whose downloaded logs contain no reported
  issues, followed by ticket stapling;
- a canonical metadata-free ZIP and an exact UDZO/GUID/HFS+ DMG topology with
  one read-only `Activity Radar` volume and zero-data raw free regions;
- `codesign`, `stapler`, `spctl`, archive-content, and SHA-256 verification.

Existing versioned release output is never silently merged. Use `--overwrite`
to replace only that exact version directory.

## Create the draft GitHub Release

After the tagged commit's CI is green, use the credential-free publisher to
independently re-check the finished directory and upload only the ZIP, DMG,
checksum file, and release manifest. Start from
`Packaging/RELEASE_NOTES_TEMPLATE.md`, replace every placeholder, and keep the
notes outside the release directory so the public artifact set remains exact:

```sh
./scripts/publish-github-release.sh \
  --tag "v1.2.0-beta.2" \
  --team-id "TEAMID1234" \
  --release-dir "./dist/Activity-Radar-1.2.0-beta.2-macOS-universal2" \
  --notes-file "/absolute/path/to/release-notes.md"
```

The command requires a bypass-free default-branch ruleset that blocks deletion
and non-fast-forward updates, requires a pull request with resolved review
threads, and strictly requires both `macOS verification` and `Intel runtime`.
It also requires a bypass-free release-tag ruleset, immutable releases, and an
exact successful default-branch `push` CI run whose two jobs passed for the
tagged commit. The repository's stable numeric GitHub identity is frozen and
rechecked around release operations. The publisher creates a **draft**
prerelease and refuses to mutate an existing release. It does not receive
signing credentials. Do not publish the draft in the GitHub UI or with a
different command. Only the explicit finalization step below may publish it;
release immutability then prevents later tag or asset replacement.

The release-notes checker requires the installation, integrity, compatibility,
privacy, limitations, and asset sections in the committed template. It also
requires exact tag-pinned links to `INSTALL.md`, `PRIVACY.md`, and `SECURITY.md`
and the calculated ZIP, DMG, and acceptance-record filenames. This prevents a
technically valid binary from being published without a usable end-user
contract.

## Reproducibility boundary

Public packaging first materializes the exact tagged Git tree into a temporary
snapshot. Each architecture is built from that snapshot in a fresh, isolated
SwiftPM scratch directory with an explicit target triple, SDK, release
configuration, and deployment target.
Bundle and ZIP mtimes are normalized with `SOURCE_DATE_EPOCH` (default:
`2000-01-01T00:00:00Z`), and every public archive plus its release manifest is
checksummed. The manifest records the exact release tag, source commit, Swift
toolchain, SDK, build host architecture, signing team, and accepted no-issue
notarization outcomes. Apple submission UUIDs remain in the private notarization
logs and are not copied into public artifacts.

Developer ID secure timestamps, Apple notarization responses, stapled tickets,
and DMG filesystem metadata are intentionally time-dependent. The manifest and
SHA-256 file provide a reviewable source-to-artifact record and integrity
checks; they are not a third-party build attestation, and the signed result is
not claimed to be byte-for-byte reproducible across separate notarization runs.
The credential-free publisher independently verifies the visible signed app,
archive topology, and raw GPT free regions; it still trusts the named Apple Team
that signed and notarized the HFS+ image. It is not a defense against a malicious
holder of that team's Developer ID credentials hiding data in filesystem slack.

## Clean-machine distribution acceptance

Do not publish the draft binary until the actual GitHub draft DMG has been
tested with browser quarantine on clean Macs that did not build it. Verify the
checksum, read-only mount, copy to Applications, eject, Gatekeeper launch,
menu-bar item, About identity, content-free support text, synthetic Codex
return-to-task, application replacement, and complete uninstall. Record Apple
Silicon and Intel results separately. At least one of the two records must come
from a real macOS 13.x runtime; declaring a 13.0 deployment target is not
runtime evidence.

On each clean Mac, perform the fixed sequence below without recording a user,
machine, path, task title, task identifier, screenshot, or note in the JSON:

1. Download the draft DMG through a browser, verify its SHA-256, open it, confirm
   the mounted volume is read-only, copy the app to Applications, eject the DMG,
   and launch only the Applications copy through Gatekeeper.
2. Confirm the menu-bar item appears. In **Activity Radar Hakkında…**, compare
   the version, build, release tag, and 12-character source prefix with
   `RELEASE-MANIFEST.txt`; also confirm the independent-community-project and
   unofficial-OpenAI-product notice is visible.
3. Use **Destek Bilgisini Kopyala** and inspect the clipboard locally. It may
   contain only the fixed build, architecture, and macOS fields shown by the
   app; it must not contain a task title, task identifier, path, checkpoint, or
   transcript text. Do not paste the result into the acceptance JSON.
4. In Codex, create a disposable task containing only the public phrase
   `Activity Radar clean-machine synthetic task`. Refresh Activity Radar, select
   that task, and confirm the return-to-task action opens that same task in
   Codex. Do not record or publish its generated identifier or a screenshot.
5. Change Activity Radar's date range from **30 gün** to **7 gün**, quit the app,
   drag the same verified candidate from the DMG to Applications, choose
   **Replace**, reopen it, and confirm **7 gün** persisted. This exercises the
   replacement path for the first installable beta; it is not evidence of a
   migration from an older public binary.
6. Quit, move the app to Trash, optionally remove only Activity Radar's own
   local support data and preference file, and confirm Codex data was untouched.

Copy `Packaging/CLEAN_MACHINE_ACCEPTANCE.template.json` to the exact versioned
name printed by the draft command. Fill only the fixed fields; do not add a
tester, machine name, path, note, task identifier, or any free-text field. The
template is intentionally invalid while any result is `false` or a placeholder
remains. Obtain the public numeric draft ID and its exact creation time with:

```sh
gh release view "v1.2.0-beta.2" \
  --repo "mehmetsolakedu/activity-radar" \
  --json databaseId,createdAt \
  --jq '{releaseID: .databaseId, releaseCreatedAt: .createdAt}'
```

The JSON must bind that ID and creation time, the repository, tag, exact DMG
asset name, and the bare lowercase DMG SHA-256. Put the `arm64` record first and
the `x86_64` record second. Each canonical UTC `testedAt` must be at or after the
draft's `releaseCreatedAt`. After both physical tests, canonicalize to a new
temporary file, verify that file, and only then move it to the final name. This
avoids truncating a previously valid record when validation fails:

```sh
CANONICAL_ACCEPTANCE="$(mktemp -t activity-radar-acceptance)"

swift scripts/clean-machine-acceptance-check.swift \
  --canonicalize \
  "/absolute/path/to/acceptance-working.json" \
  "mehmetsolakedu/activity-radar" \
  "v1.2.0-beta.2" \
  "123456789" \
  "2026-08-20T10:00:00Z" \
  "Activity-Radar-1.2.0-beta.2-macOS-universal2.dmg" \
  "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" \
  > "$CANONICAL_ACCEPTANCE"

swift scripts/clean-machine-acceptance-check.swift \
  "$CANONICAL_ACCEPTANCE" \
  "mehmetsolakedu/activity-radar" \
  "v1.2.0-beta.2" \
  "123456789" \
  "2026-08-20T10:00:00Z" \
  "Activity-Radar-1.2.0-beta.2-macOS-universal2.dmg" \
  "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"

mv "$CANONICAL_ACCEPTANCE" \
  "/absolute/path/to/Activity-Radar-1.2.0-beta.2-CLEAN-MACHINE-ACCEPTANCE.json"
```

Replace the example release ID, creation time, and digest with the verified
values. The formal shape is in
`Packaging/CLEAN_MACHINE_ACCEPTANCE.schema.json`. The validator requires an
exact, canonical, content-free schema and all physical checks to be JSON
booleans equal to `true`. This record is structured human attestation; it binds
what was recorded to the release but cannot cryptographically prove that a
person performed the physical tests.

After those checks pass, rerun the publisher with the same tag, Team ID,
release directory, notes, and optional title, plus the explicit finalization
mode and canonical acceptance file:

```sh
./scripts/publish-github-release.sh \
  --tag "v1.2.0-beta.2" \
  --team-id "TEAMID1234" \
  --release-dir "./dist/Activity-Radar-1.2.0-beta.2-macOS-universal2" \
  --notes-file "/absolute/path/to/release-notes.md" \
  --finalize-existing-draft \
  --acceptance-file "/absolute/path/to/Activity-Radar-1.2.0-beta.2-CLEAN-MACHINE-ACCEPTANCE.json"
```

This mode rebuilds the verification snapshot, rechecks the source tag, branch
and tag protections, exact CI run, signatures, tickets, archive contents,
checksums, remote draft body, and all four base asset digests. It validates and
privacy-scans the frozen acceptance JSON, then uploads it once as the fifth
asset without clobbering an existing file. An interrupted retry accepts only
the same acceptance digest. The finalizer rechecks the exact five-asset set
immediately before publication, requires GitHub to report the release as
immutable, and verifies the tag, body, and five asset digests again. If the
publish succeeded but the final local check was interrupted, rerunning the same
command can only report success after re-verifying the immutable release.

GitHub can leave a failed upload as a draft asset whose state is `starter`.
The publisher deliberately stops instead of replacing or deleting remote data.
Before retrying, verify the repository, tag, numeric draft ID, asset name, and
that the release is still a draft; then remove only that incomplete draft asset
in GitHub and rerun the identical finalizer command. If initial draft creation
stopped after uploading only part of the four-asset set, verify the same
identity fields, remove only that incomplete draft release (never its Git tag),
and rerun the original draft command. Never repair a published or immutable
release in place; use a new tag.

GitHub does not provide an atomic compare-and-publish operation covering every
draft field. Finalization therefore assumes that no other release manager edits
the draft during this short command. A post-publish mismatch is reported as a
failure, but an immutable release cannot then be repaired in place; publish a
new tag instead.
