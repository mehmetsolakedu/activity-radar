# Architecture

AiWingman is a native Swift/AppKit/SwiftUI menu-bar application with no service component.

## Components

- `ActivityRadarCore`: query-only Codex SQL adapters, bounded Wingman evidence
  extraction, deterministic task/theme analysis, rollout reduction,
  attention/lifecycle policy, and continuity triage.
- `ActivityRadar`: menu-bar and command-palette UI, local preferences,
  continuity storage, deep-link navigation, and the optional Codex CLI process
  boundary.
- `ActivityRadarDiagnostics`: content-free compatibility report.
- `ActivityRadarSelfTest`: deterministic executable contract tests available even when XCTest discovery is unavailable.

## Trust boundaries

1. `~/.codex` is external state owned by Codex. AiWingman issues no SQL writes
   and does not intentionally modify Codex records, schema, rollouts, the main
   database, or its WAL. SQLite's VFS may create or update an auxiliary `-shm`
   file for WAL coordination, and that file may persist according to the
   SQLite/Codex lifecycle, so this is not a whole-directory immutability claim.
2. `~/Library/Application Support/Activity Radar` is AiWingman-owned mutable state retained at its legacy path for compatibility.
3. `UserDefaults` contains local navigation, interface-language, and explicit
   lifecycle preferences.
4. A `codex://` URL is handed to macOS only after a user opens a task.
5. Dashboard analysis is offline and starts no background agent call.
6. The optional remote Wingman review is a distinct, user-triggered boundary:
   AiWingman shows the exact user-derived JSON packet it intends to supply,
   documents the fixed review instruction and output schema, requires one-shot
   consent, and invokes a separately installed and signed-in Codex CLI.
7. The child CLI uses read-only sandboxing, but this blocks writes rather than
   proving that no other local file can be read. The previewed packet is not a
   sole-context guarantee.
8. The saved Codex authentication file is copied opaquely into a private
   temporary CLI home. Normal completion and error paths attempt cleanup and
   verify absence; an unverified cleanup rejects the result and latches later
   remote calls in the current process. A process-wide gate allows only one
   such remote lifecycle at a time. Crash residue remains possible under the
   two temporary-directory prefixes documented in `SECURITY.md`.

## Wingman analysis boundary

The evidence reader opens Codex SQLite with read-only flags and query-only SQL,
subject to the WAL `-shm` behavior above, and resolves a defensive
parent/child forest from one read transaction. Spawned rollout files carry a
shared cumulative token-counter lineage, so root and descendant counters are
not additive. AiWingman ranks each tree by its largest observed cumulative
counter and labels that value as a comparison proxy, not an exact billed or
wasted-token total. The date control selects trees by latest activity; it does
not convert this lifetime counter proxy into a period total. Bounded rollout
sampling marks incomplete evidence as partial rather than silently treating it
as complete.

Task and theme relationships use deterministic text features. Derived activity,
similarity, weighted-degree, PageRank, and connected-component values are
descriptive signals, not task success, effort, personality, or exact token-waste
measurements.

## Conservative inference

Inactivity is not treated as execution, abandonment, or obsolescence. Incomplete history produces uncertainty. High-impact lifecycle states such as obsolete or abandoned require an explicit, reversible user decision. Continuity ranking exposes its evidence and returns no ranked candidates when it abstains.

## Storage safety

The continuity store rejects any storage root under `~/.codex`, writes its directory and files with `0700`/`0600` permissions, pseudonymizes task identifiers, and bounds the optional ledger by both age and count.
