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

Before every remote call, AiWingman makes the exact user-derived JSON packet
it intends to supply on stdin available for inspection and requires one-shot consent. The packet is
processed with the fixed reviewer instruction and output schema shipped in the
source; those fixed texts contain no task data. Prompt excerpts, prompt-derived
themes, and local text signals are off by default. With that option off,
task-derived free text is limited to sanitized titles; prompt excerpts,
prompt-derived themes, local review signals, and next-move text are omitted.
The packet still contains timestamps and the activity cutoff,
status/enumeration fields, booleans, counts, numeric measurements,
schema/language metadata, and a fixed method-boundary string. Scope or
prompt-sharing changes clear consent, and consent is also
cleared after an attempt. AiWingman requests Codex CLI read-only sandbox mode,
intended to deny agent-tool writes to the workspace. This is neither OS-level
isolation nor a zero-filesystem-write guarantee, and it does not prove that the
child cannot read another local file; the previewed packet is not a sole-context
guarantee.

AiWingman validates the saved CLI authentication file's metadata and makes
an opaque, private temporary copy for the isolated child process. It does not
parse or include credential contents in the packet, diagnostics, or logs,
and does not copy user rules or configuration. Normal completion and error paths
attempt removal and verify absence. If absence cannot be verified, the result is
rejected and later remote operations in that app process remain blocked until
cleanup succeeds. A crash or forced termination can still leave a documented
prefixed temporary directory. A timeout, cancellation,
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

Tag `v1.2.0-beta.2` at `5e212181...` is superseded; do not build or use it.
Current `main` at `2248203...` adds the supersession documentation while
retaining that unsupported application source. The hardened review branch is available for technical audit
and contributions, but no current tag is a supported installation release.
Availability of signed, notarized, architecture-specific, source-only, or
package-manager releases depends on the artifacts explicitly published by
project maintainers. Do not treat an unpublished branch or locally built artifact
as an official public release.
