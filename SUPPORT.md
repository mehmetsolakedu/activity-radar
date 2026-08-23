# Support

AiWingman is an independent community project and is not an official
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

Include the macOS version, CPU architecture, AiWingman version or commit,
the smallest synthetic reproduction, expected behavior, actual behavior, and
which checks passed or failed.

For an installed app, **Destek Bilgisini Kopyala** in the status menu provides
the same safe version/provenance context without task data.

## Wingman troubleshooting

If the optional remote critique is unavailable, verify a compatible installed
CLI and saved login with `codex --version` and `codex login status`, then use
**Codex CLI'yi yeniden denetle** in the Wingman sheet. The dashboard remains
available without the CLI. AiWingman does not install the CLI, request an
API key, or start a background call.

Before every remote call, AiWingman displays the exact user-derived JSON packet
it intends to supply on stdin and requires one-shot consent. The packet is
processed with the fixed reviewer instruction and output schema shipped in the
source; those fixed texts contain no task data. Prompt excerpts, prompt-derived
themes, and local text signals are off by default; with that option off the
packet contains task titles and numeric measurements only. Scope or
prompt-sharing changes clear consent, and consent is also
cleared after an attempt. The CLI's read-only sandbox blocks writes but does not
prove that the child cannot read another local file; the previewed packet is not
a sole-context guarantee.

AiWingman validates the saved CLI authentication file's metadata and makes
an opaque, private temporary copy for the isolated child process. It does not
parse or include credential contents in the packet, diagnostics, or logs,
does not copy user rules or configuration, and removes the temporary copy after
the attempt. A timeout, cancellation,
unknown or tool event, or invalid schema intentionally discards partial output.
Never attach the JSON packet, `auth.json`, Codex databases, or rollout files to
a public support request.

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
