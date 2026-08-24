# Codex integration

AiWingman does not embed an OpenAI API client. Its ordinary dashboard uses
two local interfaces:

```text
Codex Desktop or CLI
        │ writes local task state
        ▼
~/.codex SQLite and JSONL files
        │ query-only SQL / bounded file reads
        ▼
AiWingman
        │ requests codex://threads/<thread-id>
        ▼
Codex URL handler (final navigation is not observed by AiWingman)
```

AiWingman issues no SQL writes to Codex records or schema and does not
intentionally modify Codex rollout files, the main database, or its WAL.
SQLite's VFS may create or update an auxiliary `state_5.sqlite-shm` or
`goals_1.sqlite-shm` file for WAL coordination, and that file may persist
according to the SQLite/Codex lifecycle; therefore the integration is not
described as making the entire `~/.codex` directory immutable.

## Requirements

- The package declares macOS 13 as its deployment target. Current automated builds and tests ran on later macOS versions; no real macOS 13 launch or runtime result is reported yet.
- Codex Desktop or Codex CLI must have been used by the same macOS user.
- `~/.codex/state_5.sqlite` must exist and use a schema supported by this AiWingman version.
- The Codex desktop application must register the `codex://` URL scheme for “Return to task” navigation.

AiWingman accepts a task-navigation identifier only when it has the standard
hyphenated UUID layout, normalizes its hexadecimal case, and constructs the
route as one URL path segment. Delimiters, path traversal, raw or
percent-encoded slashes, and other UUID layouts are rejected before a URL-open
request is made. A successful `NSWorkspace.open`
return is shown as **Open requested in Codex**: it means macOS accepted the URL
open request, not that AiWingman observed Codex render the selected task. The
legacy fixed-schema research value `taskOpened` has this same request-accepted
meaning and is not evidence of completed navigation.

No separate API-key request or storage, OAuth flow, AiWingman account, plug-in,
or background server is required. The optional review reuses the signed-in
CLI's saved authentication mechanism opaquely; a separately installed and
signed-in Codex CLI is required only for that remote critique.

## Optional Wingman review

The **Bir Wingman Çağır** flow is separate from task navigation and does not
attach to the currently open Codex Desktop task. Local evidence analysis and
the exact packet preview work without a network request. No agent call runs in
the background.

```text
query-only SQL and bounded local evidence
        │ bounded analysis and redaction
        ▼
exact intended JSON preview + one-shot consent
        │ stdin, direct process invocation without a shell
        ▼
new ephemeral Codex CLI turn
        │ schema-constrained review through Codex/OpenAI
        ▼
in-memory structured result
```

Before every invocation, AiWingman makes the exact user-derived JSON packet it
intends to supply on stdin available for inspection. The packet is processed together with the fixed
reviewer instruction and output schema shipped in the source; those fixed texts
contain no task data. Prompt excerpts, prompt-derived themes, and local text signals
share one separate, off-by-default choice. With it off, task-derived free text is
limited to sanitized titles; prompt excerpts, prompt-derived themes, local review
signals, and next-move text are omitted. The packet still contains timestamps and
the activity cutoff, status/enumeration fields, booleans, counts, numeric
measurements, schema/language metadata, and a fixed method-boundary string.
Changing the scope or prompt-sharing setting clears consent, and consent is
cleared after the attempt. The local analysis can select up to 20 task trees;
the remote packet carries detailed rows for at most the 12 busiest selected
trees and states the selected, detailed, and omitted-detail counts.

Opening the Wingman view does not invoke Codex CLI. The user must separately
choose **Check Codex CLI**. That compatibility action validates the executable
and runs version, command-compatibility, and login-status checks. It starts no
agent turn and sends no AiWingman task packet, but it uses a private temporary
Codex home with an opaque copy of the validated saved authentication file. Its
cleanup and residue boundary is the same one documented below.

The CLI is launched with approval disabled, a request for read-only sandbox mode, an ephemeral
turn, ignored user configuration, no shell, bounded input/output/time, and a
strict output schema. Unknown or tool events fail closed. AiWingman
validates the saved authentication file's metadata and copies it opaquely into
a private temporary Codex home. Normal result and error paths attempt cleanup
and verify absence; an unverified cleanup rejects the result and blocks later
remote calls in the current app process until cleanup succeeds. A process-wide
gate allows only one remote temporary-auth lifecycle at a time. A crash can
still leave `ActivityRadar-Wingman-` or `ActivityRadar-CLI-Probe-` residue;
quit the app and follow the narrowly scoped recovery procedure in `SECURITY.md`
before reopening. User rules and configuration files are not copied.
Credential contents are not parsed or
added to the packet.

These controls describe the intended invocation, not an isolation proof. A
requested read-only sandbox mode is intended to deny agent-tool writes to the
workspace; it is neither OS-level isolation nor a zero-filesystem-write
guarantee, and it does not prove that the child process cannot read another
local file. The exact previewed packet is therefore not a
claim that it is the CLI's only technically accessible context. `--ephemeral`
requests a turn intended not to save a local rollout; it does not prove that no
local artifact exists and does not define service-side retention. See
[PRIVACY.md](../PRIVACY.md) before consenting.

## Compatibility boundary

This is an unofficial local integration, not a stable OpenAI API contract. A future Codex release may rename local files, change their schema, or change the deep-link route. AiWingman checks required database columns and reports a neutral incompatibility error rather than modifying or repairing Codex data.

## Troubleshooting

1. Open Codex and create or open at least one task.
2. Quit and reopen AiWingman.
3. Run `swift run ActivityRadarDiagnostics` from a source checkout.
4. Share only the fixed-schema diagnostic JSON after confirming that it contains
   no task text or raw task identifiers—not `~/.codex` files—in a public issue.

If tasks are visible but “Return to task” fails, verify that the current Codex desktop application is installed and can open a `codex://` link.

If the optional critique is unavailable, verify `codex --version` and `codex
login status`, then use **Codex CLI'yi yeniden denetle**. Do not paste
`auth.json`, the preview packet, or rollout files into a public issue.
