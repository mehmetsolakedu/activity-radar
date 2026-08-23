# Codex integration

AiWingman does not embed an OpenAI API client. Its ordinary dashboard uses
two local interfaces:

```text
Codex Desktop or CLI
        │ writes local task state
        ▼
~/.codex SQLite and JSONL files
        │ read-only
        ▼
AiWingman
        │ opens codex://threads/<thread-id>
        ▼
Codex opens the selected task
```

## Requirements

- macOS 13 or newer.
- Codex Desktop or Codex CLI must have been used by the same macOS user.
- `~/.codex/state_5.sqlite` must exist and use a schema supported by this AiWingman version.
- The Codex desktop application must register the `codex://` URL scheme for “Return to task” navigation.

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
read-only local evidence
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

Before every invocation, AiWingman shows the exact user-derived JSON packet it
intends to supply on stdin. The packet is processed together with the fixed
reviewer instruction and output schema shipped in the source; those fixed texts
contain no task data. Prompt excerpts, prompt-derived themes, and local text signals
share one separate, off-by-default choice. With it off, the remote packet
contains task titles and numeric measurements only.
Changing the scope or prompt-sharing setting clears consent, and consent is
cleared after the attempt. The local analysis can select up to 20 task trees;
the remote packet carries detailed rows for at most the 12 busiest selected
trees and states the selected, detailed, and omitted-detail counts.

The CLI is launched with approval disabled, read-only sandboxing, an ephemeral
turn, ignored user configuration, no shell, bounded input/output/time, and a
strict output schema. Unknown or tool events fail closed. AiWingman
validates the saved authentication file's metadata, copies it opaquely into a
private temporary Codex home, and removes the copy after the attempt. User rules
and configuration files are not copied. Credential contents are not parsed or
added to the packet.

These controls describe the intended invocation, not an isolation proof. A
read-only sandbox prevents writes but does not guarantee that the child process
cannot read another local file. The exact previewed packet is therefore not a
claim that it is the CLI's only technically accessible context. `--ephemeral`
prevents a local rollout from being saved; it does not define service-side
retention. See [PRIVACY.md](../PRIVACY.md) before consenting.

## Compatibility boundary

This is an unofficial local integration, not a stable OpenAI API contract. A future Codex release may rename local files, change their schema, or change the deep-link route. AiWingman checks required database columns and reports a neutral incompatibility error rather than modifying or repairing Codex data.

## Troubleshooting

1. Open Codex and create or open at least one task.
2. Quit and reopen AiWingman.
3. Run `swift run ActivityRadarDiagnostics` from a source checkout.
4. Share only the content-free diagnostic JSON—not `~/.codex` files—in a public issue.

If tasks are visible but “Return to task” fails, verify that the current Codex desktop application is installed and can open a `codex://` link.

If the optional critique is unavailable, verify `codex --version` and `codex
login status`, then use **Codex CLI'yi yeniden denetle**. Do not paste
`auth.json`, the preview packet, or rollout files into a public issue.
