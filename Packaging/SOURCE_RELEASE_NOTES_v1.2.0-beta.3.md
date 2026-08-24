# DRAFT — AiWingman v1.2.0-beta.3 source-only candidate

> Do not publish or treat this file as current release instructions until the
> protected `v1.2.0-beta.3` tag exists at the final clean, CI-passing checkpoint.

AiWingman is a free, open-source macOS menu-bar companion for reviewing
continuity evidence across parallel Codex tasks. This candidate is intended to
supersede `v1.2.0-beta.2`, which must not be built or used.

## Release status

This prerelease is **source-only**. It contains no prebuilt `.app`, DMG, or ZIP.
GitHub's automatic source archives are source code, not macOS installers. The
annotated release tag is protected against update and deletion by repository
rules but is not cryptographically signed.

## Build the exact source tag

Use a current Xcode installation or compatible Swift toolchain with the macOS
SDK. The package declares macOS 13 as its deployment target, but recorded builds
and tests ran on later macOS versions; no real macOS 13 launch/runtime result is
claimed.

```sh
git clone https://github.com/mehmetsolakedu/activity-radar.git
cd activity-radar
git fetch --tags --force
git switch --detach v1.2.0-beta.3
test "$(git describe --exact-match --tags HEAD)" = "v1.2.0-beta.3"
test -z "$(git status --porcelain)"

command -v rg sqlite3 python3
./scripts/run-swift-tests.sh
swift run ActivityRadarSelfTest
./scripts/package-app.sh --mode local --output-app "$PWD/AiWingman.app"
open "$PWD/AiWingman.app"
```

The locally built app is ad-hoc signed for use on the Mac that built it. Do not
redistribute it as a publisher-signed or Apple-notarized download. AiWingman is
an `LSUIElement` menu-bar app and does not appear in the Dock.

The enforced test/release gate has command-line prerequisites: `rg` (ripgrep),
`sqlite3`, and `python3`. Maintainers should confirm all three are on `PATH`
before running it:

```sh
command -v rg sqlite3 python3
REQUIRE_STANDARD_TESTS=1 ./scripts/public-release-check.sh
```

## Security and privacy boundary

- The dashboard makes no network request and starts no background agent call.
- AiWingman issues no SQL write to Codex records or schema. SQLite WAL
  coordination may nevertheless create or update an auxiliary `-shm` file under
  `~/.codex`.
- Later hardening bounds and contains rollout/session-index reads and verifies
  normal/error temporary-auth cleanup. A crash or forced termination can still
  leave a documented prefixed temporary directory.
- Optional Wingman review requires a separately installed, signed-in Codex CLI,
  makes the complete intended user-derived JSON packet available for inspection
  in a collapsed disclosure control, and requires one-shot consent. The fixed
  instruction and schema contain no task data.
- With prompt content off, task-derived free text is limited to sanitized titles;
  prompt excerpts, prompt-derived themes, local review signals, and next-move
  text are omitted. The packet still carries timestamps/activity cutoff,
  status/enumeration fields, booleans, counts, numeric measurements,
  schema/language metadata, and a fixed method-boundary string.
- Sanitization is best effort. AiWingman requests Codex CLI read-only sandbox
  mode, intended to deny agent-tool writes to the workspace; this is not OS-
  level isolation or a zero-filesystem-write guarantee and does not prove that
  no other local file can be read. `--ephemeral` requests a
  turn intended not to save a local rollout; it does not prove absence of local
  artifacts or define service-side retention.

## Evidence and claim boundary

The exact source checkpoint must pass non-zero standard-test discovery,
deterministic self-tests, the frozen 155-fixture policy benchmark, public-source
manifest equality, and fail-closed privacy fixtures before this release is
published. Those checks are engineering and synthetic-contract evidence. They
do not establish human productivity, task-selection quality, external
validation, exact billed or wasted tokens, security isolation, broad
cross-machine determinism, or real macOS 13 runtime compatibility.

## Known limitations

- Codex local storage and deep-link behavior are unofficial compatibility
  boundaries and may change.
- The tree-level cumulative counter is a comparison proxy, not exact cost,
  period usage, effort, usefulness, or waste.
- There is no one-click signed/notarized public installer in this release.

## Documentation, citation, and contribution

Read the tag-pinned [installation](https://github.com/mehmetsolakedu/activity-radar/blob/v1.2.0-beta.3/INSTALL.md),
[privacy](https://github.com/mehmetsolakedu/activity-radar/blob/v1.2.0-beta.3/PRIVACY.md),
[security](https://github.com/mehmetsolakedu/activity-radar/blob/v1.2.0-beta.3/SECURITY.md),
and [contribution](https://github.com/mehmetsolakedu/activity-radar/blob/v1.2.0-beta.3/CONTRIBUTING.md)
documents. Citation metadata is in `CITATION.cff`. Use only synthetic or redacted
evidence in public issues and pull requests; never upload Codex databases,
rollout files, authentication files, packet previews, or real-task screenshots.
