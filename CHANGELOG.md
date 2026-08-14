# Changelog

All notable public changes to Activity Radar are documented here. The format follows Keep a Changelog and public tags use Semantic Versioning prerelease identifiers.

Earlier pre-public development history has not been reconstructed.

## [Unreleased]

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
