# AiWingman v1.2.0-beta.2 — Free source-first community beta

AiWingman is a local-first macOS menu-bar companion for people working across
multiple Codex tasks. The project is free software under the MIT License and
welcomes issues, discussions, tests, documentation, privacy review, and focused
pull requests.

## Release status

This prerelease is **source-only**. It contains no prebuilt `.app`, DMG, or ZIP.
GitHub's automatically generated source archives are source code, not macOS
installers. Build the exact tag on the Mac where you intend to use it.

## Build and run

Requirements: macOS 13 or newer, Xcode or a compatible Swift toolchain with the
macOS SDK, and Codex Desktop or Codex CLI previously used by the same macOS
account.

```sh
git clone https://github.com/mehmetsolakedu/activity-radar.git
cd activity-radar
git switch --detach v1.2.0-beta.2
swift test
swift run ActivityRadarSelfTest
./scripts/package-app.sh --mode local --output-app "$PWD/AiWingman.app"
open "$PWD/AiWingman.app"
```

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

The dashboard works locally, makes no network request, and never writes to
`~/.codex`. The optional remote Wingman review requires a separately installed,
signed-in Codex CLI and one-shot consent after the complete user-derived JSON
packet is shown. That packet is processed with a fixed reviewer instruction and
output schema that contain no task data. Prompt excerpts, prompt-derived themes, and local text signals are off
by default; with that option off, the packet contains task titles and numeric
measurements only. User rules and configuration files are not copied into the
isolated CLI home.

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

Read the pinned [installation](https://github.com/mehmetsolakedu/activity-radar/blob/v1.2.0-beta.2/INSTALL.md), [privacy](https://github.com/mehmetsolakedu/activity-radar/blob/v1.2.0-beta.2/PRIVACY.md), [security](https://github.com/mehmetsolakedu/activity-radar/blob/v1.2.0-beta.2/SECURITY.md), and [contribution](https://github.com/mehmetsolakedu/activity-radar/blob/v1.2.0-beta.2/CONTRIBUTING.md) documents. Use only synthetic or redacted evidence in public issues and pull requests; never upload Codex databases, rollout files, authentication files, packet previews, or screenshots of real tasks.
