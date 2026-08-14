# Activity Radar

**Local work continuity for parallel Codex tasks on macOS.**

Activity Radar is a native menu-bar application that helps you return to the right Codex task without treating inactivity as progress—or abandonment. It reads local Codex state in read-only mode, keeps a small user-owned continuity layer, and opens the selected task back in Codex.

[Türkçe README](README.tr.md) · [Privacy](PRIVACY.md) · [Codex integration](docs/CODEX_INTEGRATION.md) · [Contributing](CONTRIBUTING.md)

> [!IMPORTANT]
> The repository is preparing a source-first public beta. A binary is a supported public download only when its GitHub Release explicitly says it is Developer ID–signed and Apple-notarized and includes `SHA256SUMS` plus `RELEASE-MANIFEST.txt`. Local or CI-built ad-hoc apps are not public releases.

## Why it exists

Parallel agent work creates a prospective-memory problem: results arrive in different tasks, quiet work becomes easy to forget, and a timestamp alone cannot tell you what deserves attention. Activity Radar separates observed signals from user decisions and abstains when the evidence is insufficient.

## What it does

- Shows top-level, user-owned Codex tasks while hiding spawned sub-agent threads.
- Separates explicit input requests, blockers, unseen results, recent activity, and quiet open work.
- Never describes a stale turn as running.
- Lets you park work with a checkpoint and one concrete next action.
- Ranks at most three explainable “Why now?” candidates when history is complete enough.
- Returns no ranked candidates when evidence is incomplete, weak, closely matched, snoozed, or waiting on something external.
- Treats long silence as neutral; obsolete and abandoned are explicit, reversible user decisions.
- Searches the locally retained task corpus across 24 hours, 7 days, 30 days, 90 days, or all time.
- Opens the exact task through `codex://threads/<thread-id>`.
- Offers an optional, content-free local research ledger that is off by default.

## Privacy by construction

- No Activity Radar account, OpenAI API key, OAuth flow, telemetry, or network client.
- Codex SQLite files are opened with `SQLITE_OPEN_READONLY` and `PRAGMA query_only=ON`.
- Activity Radar never writes to `~/.codex`.
- Continuity data stays under `~/Library/Application Support/Activity Radar`.
- Research export excludes task identifiers, titles, prompts, messages, paths, checkpoints, next actions, and waiting-on text.
- The diagnostic command emits aggregate, content-free compatibility counts.

See [PRIVACY.md](PRIVACY.md) for the complete storage and export boundary.

## Requirements

- macOS 13 or newer.
- Codex Desktop or Codex CLI previously used by the same macOS account.
- `~/.codex/state_5.sqlite` in a schema supported by this version.
- The Codex desktop application for return-to-task deep links.

Activity Radar is an unofficial local integration. Codex may change its local schema or deep-link contract; incompatible versions fail neutrally instead of attempting to repair Codex data.

## Build from source

A current Xcode installation or compatible Swift toolchain with the macOS SDK is required.

```bash
git clone https://github.com/mehmetsolakedu/activity-radar.git
cd activity-radar

swift run ActivityRadarSelfTest

swiftc -parse-as-library \
  Sources/ActivityRadar/RadarContinuityStore.swift \
  scripts/continuity-store-self-test.swift \
  -o /tmp/activity-radar-continuity-store-self-test
/tmp/activity-radar-continuity-store-self-test

./scripts/package-app.sh --mode local \
  --output-app "$PWD/Activity Radar.app"
open "$PWD/Activity Radar.app"
```

Local mode builds a Universal 2 application and applies an ad-hoc signature unless a signing identity is explicitly supplied. That is appropriate for development on the machine that built it, not for public binary distribution.

## Content-free diagnostics

```bash
swift run ActivityRadarDiagnostics
```

The JSON report contains only aggregate counts and privacy flags. It does not include task-level identifiers or content. Do not upload Codex databases, rollout files, screenshots of real work, or any file from `~/.codex` to an issue.

## Public macOS release contract

The public packager has no unsafe fallback:

```bash
./scripts/package-app.sh --mode public \
  --identity "Developer ID Application: Example Org (TEAMID)" \
  --notary-profile "activity-radar-notary" \
  --bundle-id "io.github.mehmetsolakedu.ActivityRadar" \
  --dist-dir ./dist
```

Public mode requires and verifies:

- arm64 and x86_64 slices with the declared macOS deployment target;
- Developer ID signing, hardened runtime, secure timestamp, and Team ID;
- accepted Apple notarization and stapled tickets for the app and DMG;
- Gatekeeper assessment, ZIP/DMG integrity, and SHA-256 checksums.

Credentials are read from a `notarytool` Keychain profile; passwords and API private keys are never accepted on the command line. See [Packaging/DISTRIBUTION.md](Packaging/DISTRIBUTION.md).

## Contributing

Bug reports, privacy reviews, accessibility improvements, documentation, deterministic tests, and focused code changes are welcome. All examples and screenshots must be synthetic. Start with [CONTRIBUTING.md](CONTRIBUTING.md), follow [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md), and report vulnerabilities through [SECURITY.md](SECURITY.md).

The project is available under the [MIT License](LICENSE). Asset provenance is documented in [ASSET_NOTICES.md](ASSET_NOTICES.md).

## Research boundary

Activity Radar implements a testable product hypothesis; it does not by itself prove faster resumption, lower cognitive load, scientific novelty, or superiority. See [docs/RESEARCH_BOUNDARY.md](docs/RESEARCH_BOUNDARY.md).

Activity Radar is an independent community project. It is not an official OpenAI product and is not endorsed or supported by OpenAI.
