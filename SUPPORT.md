# Support

Activity Radar is an independent community project and is not an official
OpenAI product.

## Where to ask

- Use repository discussions, when enabled, for setup and usage questions.
- Open an issue for a reproducible bug or a bounded feature proposal.
- Use the private process in [SECURITY.md](SECURITY.md) for security or privacy
  vulnerabilities.
- Use the private process in [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) for
  conduct reports.

Community support is best effort; no response-time guarantee is provided.

## Before opening an issue

Run the deterministic local checks:

~~~sh
swift run ActivityRadarSelfTest

swiftc -parse-as-library \
  Sources/ActivityRadar/RadarContinuityStore.swift \
  scripts/continuity-store-self-test.swift \
  -o /tmp/activity-radar-continuity-store-self-test
/tmp/activity-radar-continuity-store-self-test

swift build -c release --product ActivityRadar
~~~

Include the macOS version, CPU architecture, Activity Radar version or commit,
the smallest synthetic reproduction, expected behavior, actual behavior, and
which checks passed or failed.

## Protect private data

`ActivityRadarDiagnostics` emits aggregate compatibility counts and explicit
privacy-boundary flags. Its output contract excludes task identifiers, titles
or messages, local paths, and checkpoints. Review the final attachment before
uploading it. If diagnostic output contains private work context, do not post
it; use the private process in [SECURITY.md](SECURITY.md). Use synthetic values
for reproductions, and do not rely on visual blurring for text files or
structured data.

## Current distribution boundary

Source builds are the supported collaboration path. Availability of signed,
notarized, architecture-specific, or package-manager binaries depends on the
artifacts explicitly published by project maintainers. Do not treat an
unpublished or locally built artifact as an official public release.
