# AiWingman

**Local work continuity for parallel Codex tasks on macOS.**

[![CI](https://github.com/mehmetsolakedu/activity-radar/actions/workflows/ci.yml/badge.svg)](https://github.com/mehmetsolakedu/activity-radar/actions/workflows/ci.yml)

AiWingman is a native menu-bar application that helps you return to the right Codex task without treating inactivity as progress—or abandonment. It queries local Codex state through read-only/query-only SQL access, keeps a small user-owned continuity layer, and opens the selected task back in Codex.

[Install](INSTALL.md) · [Türkçe kurulum](INSTALL.tr.md) · [Türkçe README](README.tr.md) · [Privacy](PRIVACY.md) · [Codex integration](docs/CODEX_INTEGRATION.md) · [Publication blueprint](docs/PUBLICATION_BLUEPRINT.md) · [Contributing](CONTRIBUTING.md)

> [!IMPORTANT]
> [`v1.2.0-beta.2`](https://github.com/mehmetsolakedu/activity-radar/releases/tag/v1.2.0-beta.2) is the current free, source-first community beta. It contains no prebuilt app: inspect the exact tag and build it locally with the commands below. GitHub's automatic source archives are source code, not macOS installers.

## Why it exists

Parallel agent work creates a prospective-memory problem: results arrive in different tasks, quiet work becomes easy to forget, and a timestamp alone cannot tell you what deserves attention. AiWingman separates observed signals from user decisions and abstains when the evidence is insufficient.

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
- Switches the dashboard, editor, status menu, and Wingman interface instantly
  between Turkish and English, and remembers the local choice.
- Can optionally start a separate Codex CLI Wingman turn to critique prompting,
  harness scope, unfinished work, and token-review candidates.
- Offers an optional, content-free local research ledger that is off by default.

## Privacy by construction

- No AiWingman account, separate API-key request or storage, OAuth flow,
  telemetry, background agent call, or background upload. The dashboard makes
  no network request. Optional review reuses the signed-in CLI's saved
  authentication mechanism opaquely.
- The optional remote Wingman critique requires a separately installed and
  signed-in Codex CLI. AiWingman shows the exact user-derived JSON packet it
  intends to supply on stdin and requires one-shot consent before every call.
  That packet is processed with a fixed review instruction and output schema
  that contain no task data; prompt
  excerpts, prompt-derived themes, and local text signals share one separate,
  off-by-default choice. With it off, the packet contains task titles and
  numeric measurements only.
- The child CLI uses a read-only sandbox, but this is not a guarantee that it
  cannot read other local files. The previewed packet must not be treated as the
  only context technically accessible to that process. See [PRIVACY.md](PRIVACY.md).
- Codex SQLite files are opened with `SQLITE_OPEN_READONLY` and `PRAGMA query_only=ON`; AiWingman issues no SQL writes to Codex records or schema.
- SQLite's WAL coordination can nevertheless create or update an auxiliary
  `state_5.sqlite-shm` or `goals_1.sqlite-shm` file under `~/.codex`. AiWingman
  does not intentionally create or modify Codex records, rollout files, the
  main database, or its WAL. The `-shm` file can persist according to the
  SQLite/Codex lifecycle. See [PRIVACY.md](PRIVACY.md) for this narrow VFS
  exception.
- Continuity data stays under the legacy compatibility path
  `~/Library/Application Support/Activity Radar`.
- Research export excludes task identifiers, titles, prompts, messages, paths, checkpoints, next actions, and waiting-on text.
- The diagnostic command emits aggregate, content-free compatibility counts.

See [PRIVACY.md](PRIVACY.md) for the complete storage and export boundary.

## Requirements

- macOS 13 or newer.
- Codex Desktop or Codex CLI previously used by the same macOS account.
- `~/.codex/state_5.sqlite` in a schema supported by this version.
- The Codex desktop application for return-to-task deep links.
- A compatible, signed-in Codex CLI only for the optional remote Wingman
  critique; the dashboard does not require it.

AiWingman is an unofficial local integration. Codex may change its local schema or deep-link contract; incompatible versions fail neutrally instead of attempting to repair Codex data. The optional remote critique uses the user's existing Codex CLI account and may consume that account's plan or quota; AiWingman itself is free and does not sell a subscription.

## Build from source

A current Xcode installation or compatible Swift toolchain with the macOS SDK is required.

For a published source release, replace the example tag below with the exact tag shown on that release page. Do not build a release binary from a moving branch.

```bash
git clone https://github.com/mehmetsolakedu/activity-radar.git
cd activity-radar
RELEASE_TAG=v1.2.0-beta.2
git switch --detach "$RELEASE_TAG"
test "$(git rev-parse HEAD)" = "$(git rev-list -n 1 "$RELEASE_TAG")"

swift run ActivityRadarSelfTest

swiftc -parse-as-library \
  Sources/ActivityRadar/RadarContinuityStore.swift \
  scripts/continuity-store-self-test.swift \
  -o /tmp/activity-radar-continuity-store-self-test
/tmp/activity-radar-continuity-store-self-test

./scripts/package-app.sh --mode local \
  --output-app "$PWD/AiWingman.app"
open "$PWD/AiWingman.app"
```

Local mode builds a Universal 2 application and applies an ad-hoc signature unless a signing identity is explicitly supplied. AiWingman deliberately retains the legacy `ActivityRadar` executable, bundle identifiers, preference keys, and application-support path so existing Activity Radar users keep their data. These are compatibility identifiers, not a second application. Local mode is appropriate for use on the machine that built it, not for redistributing that locally signed bundle.

For a supported signed download, follow [INSTALL.md](INSTALL.md). GitHub's automatic source archives and a locally ad-hoc-signed app are not installers.

AiWingman is an `LSUIElement` menu-bar app, so it does not appear in the
Dock after launch. Look for its radar icon in the menu bar, or press `⌘⇧K` to
show the panel.

## Content-free diagnostics

```bash
swift run ActivityRadarDiagnostics
```

The JSON report contains only aggregate counts and privacy flags. It does not include task-level identifiers or content. Do not upload Codex databases, rollout files, screenshots of real work, or any file from `~/.codex` to an issue.

## Public macOS release contract

The public packager has no unsafe fallback:

```bash
./scripts/package-app.sh --mode public \
  --identity "Developer ID Application: Example Publisher (TEAMID1234)" \
  --notary-profile "activity-radar-notary" \
  --release-tag "v1.2.0-beta.3" \
  --team-id "TEAMID1234" \
  --bundle-id "io.github.mehmetsolakedu.ActivityRadar" \
  --dist-dir ./dist
```

Public mode requires and verifies:

- arm64 and x86_64 slices with the declared macOS deployment target;
- Developer ID signing, hardened runtime, secure timestamp, and Team ID;
- clean exact-tag source provenance and prerelease-aware artifact names;
- accepted Apple notarization, issue-free downloaded logs, and stapled tickets
  for the app and DMG;
- Gatekeeper assessment, a metadata-free ZIP, a single-volume read-only
  UDZO/GUID/HFS+ DMG, and SHA-256 checksums covering the release manifest.
- a release-bound, content-free acceptance record for clean arm64 and x86_64
  installs, including a real macOS 13.x runtime result, before publication.

Credentials are read from a `notarytool` Keychain profile; passwords and API private keys are never accepted on the command line. See [Packaging/DISTRIBUTION.md](Packaging/DISTRIBUTION.md).

## Contributing

Bug reports, privacy reviews, accessibility improvements, documentation, deterministic tests, and focused code changes are welcome. All examples and screenshots must be synthetic. Start with [CONTRIBUTING.md](CONTRIBUTING.md), follow [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md), and report vulnerabilities through [SECURITY.md](SECURITY.md).

The project is available under the [MIT License](LICENSE). Asset provenance is documented in [ASSET_NOTICES.md](ASSET_NOTICES.md), and research use can cite [CITATION.cff](CITATION.cff).

## Research boundary

AiWingman is an open-source software artifact; its technical tests do not prove faster resumption, lower cognitive load, scientific novelty, or superiority. See [docs/RESEARCH_BOUNDARY.md](docs/RESEARCH_BOUNDARY.md).

AiWingman is an independent community project. It is not an official OpenAI product and is not endorsed or supported by OpenAI.
