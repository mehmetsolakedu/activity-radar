# Privacy

AiWingman is a local, unofficial companion for Codex on macOS. It does not ask for, store, or manage a separate OpenAI API key; it reuses the saved authentication mechanism of the user's separately installed and signed-in Codex CLI without parsing it. AiWingman does not sign in to an AiWingman service, send analytics, or start an agent call in the background. The optional Wingman review sends its task packet only after explicit consent. A separate CLI compatibility check runs only after an explicit **Check Codex CLI** action, as described below.

## Data it reads

AiWingman reads the current macOS user's local Codex state under `~/.codex`:

- `state_5.sqlite`
- `goals_1.sqlite`, when present
- `session_index.jsonl`, when present
- rollout JSONL files referenced by the local Codex database

SQLite is opened with `SQLITE_OPEN_READONLY` and `PRAGMA query_only=ON`, and
AiWingman issues no SQL writes to Codex records or schema. SQLite's own VFS may
nevertheless create or update an auxiliary `state_5.sqlite-shm` or
`goals_1.sqlite-shm`
under `~/.codex` when coordinating a database in WAL mode. AiWingman does not
intentionally create or modify Codex records, rollout files, the main database,
or its WAL. The `-shm` file may persist according to the SQLite/Codex lifecycle.
This narrow SQLite auxiliary-file behavior is why this policy does not claim
that the whole Codex state directory is immutable.

## Data it stores

AiWingman stores its own preferences outside `~/.codex`:

- macOS `UserDefaults`: last-viewed timestamps, the identifier and timestamp of
  the last task whose open request macOS accepted,
  date range, interface language, and explicit lifecycle choices.
- `~/Library/Application Support/Activity Radar`: the legacy compatibility path for local continuity plans, a pseudonym salt, and—only when the user opts in—the research ledger.

Continuity files use a salted pseudonym instead of a raw Codex task identifier. Human-authored checkpoint, next-action, and waiting-on text stays in the local continuity file and is never included in the research ledger.

## Network behavior

The dashboard, continuity features, diagnostics, and research ledger contain no
network client and make no network request. Opening
`codex://threads/<id>` hands a local URL to macOS; the separately installed Codex
application decides how to handle it and has its own privacy behavior.

The optional **Codex Wingman review** is a separate, user-triggered boundary. It
uses a compatible Codex CLI already installed and signed in by the same macOS
user. Before every invocation, AiWingman makes the exact user-derived JSON
packet it intends to supply on stdin available for inspection, including task,
theme, prompt-excerpt, and UTF-8 byte counts, and requires one-shot consent.
Consent is cleared after the attempt and
whenever the scope or prompt-sharing choice changes. Prompt excerpts,
prompt-derived themes, and local text signals are all excluded by default and
require the same separate toggle. With that toggle off, task-derived free text
is limited to sanitized titles; prompt excerpts, prompt-derived themes, local
review signals, and next-move text are omitted. The packet still contains
timestamps and the activity cutoff, status/enumeration fields, booleans, counts,
numeric measurements, schema/language metadata, and a fixed method-boundary
string. No Wingman call runs in the background.

Opening the Wingman sheet does not invoke Codex CLI. The separate explicit
**Check Codex CLI** action runs signed-executable, version, command-compatibility,
and login-status checks. It does not start an agent turn or send an AiWingman
task packet. The check does create a private temporary Codex home containing an
opaque copy of the validated saved authentication file; the CLI's own behavior
during these commands is not represented as network non-interference. The same
cleanup, residue, and process-wide operation boundaries below apply.

The packet excludes raw task identifiers, full paths, working and rollout paths,
git and account metadata, system and developer instructions, and tool outputs.
The local analysis can select up to 20 task trees; the bounded remote packet
carries detailed rows for at most the 12 busiest selected trees and states the
selected, detailed, and omitted-detail counts.

After consent, the packet is processed through Codex/OpenAI. AiWingman
invokes the CLI directly without a shell, with approval disabled, an ephemeral
turn, ignored user configuration, and a request for read-only sandbox mode. Only the validated
authentication file is copied into the isolated Codex home; user rules and
configuration files are not copied. It rejects unknown
or tool events and bounds packet size, output, and execution time. These controls
limit the intended invocation. The requested read-only mode is intended to deny
agent-tool writes to the workspace; it is neither OS-level isolation nor a zero-
filesystem-write guarantee, and it does not prove that the child process cannot
read another local file. The exact
preview is exact for the user-derived stdin packet AiWingman intentionally
supplies; the fixed instruction and schema are separately documented below. It
is not a claim that this is the only context technically accessible to the CLI. Do not use
the remote review if that residual local-read boundary is unacceptable.

Before launch, AiWingman validates the saved Codex authentication file's
metadata and makes an opaque temporary copy in an isolated Codex home. The
temporary directory and file use private permissions. Cleanup is attempted
after every normal result or error and absence is checked. If absence cannot be
verified, the result is rejected and the current app process blocks later
remote calls until cleanup succeeds. Only one remote Wingman operation may use
the temporary-auth lifecycle at a time. A crash or forced termination can still
leave an `ActivityRadar-Wingman-` or `ActivityRadar-CLI-Probe-` temporary
directory. Quit the app, inspect only immediate children of the current user's
macOS temporary directory with either exact prefix, remove only those residue
directories, and then reopen; never delete a broader temporary path. AiWingman
does not parse the credential contents or include them in the packet,
diagnostics, or logs. The CLI's `--ephemeral` option requests a turn intended
not to save a local rollout; it does not prove that no local artifact exists
and does not define service-side data retention.

The user-derived JSON packet is processed together with the fixed reviewer
instruction and output schema shipped in the source. Those fixed texts contain
no task data. The remote call can consume the user's existing Codex plan or
quota; AiWingman charges no separate fee.

The agent result remains in the current app view. AiWingman does not start
a later or background call from that result.

## Optional research ledger

Research logging is off by default. If enabled, each local event contains only:

- a salted task pseudonym;
- an event kind;
- a timestamp;
- a fixed experimental condition.

The ledger is limited to 90 days or 10,000 events. Export is manual and requires
a fixed-schema preview followed by a separate confirmation. The export contains
pseudonyms, timestamps, event kinds, and condition values, but excludes task
titles, prompts, messages, paths, raw task identifiers, checkpoints, next
actions, and waiting-on text.

## Diagnostics

`swift run ActivityRadarDiagnostics` emits aggregate compatibility counts only. It excludes task identifiers, titles, messages, paths, and checkpoints. Do not attach files from `~/.codex` to a public issue.

The status menu's **Destek Bilgisini Kopyala** action is fixed-schema and
task-text-free. It
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

The direct-download build is intentionally not App Sandbox–restricted because it must read the hidden `~/.codex` directory. AiWingman's SQL access is read-only/query-only, subject to SQLite's WAL `-shm` coordination behavior documented above. The app does not request Full Disk Access, Contacts, Calendar, Photos, microphone, camera, or location. The optional child CLI boundary is described separately above and is not represented as a guarantee that the child cannot read other local files.

## Removing local data

Deleting the app does not automatically delete its local continuity data. To remove all AiWingman data, quit the app and delete:

- `~/Library/Application Support/Activity Radar`
- the preferences domain belonging to the distribution that was used:
  `io.github.mehmetsolakedu.ActivityRadar` for a signed public build and
  `local.mehmet.activityradar` for a local, pre-public-compatible build

If both distributions were used, quit both copies before removing both
preference domains. These paths contain AiWingman data only; do not delete
`~/.codex`.

Security concerns can be reported using the private process in [SECURITY.md](SECURITY.md).
