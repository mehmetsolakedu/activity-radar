# Activity Radar REPLACE_WITH_RELEASE_TAG

## Release status

This is a Developer ID-signed and Apple-notarized installable public beta.

Historical note: v1.2.0-beta.1 is source-only and contains no installable binary.

## Requirements

- macOS 13 or newer.
- Codex Desktop or Codex CLI previously used by the same macOS account.
- Codex Desktop for return-to-task links.

## Install

The DMG is the recommended download. Verify it, open it, drag Activity Radar to Applications, eject the disk image, and launch the copy in Applications. The ZIP is an alternative transport for the same signed app.

## Verify

Compare the downloaded file's SHA-256 digest with `SHA256SUMS`. Stop if it differs or if `RELEASE-MANIFEST.txt` is absent.

During maintainer-only draft testing, the clean-machine acceptance asset is intentionally absent while the four base assets—the DMG, ZIP, `SHA256SUMS`, and `RELEASE-MANIFEST.txt`—are tested.

For a published release, the clean-machine acceptance asset listed below is mandatory; stop if it is absent.

## First launch

Activity Radar appears in the menu bar, not the Dock. Use the radar item or press `⌘⇧K` to show the panel.

## Changes

- REPLACE_WITH_CONCISE_USER_VISIBLE_CHANGE

## Known limitations

- REPLACE_WITH_RELEASE_SPECIFIC_LIMITATION

## Privacy, support, update, and removal

Full Disk Access is not required. Activity Radar has no telemetry or network client and never writes to `~/.codex`. Follow the pinned installation document for safe updates and removal; never attach Codex databases, rollout files, or real-task screenshots to an issue.

- Installation: https://github.com/mehmetsolakedu/activity-radar/blob/REPLACE_WITH_RELEASE_TAG/INSTALL.md
- Privacy: https://github.com/mehmetsolakedu/activity-radar/blob/REPLACE_WITH_RELEASE_TAG/PRIVACY.md
- Security: https://github.com/mehmetsolakedu/activity-radar/blob/REPLACE_WITH_RELEASE_TAG/SECURITY.md

## Release assets

- Recommended download: `REPLACE_WITH_DMG_ASSET_NAME`
- Alternative download: `REPLACE_WITH_ZIP_ASSET_NAME`
- Checksums: `SHA256SUMS`
- Build and signing provenance: `RELEASE-MANIFEST.txt`
- Clean-machine acceptance: `REPLACE_WITH_ACCEPTANCE_ASSET_NAME`
