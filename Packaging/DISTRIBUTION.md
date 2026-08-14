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
  --identity "Developer ID Application: Example Org (TEAMID)" \
  --notary-profile "activity-radar-notary" \
  --bundle-id "com.example.activityradar" \
  --dist-dir ./dist
```

The versioned output directory contains the stapled app, a ZIP, a signed and
stapled DMG, `SHA256SUMS`, and `RELEASE-MANIFEST.txt`. The public command fails
instead of falling back when any of these gates is missing or fails:

- both `arm64` and `x86_64` builds at the declared minimum macOS version;
- an available Developer ID Application identity;
- hardened-runtime signing with a secure timestamp and Team ID;
- an accepted app notarization followed by app ticket stapling;
- an accepted DMG notarization followed by DMG ticket stapling;
- `codesign`, `stapler`, `spctl`, ZIP, DMG, and SHA-256 verification.

Existing versioned release output is never silently merged. Use `--overwrite`
to replace only that exact version directory.

## Reproducibility boundary

Each architecture is built in a fresh, isolated SwiftPM scratch directory with
an explicit target triple, SDK, release configuration, and deployment target.
Bundle and ZIP mtimes are normalized with `SOURCE_DATE_EPOCH` (default:
`2000-01-01T00:00:00Z`), and every public archive is checksummed.

Developer ID secure timestamps, Apple notarization responses, stapled tickets,
and DMG filesystem metadata are intentionally time-dependent. Therefore a
public notarized artifact is provenance-verified by its manifest and SHA-256
checksums; it is not claimed to be byte-for-byte reproducible across separate
signing/notarization runs.
