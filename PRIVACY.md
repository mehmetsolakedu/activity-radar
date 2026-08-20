# Privacy

Activity Radar is a local, unofficial companion for Codex on macOS. It does not use an OpenAI API key, sign in to an Activity Radar service, or send analytics.

## Data it reads

Activity Radar reads the current macOS user's local Codex state under `~/.codex`:

- `state_5.sqlite`
- `goals_1.sqlite`, when present
- `session_index.jsonl`, when present
- rollout JSONL files referenced by the local Codex database

SQLite is opened with `SQLITE_OPEN_READONLY` and `PRAGMA query_only=ON`. Activity Radar has no code path that writes to `~/.codex`.

## Data it stores

Activity Radar stores its own preferences outside `~/.codex`:

- macOS `UserDefaults`: last-viewed timestamps, the last opened task identifier, date range, and explicit lifecycle choices.
- `~/Library/Application Support/Activity Radar`: local continuity plans, a pseudonym salt, and—only when the user opts in—the research ledger.

Continuity files use a salted pseudonym instead of a raw Codex task identifier. Human-authored checkpoint, next-action, and waiting-on text stays in the local continuity file and is never included in the research ledger.

## Network behavior

Activity Radar contains no network client and makes no network request. Opening `codex://threads/<id>` hands a local URL to macOS; the separately installed Codex application decides how to handle it and has its own privacy behavior.

## Optional research ledger

Research logging is off by default. If enabled, each local event contains only:

- a salted task pseudonym;
- an event kind;
- a timestamp;
- a fixed experimental condition.

The ledger is limited to 90 days or 10,000 events. Export is manual and requires a content-free preview followed by a separate confirmation. The export excludes task titles, prompts, messages, paths, checkpoints, next actions, and waiting-on text.

## Diagnostics

`swift run ActivityRadarDiagnostics` emits aggregate compatibility counts only. It excludes task identifiers, titles, messages, paths, and checkpoints. Do not attach files from `~/.codex` to a public issue.

The status menu's **Destek Bilgisini Kopyala** action is also content-free. It
contains only the app version/build, an allowlisted release tag, the first 12
hex characters of the packaged source revision, the running architecture, and
the macOS version/build. Unexpected or content-bearing bundle metadata is
replaced with a neutral “atanmamış” or “bilinmiyor” value. It never includes a
task identifier, title, prompt, message, path, checkpoint, or next action.

Clean-machine release acceptance is a separate public JSON asset with a closed
schema. It contains the public repository, tag, release ID, DMG name/digest,
architecture, macOS version/build, UTC test time, and fixed boolean outcomes.
There is no tester, device, user, path, note, or free-text field.

## Permissions and sandboxing

The direct-download build is intentionally not App Sandbox–restricted because it must read the hidden `~/.codex` directory. This access is read-only. The app does not request Full Disk Access, Contacts, Calendar, Photos, microphone, camera, or location.

## Removing local data

Deleting the app does not automatically delete its local continuity data. To remove all Activity Radar data, quit the app and delete:

- `~/Library/Application Support/Activity Radar`
- the `io.github.mehmetsolakedu.ActivityRadar` preferences domain

These paths contain Activity Radar data only; do not delete `~/.codex`.

Security concerns can be reported using the private process in [SECURITY.md](SECURITY.md).
