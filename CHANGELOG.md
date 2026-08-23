# Changelog

All notable public changes to AiWingman are documented here. The format follows Keep a Changelog and public tags use Semantic Versioning prerelease identifiers.

Earlier pre-public development history has not been reconstructed.

## [1.2.0-beta.2] - 2026-08-23

### Added

- An optional Codex CLI Wingman critique for prompting, harness scope,
  unfinished work, and token-review candidates. Every call is user-triggered,
  shows the exact intended JSON packet, requires one-shot consent, and keeps
  prompt excerpts separately off by default; no call runs in the background.
- A persistent, instant TR/EN interface selector for the dashboard, editor,
  status menu, and Wingman sheet.
- The public-facing product name AiWingman. Legacy ActivityRadar identifiers
  and the existing application-support path remain unchanged for data continuity.

### Changed

- Public privacy, security, installation, support, and release contracts now
  distinguish the offline dashboard from the optional remote Wingman boundary.
  They also document the temporary opaque authentication copy and that read-only
  CLI sandboxing is not a sole-context guarantee.
- Spawned task counters are no longer added together: each task tree now uses
  its largest observed cumulative counter as a comparison proxy. The interface
  states that this is neither exact billed usage nor an exact waste total.
- The Wingman sheet hides the local CLI path, normalizes internal goal titles,
  distinguishes scoped, locally analyzed, and remotely detailed task counts,
  and provides bounded cancellation feedback.
- With prompt-content sharing off, the remote packet now removes prompt-derived
  themes and local text signals as well as raw excerpts; isolated CLI runs copy
  authentication only and do not copy user rules or configuration.
- Public packaging now binds every binary to an exact clean Git tag, source
  revision, Apple Team ID, and prerelease-aware artifact name.
- Notarization credentials are checked before the build, both Apple submission
  logs must report no issues, and release checksums also cover the provenance
  manifest.
- A credential-free publisher independently re-verifies tagged artifacts,
  creates an immutable-ready draft, and exposes a separate explicit finalizer
  that rechecks the same remote bytes after clean-machine acceptance.
- Public packaging now builds from an immutable tagged-source snapshot, accepts
  both valid empty notarization-log forms, removes notarization UUIDs from public
  metadata, and binds a canonical metadata-free ZIP plus an exact single-volume
  UDZO/GUID/HFS+ DMG topology to the signed app before a draft can be created.
- CI uses an explicit Apple Silicon image and runs the core contracts and
  standard tests natively on an Intel macOS runner as a separate gate.
- Installable release notes now have a fail-closed end-user contract, with
  English and Turkish installation, update, removal, and safe troubleshooting
  guidance.
- Final publication now requires a canonical content-free acceptance record
  bound to the GitHub release ID, creation time, and DMG digest, with clean
  arm64 and x86_64 results and at least one real macOS 13.x runtime check. The
  immutable release carries that record as its fifth verified asset.
- The status menu now shows content-free version/provenance information and can
  copy a constrained support summary without task identifiers, titles, paths,
  or authored text. Its About view states that AiWingman is an independent
  community project and not an official OpenAI product.

### Distribution

- This prerelease is free and source-only. It contains no prebuilt macOS app.
- The dashboard is offline; the optional remote Wingman critique can consume
  the user's existing Codex plan or quota.

## [1.2.0-beta.1] - 2026-08-14

### Added

- Native macOS menu-bar dashboard for top-level local Codex tasks.
- Read-only Codex SQLite/JSONL adapter and exact-task deep-link navigation.
- Conservative attention and lifecycle status with explicit uncertainty.
- Explainable continuity triage, abstention, snooze/waiting suppression, and reversible lifecycle decisions.
- Local continuity capsules and an optional, content-free research ledger.
- MIT license, community contribution guidance, code of conduct, security policy, and support boundary.
- Privacy-aware issue and pull-request templates.
- Deterministic macOS CI covering standard tests, executable contracts, diagnostic privacy, store privacy/retention, release build, and Universal 2 packaging.
- Fail-closed Developer ID and Apple notarization packaging path for a future binary release.

### Security

- No network client or telemetry.
- Codex state is opened read-only and never modified.
- Public source is produced from an explicit file manifest that excludes real task screenshots, local build products, and private QA evidence.

### Distribution

- This prerelease is source-only. It does not contain a Developer ID–signed or Apple-notarized binary.
