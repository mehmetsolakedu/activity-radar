# AiWingman

**Local work continuity for parallel Codex tasks on macOS.**

[![CI](https://github.com/mehmetsolakedu/activity-radar/actions/workflows/ci.yml/badge.svg)](https://github.com/mehmetsolakedu/activity-radar/actions/workflows/ci.yml)

AiWingman is a native menu-bar application that presents continuity evidence for candidate Codex tasks without treating inactivity as progress—or abandonment. It queries local Codex state through read-only/query-only SQL access, keeps a small user-owned continuity layer, and requests that Codex open the user-selected task.

[Install](INSTALL.md) · [Türkçe kurulum](INSTALL.tr.md) · [Türkçe README](README.tr.md) · [Privacy](PRIVACY.md) · [Codex integration](docs/CODEX_INTEGRATION.md) · [Research boundary](docs/RESEARCH_BOUNDARY.md) · [Contributing](CONTRIBUTING.md)

> [!IMPORTANT]
> [`v1.2.0-beta.2`](https://github.com/mehmetsolakedu/activity-radar/releases/tag/v1.2.0-beta.2) is superseded and must not be built or used. Its unsigned annotated tag currently resolves to commit `5e212181ae177cd555ab6bb92f5f71ac8be9173a`; later hardening corrected a database-controlled rollout-path trust issue, an unbounded session-index read, and unverifiable temporary-auth cleanup present at that commit. Its mutable release page now carries the security and documentation correction. No tagged public build is currently recommended; wait for a later explicitly supported source release. GitHub's automatic source archives are source code, not macOS installers.

## Why it exists

Parallel agent work creates a prospective-memory problem: results arrive in different tasks, quiet work becomes easy to forget, and a timestamp alone cannot tell you what deserves attention. AiWingman separates observed signals from user decisions and abstains when the evidence is insufficient.

## What it does

- Shows candidate root rows selected through bounded observed-schema filters while hiding rows listed as spawned children; at most 200 rows are returned, with no more than 64 priority/goal inclusions, and these filters do not prove user ownership or complete root classification.
- Separates explicit input requests, blockers, unseen results, recent activity, and quiet open work.
- Never describes a stale turn as running.
- Lets you park work with a checkpoint and one concrete next action.
- Ranks at most three explainable “Why now?” candidates when history is complete enough.
- Excludes an incomplete item from ranking; if another complete item supports a recommendation, that recommendation is not suppressed. Returns no ranking when no eligible complete evidence remains or when evidence is weak, closely matched, snoozed, or waiting on something external.
- Treats long silence as neutral; obsolete and abandoned are explicit, reversible user decisions.
- Searches the locally retained candidate corpus across 24 hours, 7 days, 30 days, 90 days, or all time; every range remains subject to the documented reader, row, and page caps.
- Requests that Codex Desktop open the selected task through the observed
  `codex://threads/<thread-id>` deep link; behavior depends on the installed
  Codex version.
- Switches the dashboard, editor, status menu, and Wingman interface instantly
  between Turkish and English, and remembers the local choice.
- Can optionally start a separate Codex CLI Wingman turn to critique prompting,
  harness scope, unfinished work, and token-review candidates.
- Offers an optional, fixed-schema local research ledger that is off by default
  and excludes task text and raw task identifiers.

## Privacy by construction

- No AiWingman account, separate API-key request or storage, OAuth flow,
  telemetry, background agent call, or background upload. The dashboard makes
  no network request. Optional review reuses the signed-in CLI's saved
  authentication mechanism opaquely.
- The optional remote Wingman critique requires a separately installed and
  signed-in Codex CLI. AiWingman makes the exact user-derived JSON packet it
  intends to supply on stdin available for inspection and requires one-shot
  consent before every call.
  That packet is processed with a fixed review instruction and output schema
  that contain no task data; prompt
  excerpts, prompt-derived themes, and local text signals share one separate,
  off-by-default choice. With it off, task-derived free text is limited to
  sanitized titles; prompt excerpts, prompt-derived themes, local review signals,
  and next-move text are omitted. The packet still contains timestamps and the
  activity cutoff, status/enumeration fields, booleans, counts, numeric
  measurements, schema/language metadata, and a fixed method-boundary string.
- Opening the Wingman sheet does not run Codex CLI. A separate explicit
  **Check Codex CLI** action checks version, command compatibility, and login
  status without starting an agent turn or sending a task packet. That check
  uses a private temporary opaque copy of the saved CLI authentication file and
  follows the same documented cleanup boundary.
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
- Research export excludes raw Codex task identifiers and human-authored task
  text; it includes a salted task pseudonym, timestamp, fixed event kind, and
  condition.
- The diagnostic command emits aggregate, fixed-schema compatibility counts
  with no task text or raw task identifiers.

See [PRIVACY.md](PRIVACY.md) for the complete storage and export boundary.

## Requirements

- The package declares macOS 13 as its deployment target. Current automated builds and tests ran on later macOS versions; no real macOS 13 launch or runtime result is reported yet.
- Codex Desktop or Codex CLI previously used by the same macOS account.
- `~/.codex/state_5.sqlite` in a schema supported by this version.
- The Codex desktop application for return-to-task deep links.
- A compatible, signed-in Codex CLI only for the optional remote Wingman
  critique; the dashboard does not require it.

AiWingman is an unofficial local integration. Codex may change its local schema or deep-link contract; incompatible versions fail neutrally instead of attempting to repair Codex data. The optional remote critique uses the user's existing Codex CLI account and may consume that account's plan or quota; AiWingman itself is free and does not sell a subscription.

## Source-build hold

No tagged source build is currently recommended. Do not build or run
`v1.2.0-beta.2`. The hardened checkpoint `99faac3ef52d0da72d082706f64903a6aacd2c6d`
is published for technical audit and exact-commit CI evidence, not as a supported
installation release. Wait for a later release page that explicitly states that
its tag supersedes beta2 and has passed the final source gate. Do not treat a
moving development branch or an automatic GitHub source archive as an installer.

AiWingman deliberately retains the legacy `ActivityRadar` executable, bundle
identifiers, preference keys, and application-support path so existing Activity
Radar users keep their data. These are compatibility identifiers, not a second
application.

For a supported signed download, follow [INSTALL.md](INSTALL.md). GitHub's automatic source archives and a locally ad-hoc-signed app are not installers.

AiWingman is an `LSUIElement` menu-bar app, so it does not appear in the
Dock after launch. Look for its radar icon in the menu bar, or press `⌘⇧K` to
show the panel.

## Task-text-free diagnostics

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
- a release-bound, fixed-schema acceptance record with no task text or raw task
  identifiers for clean arm64 and x86_64
  installs, including a real macOS 13.x runtime result, before publication.

Credentials are read from a `notarytool` Keychain profile; passwords and API private keys are never accepted on the command line. See [Packaging/DISTRIBUTION.md](Packaging/DISTRIBUTION.md).

## Contributing

Bug reports, privacy reviews, accessibility improvements, documentation, deterministic tests, and focused code changes are welcome. All examples and screenshots must be synthetic. Start with [CONTRIBUTING.md](CONTRIBUTING.md), follow [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md), and report vulnerabilities through [SECURITY.md](SECURITY.md).

The software source, tests, scripts, and executable tooling are available under
the [MIT License](LICENSE). The manuscript, generated scholarly outputs, and
specified non-executable research package are available under CC BY 4.0; the
exact file-level map is in [paper/LICENSE_STATUS.md](paper/LICENSE_STATUS.md).
Asset provenance is documented in [ASSET_NOTICES.md](ASSET_NOTICES.md), and
research use can cite [CITATION.cff](CITATION.cff).

## Research boundary

AiWingman is an open-source software artifact; its technical tests do not prove faster resumption, lower cognitive load, scientific novelty, or superiority. See [docs/RESEARCH_BOUNDARY.md](docs/RESEARCH_BOUNDARY.md).

AiWingman is an independent community project. It is not an official OpenAI product and is not endorsed or supported by OpenAI.
