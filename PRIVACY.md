# Privacy

AiWingman is a local, unofficial companion for Codex on macOS. It does not ask for, store, or manage a separate OpenAI API key; it reuses the saved authentication mechanism of the user's separately installed and signed-in Codex CLI without parsing it. AiWingman does not sign in to an AiWingman service, send analytics, or start an agent call in the background. The optional Wingman review uses that CLI only after explicit consent, as described below.

## Data it reads

AiWingman reads the current macOS user's local Codex state under `~/.codex`:

- `state_5.sqlite`
- `goals_1.sqlite`, when present
- `session_index.jsonl`, when present
- rollout JSONL files referenced by the local Codex database

SQLite is opened with `SQLITE_OPEN_READONLY` and `PRAGMA query_only=ON`. AiWingman has no code path that writes to `~/.codex`.

## Data it stores

AiWingman stores its own preferences outside `~/.codex`:

- macOS `UserDefaults`: last-viewed timestamps, the last opened task identifier,
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
user. Before every invocation, AiWingman displays the exact user-derived JSON
packet it intends to supply on stdin, including task, theme, prompt-excerpt, and UTF-8 byte
counts, and requires one-shot consent. Consent is cleared after the attempt and
whenever the scope or prompt-sharing choice changes. Prompt excerpts,
prompt-derived themes, and local text signals are all excluded by default and
require the same separate toggle. With that toggle off, the packet contains task
titles and numeric measurements only. No Wingman call runs in the background.

The packet excludes raw task identifiers, full paths, working and rollout paths,
git and account metadata, system and developer instructions, and tool outputs.
The local analysis can select up to 20 task trees; the bounded remote packet
carries detailed rows for at most the 12 busiest selected trees and states the
selected, detailed, and omitted-detail counts.

After consent, the packet is processed through Codex/OpenAI. AiWingman
invokes the CLI directly without a shell, with approval disabled, an ephemeral
turn, ignored user configuration, and read-only sandboxing. Only the validated
authentication file is copied into the isolated Codex home; user rules and
configuration files are not copied. It rejects unknown
or tool events and bounds packet size, output, and execution time. These controls
limit the intended invocation, but the read-only sandbox prevents writes rather
than proving that the child process cannot read another local file. The exact
preview is exact for the user-derived stdin packet AiWingman intentionally
supplies; the fixed instruction and schema are separately documented below. It
is not a claim that this is the only context technically accessible to the CLI. Do not use
the remote review if that residual local-read boundary is unacceptable.

Before launch, AiWingman validates the saved Codex authentication file's
metadata and makes an opaque temporary copy in an isolated Codex home. The
temporary directory and file use private permissions and are removed after the
attempt. AiWingman does not parse the credential contents or include them
in the packet, diagnostics, or logs. The CLI's `--ephemeral` option avoids
creating a local rollout for this turn; it does not define service-side data
retention.

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

The direct-download build is intentionally not App Sandbox–restricted because it must read the hidden `~/.codex` directory. AiWingman's access to `~/.codex` is read-only. The app does not request Full Disk Access, Contacts, Calendar, Photos, microphone, camera, or location. The optional child CLI boundary is described separately above and is not represented as a guarantee that the child cannot read other local files.

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
