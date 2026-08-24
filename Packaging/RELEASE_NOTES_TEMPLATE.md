# AiWingman REPLACE_WITH_RELEASE_TAG

## Release status

This is a Developer ID-signed and Apple-notarized installable public beta.

Historical note: v1.2.0-beta.1 is source-only and contains no installable binary.

## Requirements

- The package declares macOS 13 as its deployment target. State the exact tested
  runtime versions in each release; do not imply real macOS 13 runtime evidence
  unless clean-machine acceptance actually records it.
- Codex Desktop or Codex CLI previously used by the same macOS account.
- Codex Desktop for return-to-task links.
- A compatible, separately installed and signed-in Codex CLI only for the
  optional remote Wingman critique; the dashboard does not require it.

## Install

The DMG is the recommended download. Verify it, open it, drag AiWingman to Applications, eject the disk image, and launch the copy in Applications. The ZIP is an alternative transport for the same signed app.

## Verify

Compare the downloaded file's SHA-256 digest with `SHA256SUMS`. Stop if it differs or if `RELEASE-MANIFEST.txt` is absent.

During maintainer-only draft testing, the clean-machine acceptance asset is intentionally absent while the four base assets—the DMG, ZIP, `SHA256SUMS`, and `RELEASE-MANIFEST.txt`—are tested.

For a published release, the clean-machine acceptance asset listed below is mandatory; stop if it is absent.

## First launch

AiWingman appears in the menu bar, not the Dock. Use the radar item or press `⌘⇧K` to show the panel.

The optional remote Wingman critique makes the exact JSON packet AiWingman
intends to supply available for inspection and requires one-shot consent before every call; no call
runs in the background and prompt excerpts are off by default.

## Changes

- The dashboard and status menu can switch instantly between Turkish and English, and the selection persists across launches.
- REPLACE_WITH_CONCISE_USER_VISIBLE_CHANGE

## Known limitations

- REPLACE_WITH_RELEASE_SPECIFIC_LIMITATION

## Privacy, support, update, and removal

Full Disk Access is not required. AiWingman has no telemetry; its dashboard makes no network request and issues no SQL write to Codex records or schema. SQLite WAL coordination may nevertheless create or update an auxiliary `-shm` file under `~/.codex`. Opening Wingman does not invoke Codex CLI; a separate explicit compatibility check uses a private temporary opaque copy of saved CLI authentication without starting an agent turn or sending a task packet. The optional remote critique uses the separately installed, signed-in Codex CLI only after access to the exact intended JSON preview and one-shot consent. Normal completion and error paths attempt cleanup and verify absence; a crash or forced termination can leave a prefixed temporary directory that must be handled as documented in the pinned security guidance. AiWingman requests Codex CLI read-only sandbox mode, intended to deny agent-tool writes to the workspace. This is neither OS-level isolation nor a zero-filesystem-write guarantee, and it does not prove that other local files cannot be read, so the previewed packet is not a sole-context guarantee. Follow the pinned installation document for safe updates and removal; never attach Codex databases, rollout files, preview packets, `auth.json`, or real-task screenshots to an issue.

- Installation: https://github.com/mehmetsolakedu/activity-radar/blob/REPLACE_WITH_RELEASE_TAG/INSTALL.md
- Privacy: https://github.com/mehmetsolakedu/activity-radar/blob/REPLACE_WITH_RELEASE_TAG/PRIVACY.md
- Security: https://github.com/mehmetsolakedu/activity-radar/blob/REPLACE_WITH_RELEASE_TAG/SECURITY.md

## Release assets

- Recommended download: `REPLACE_WITH_DMG_ASSET_NAME`
- Alternative download: `REPLACE_WITH_ZIP_ASSET_NAME`
- Checksums: `SHA256SUMS`
- Build and signing provenance: `RELEASE-MANIFEST.txt`
- Clean-machine acceptance: `REPLACE_WITH_ACCEPTANCE_ASSET_NAME`
