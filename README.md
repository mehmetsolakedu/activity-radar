# AiWingman

**Local work continuity for parallel Codex tasks on macOS.**

[![CI](https://github.com/mehmetsolakedu/activity-radar/actions/workflows/ci.yml/badge.svg)](https://github.com/mehmetsolakedu/activity-radar/actions/workflows/ci.yml)

AiWingman is a native menu-bar application that helps you return to the right Codex task without treating inactivity as progress—or abandonment. It reads local Codex state in read-only mode, keeps a small user-owned continuity layer, and opens the selected task back in Codex.

[Install](INSTALL.md) · [Türkçe kurulum](INSTALL.tr.md) · [Türkçe README](README.tr.md) · [Privacy](PRIVACY.md) · [Codex integration](docs/CODEX_INTEGRATION.md) · [Publication blueprint](docs/PUBLICATION_BLUEPRINT.md) · [Contributing](CONTRIBUTING.md)

> [!IMPORTANT]
> **SAFETY HOLD:** `v1.2.0-beta.2` and this matching default-branch snapshot are superseded. Do not build or use them. Later review found release-blocking privacy and robustness defects, including incomplete path containment, unbounded session-index reads, unverifiable temporary-auth cleanup, and overbroad privacy copy. The [beta2 release page](https://github.com/mehmetsolakedu/activity-radar/releases/tag/v1.2.0-beta.2) carries the same warning. No supported public tag is available until the hardened source candidate completes review.

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
  That packet is processed with a fixed review instruction and output schema.
  Do not rely on this superseded branch's prose as an exhaustive statement of
  the packet fields; inspect the one-shot preview before any optional call.
- The child CLI uses a read-only sandbox, but this is not a guarantee that it
  cannot read other local files. The previewed packet must not be treated as the
  only context technically accessible to that process. See [PRIVACY.md](PRIVACY.md).
- Codex SQLite files are requested in read-only/query-only mode. This
  superseded build does not establish a no-write guarantee for SQLite WAL
  sidecars such as `-shm` under `~/.codex`.
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

## Installation hold

There is currently no supported public build or tag. Do not build from
`v1.2.0-beta.2` or from this moving/default-branch snapshot. Exact-tag source
instructions will return only after the hardened candidate passes its release
and privacy gates. GitHub's automatic source archives are not macOS installers.

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
