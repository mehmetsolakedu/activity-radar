# Install AiWingman on macOS

## Release status

[`v1.2.0-beta.2`](https://github.com/mehmetsolakedu/activity-radar/releases/tag/v1.2.0-beta.2) is the current free, source-only community beta. It has no prebuilt app. GitHub's automatic “Source code” archives are source code, not macOS installers.

## Requirements

- macOS 13 or newer.
- Codex Desktop or Codex CLI previously used by the same macOS account.
- Codex Desktop to open the selected task through the local deep link.
- No AiWingman account, separate API-key request or storage, OAuth flow, or plugin.
- A compatible, separately installed and signed-in Codex CLI is required only
  for the optional remote Wingman critique. The dashboard works without it.
  Remote calls can consume the user's existing Codex plan or quota.

## Build the current source beta

Install Xcode or a compatible Swift toolchain with the macOS SDK, then build the
exact release tag rather than a moving branch:

```sh
git clone https://github.com/mehmetsolakedu/activity-radar.git
cd activity-radar
git switch --detach v1.2.0-beta.2
swift test
swift run ActivityRadarSelfTest
./scripts/package-app.sh --mode local --output-app "$PWD/AiWingman.app"
open "$PWD/AiWingman.app"
```

This local build is for the Mac that built it. Do not redistribute the resulting
ad-hoc-signed bundle as if it were a publisher-signed download. AiWingman is a
menu-bar app; after launch use the radar icon or press `⌘⇧K`.

## Future signed downloads

The sections below apply only if a later release explicitly includes a
Developer ID-signed and Apple-notarized app. The current beta does not.

## Verify the download

Download `SHA256SUMS` alongside the DMG or ZIP. In Terminal, run the command for the file you downloaded:

```sh
shasum -a 256 "<downloaded-file>.dmg"
shasum -a 256 "<downloaded-file>.zip"
```

The printed digest must exactly match that asset's line in `SHA256SUMS`. The release page must also include `RELEASE-MANIFEST.txt` and a clean-machine acceptance JSON file. Stop if a digest differs, an expected file is absent, or the release does not explicitly say it is signed and notarized.

## Install from the DMG (recommended)

1. Open the verified `.dmg` file.
2. Drag **AiWingman** to the **Applications** link in the disk image.
3. Eject the disk image in Finder.
4. Open `/Applications/AiWingman.app`.

Keep browser quarantine intact so macOS can perform its normal Gatekeeper check. Do not run the app directly from the disk image.

## Install from the ZIP (alternative)

1. Expand the verified `.zip` file.
2. Move **AiWingman.app** into `/Applications`.
3. Open it from Applications, not from Downloads.

The ZIP is an alternative transport for the same signed and notarized app. The DMG remains the recommended download.

## First launch

AiWingman is a menu-bar app (`LSUIElement`), so it does not appear in the Dock. After opening it, look for the radar icon in the menu bar or press `⌘⇧K` to show the panel. The first return-to-task action may ask macOS to confirm that Codex Desktop may be opened.

Use the compact **TR/EN** control in the search header to switch the dashboard,
editor, status menu, and Wingman interface instantly. AiWingman remembers
the choice locally for the next launch.

If AiWingman cannot find compatible local Codex state, it stops neutrally. It
does not issue SQL writes, repair schemas, upload Codex data, or intentionally
modify Codex records or rollouts. SQLite may create or update an auxiliary
`-shm` file for WAL coordination, and that file may persist, as disclosed in
[PRIVACY.md](PRIVACY.md).

**Bir Wingman Çağır** can start an optional remote critique. It first displays
the exact user-derived JSON packet that AiWingman intends to supply to the Codex CLI and
requires one-shot consent; no call runs in the background. Prompt excerpts are
excluded by default. The CLI's read-only sandbox prevents writes but does not
guarantee that the child cannot read another local file, so the preview is not a
claim that the packet is the process's only technically accessible context. Read
[PRIVACY.md](PRIVACY.md) before consenting.

## Permissions and privacy

AiWingman reads the current user's local Codex state and stores its own continuity data under the legacy compatibility path `~/Library/Application Support/Activity Radar`. Full Disk Access, Accessibility, Screen Recording, and administrator access are not required. The dashboard requires no network connection; the optional remote critique uses the separately installed, signed-in Codex CLI after consent. Do not grant an unexpected broad permission; stop and report it through [SECURITY.md](SECURITY.md).

See [PRIVACY.md](PRIVACY.md) for the complete data boundary. Never attach `~/.codex`, a Codex database, rollout files, or screenshots of real tasks to an issue.

## Update

1. Quit AiWingman from its status menu.
2. Download and verify the new release exactly as above.
3. Drag the new app into Applications and choose **Replace** when Finder asks.
4. Open the new copy and confirm its version in **About AiWingman…**.

Replacing the app preserves AiWingman's separate continuity data. The legacy `ActivityRadar` bundle identifiers and storage path are intentionally retained for compatibility. A release migration must not issue SQL writes or intentionally alter Codex records, schemas, rollouts, the main database, or its WAL. SQLite's documented WAL `-shm` coordination exception still applies.

## Uninstall

1. Quit AiWingman.
2. Move `/Applications/AiWingman.app` to the Trash.
3. Optional: remove only AiWingman's legacy-compatible local data at `~/Library/Application Support/Activity Radar` and the preference file belonging to the distribution you used: `~/Library/Preferences/io.github.mehmetsolakedu.ActivityRadar.plist` for a signed public build or `~/Library/Preferences/local.mehmet.activityradar.plist` for a local build. If you used both distributions, remove both preference files only after quitting both copies.

Do not delete or edit `~/.codex`; it belongs to Codex, not AiWingman.

## Safe troubleshooting

- Confirm that you launched the copy in Applications and look for the menu-bar icon or press `⌘⇧K`.
- Confirm that Codex has previously been used by the same macOS account.
- If only the optional critique is unavailable, verify `codex --version` and
  `codex login status`, then use **Codex CLI'yi yeniden denetle** in the Wingman
  sheet. The dashboard remains available without the CLI.
- Compare the downloaded checksum again and read the release's known limitations.
- Share only the content-free diagnostics or copied support information requested by the issue form.

Do not disable Gatekeeper, remove quarantine with `xattr -dr`, use `sudo`, re-sign the app, or upload private Codex files to make an unverified download run. If macOS rejects a supported release, stop and report the exact public release tag plus the content-free error.

## Build from source

Source builds are for development on the machine that builds them and use an ad-hoc signature by default. Follow the exact-tag instructions in [README.md](README.md); an ad-hoc local build is not a supported public binary release.
