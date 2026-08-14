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
checksum file, and release manifest:

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

## Manual distribution acceptance

Do not publish the draft binary until the actual release download has been
tested with browser quarantine on a clean Mac that did not build it. Verify the
checksum, mount the DMG, drag the app to Applications, launch it through
Gatekeeper, confirm the menu-bar item appears, and exercise a synthetic Codex
return-to-task flow. Record Apple Silicon and Intel results separately. The CI
Intel job executes tests natively, but it is not a substitute for this
download-and-install check; macOS 13 runtime compatibility also remains a
separate manual gate unless it is tested on Ventura.

After those checks pass, rerun the publisher with the same tag, Team ID,
release directory, notes, and optional title, plus both explicit finalization
flags:

```sh
./scripts/publish-github-release.sh \
  --tag "v1.2.0-beta.2" \
  --team-id "TEAMID1234" \
  --release-dir "./dist/Activity-Radar-1.2.0-beta.2-macOS-universal2" \
  --notes-file "/absolute/path/to/release-notes.md" \
  --finalize-existing-draft \
  --confirm-clean-machine-tests
```

This mode rebuilds the verification snapshot, rechecks the source tag, branch
and tag protections, exact CI run, signatures, tickets, archive contents,
checksums, remote draft body, and all four remote asset digests before it
publishes. It then requires GitHub to report the published release as immutable
and verifies its tag, body, and asset digests again. The confirmation flag is a
human attestation that the clean-machine tests above were actually completed;
the script cannot perform those physical-machine checks itself.
