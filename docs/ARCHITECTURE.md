# Architecture

Activity Radar is a native Swift/AppKit/SwiftUI menu-bar application with no service component.

## Components

- `ActivityRadarCore`: read-only Codex adapters, rollout reduction, attention/lifecycle policy, and deterministic continuity triage.
- `ActivityRadar`: menu-bar and command-palette UI, local preferences, continuity storage, and deep-link navigation.
- `ActivityRadarDiagnostics`: content-free compatibility report.
- `ActivityRadarSelfTest`: deterministic executable contract tests available even when XCTest discovery is unavailable.

## Trust boundaries

1. `~/.codex` is an external, read-only input owned by Codex.
2. `~/Library/Application Support/Activity Radar` is Activity Radar–owned mutable state.
3. `UserDefaults` contains local navigation and explicit lifecycle preferences.
4. A `codex://` URL is handed to macOS only after a user opens a task.
5. There is no Activity Radar network boundary because the app has no network client.

## Conservative inference

Inactivity is not treated as execution, abandonment, or obsolescence. Incomplete history produces uncertainty. High-impact lifecycle states such as obsolete or abandoned require an explicit, reversible user decision. Continuity ranking exposes its evidence and returns no ranked candidates when it abstains.

## Storage safety

The continuity store rejects any storage root under `~/.codex`, writes its directory and files with `0700`/`0600` permissions, pseudonymizes task identifiers, and bounds the optional ledger by both age and count.
