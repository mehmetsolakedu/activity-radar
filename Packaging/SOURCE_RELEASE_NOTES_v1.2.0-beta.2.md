# AiWingman v1.2.0-beta.2 — Free source-first community beta

> **SUPERSEDED — DO NOT BUILD OR USE THIS TAG.** Later hardening corrected a
> database-controlled rollout-path trust issue, an unbounded session-index read,
> and unverifiable temporary-auth cleanup. Those fixes are not present at commit
> `5e212181ae177cd555ab6bb92f5f71ac8be9173a`, to which the unsigned annotated
> tag currently resolves. Do not use its optional Wingman path or treat hostile local Codex
> state as safely bounded. Wait for a later explicitly supported source release.

> **Post-tag documentation correction.** The `v1.2.0-beta.2` tagged commit and
> its release-page copy used three overbroad descriptions. The package declared a
> macOS 13 deployment target, but no real macOS 13 launch/runtime result was
> recorded. AiWingman issues no SQL write to Codex records, yet SQLite WAL
> coordination may create or update an auxiliary `-shm` file. With prompt content
> disabled, the preview packet is not limited to titles and numeric measurements;
> the exact bounded fields are listed below. This notice was added on the later
> manuscript branch and is not part of the historical tagged commit.

AiWingman is a local-first macOS menu-bar companion for people working across
multiple Codex tasks. The project is free software under the MIT License and
welcomes issues, discussions, tests, documentation, privacy review, and focused
pull requests.

## Release status

This prerelease is **source-only**. It contains no prebuilt `.app`, DMG, or ZIP.
GitHub's automatically generated source archives are source code, not macOS
installers. They identify historical source only; do not build or run this tag.

## Historical build commands — do not run

The superseded package declared macOS 13 as its deployment target, but the recorded builds
and tests ran on later macOS versions; no real macOS 13 launch/runtime result is
reported. Building requires Xcode or a compatible Swift toolchain with the macOS
SDK, and Codex Desktop or Codex CLI previously used by the same macOS account.

```sh
git clone https://github.com/mehmetsolakedu/activity-radar.git
cd activity-radar
git switch --detach v1.2.0-beta.2
swift test
swift run ActivityRadarSelfTest
./scripts/package-app.sh --mode local --output-app "$PWD/AiWingman.app"
open "$PWD/AiWingman.app"
```

These commands are retained only to identify the historical artifact. They are
not an installation recommendation.

The locally built app is ad-hoc signed for use on the machine that built it. Do
not redistribute that bundle as a publisher-signed download.

## What is included

- The original work-continuity dashboard and exact Codex return-to-task flow.
- 24-hour, 7-day, 30-day, 90-day, and all-time ranges.
- Explicit and reversible obsolete and abandoned labels; silence alone is not
  treated as abandonment.
- Instant, persistent Turkish and English interface selection.
- An optional Wingman review for prompting, harness scope, unfinished work, and
  bounded token-review candidates.
- No HTML book/export feature.

## Privacy and cost boundary

The dashboard works locally and makes no network request. AiWingman issues no
SQL write to Codex records or schema, but SQLite WAL coordination may create or
update an auxiliary `state_5.sqlite-shm` or `goals_1.sqlite-shm` file under
`~/.codex`. The optional remote Wingman review requires a separately installed,
signed-in Codex CLI and one-shot consent after the complete user-derived JSON
packet is shown. That packet is processed with a fixed reviewer instruction and
output schema that contain no task data. Prompt excerpts, prompt-derived themes,
and local text signals are off by default. With prompt content off, task-derived
free text is limited to sanitized titles; prompt excerpts, prompt-derived themes,
local review signals, and next-move text are omitted. The packet still contains
timestamps and the activity cutoff, status/enumeration fields, booleans, counts,
numeric measurements, schema/language metadata, and a fixed method-boundary
string. User rules and configuration files are not copied into the isolated CLI
home.

AiWingman itself is free. Optional remote calls can consume the user's existing
Codex plan or quota.

## Known limitations

- There is no one-click public installer in this source-only release.
- Codex local storage and deep-link contracts are unofficial compatibility
  boundaries and may change.
- Token totals are comparison proxies, not exact billing or waste totals.
- Automated and synthetic tests do not establish human productivity,
  prospective-memory, usability, adoption, or real-world effectiveness.

## Contribute safely

The installation, privacy, and security files stored in the tagged commit preserve
the same historical documentation defects noted above. Consult the corrected
[current installation](https://github.com/mehmetsolakedu/activity-radar/blob/codex/aiwingman-technical-preprint/INSTALL.md),
[privacy](https://github.com/mehmetsolakedu/activity-radar/blob/codex/aiwingman-technical-preprint/PRIVACY.md),
[security](https://github.com/mehmetsolakedu/activity-radar/blob/codex/aiwingman-technical-preprint/SECURITY.md),
and [contribution](https://github.com/mehmetsolakedu/activity-radar/blob/codex/aiwingman-technical-preprint/CONTRIBUTING.md)
documents before use. Use only synthetic or redacted evidence in public issues
and pull requests; never upload Codex databases, rollout files, authentication
files, packet previews, or screenshots of real tasks.
