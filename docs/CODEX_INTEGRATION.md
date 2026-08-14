# Codex integration

Activity Radar does not connect through the OpenAI API. It uses two local interfaces:

```text
Codex Desktop or CLI
        │ writes local task state
        ▼
~/.codex SQLite and JSONL files
        │ read-only
        ▼
Activity Radar
        │ opens codex://threads/<thread-id>
        ▼
Codex opens the selected task
```

## Requirements

- macOS 13 or newer.
- Codex Desktop or Codex CLI must have been used by the same macOS user.
- `~/.codex/state_5.sqlite` must exist and use a schema supported by this Activity Radar version.
- The Codex desktop application must register the `codex://` URL scheme for “Return to task” navigation.

No API key, OAuth flow, Activity Radar account, plug-in, or background server is required.

## Compatibility boundary

This is an unofficial local integration, not a stable OpenAI API contract. A future Codex release may rename local files, change their schema, or change the deep-link route. Activity Radar checks required database columns and reports a neutral incompatibility error rather than modifying or repairing Codex data.

## Troubleshooting

1. Open Codex and create or open at least one task.
2. Quit and reopen Activity Radar.
3. Run `swift run ActivityRadarDiagnostics` from a source checkout.
4. Share only the content-free diagnostic JSON—not `~/.codex` files—in a public issue.

If tasks are visible but “Return to task” fails, verify that the current Codex desktop application is installed and can open a `codex://` link.
