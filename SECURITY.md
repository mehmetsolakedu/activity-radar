# Security Policy

AiWingman reads sensitive local development activity. Privacy failures
are treated as security issues.

## Supported versions

| Target | Security support |
| --- | --- |
| `v1.2.0-beta.2` | Superseded; do not build or use |
| Current default-branch snapshot | Superseded; do not build or use |
| Hardened review candidate | Not yet a supported public release |
| Older revisions and releases | Unsupported |

This policy does not promise a response or remediation SLA.

## Reporting a vulnerability

Use the repository's private vulnerability reporting feature when it is
available. Include:

- A concise description of the impact.
- The affected version or commit.
- Minimal reproduction steps using synthetic data.
- Whether exploitation reads, writes, exports, or transmits private content.
- A suggested mitigation, if known.

Do not open a public issue for an unpatched vulnerability. Do not attach real
Codex databases, rollout files, task titles, prompts, checkpoints, paths,
screenshots, identifiers, or research-ledger exports.

If private vulnerability reporting is not available, open a public issue titled
"Security contact requested" with no vulnerability details. Maintainers can
then establish a private channel.

## Security invariants

Changes should preserve these constraints:

- The Codex state directory remains read-only.
- SQLite uses read-only open flags and query-only mode.
- AiWingman-owned state is stored outside the Codex directory.
- Dashboard, diagnostics, and research-ledger paths transmit no Codex content
  and never start a background agent call.
- The sole optional Wingman transmission remains user-triggered, bounded,
  redacted, schema-validated, preceded by the exact intended JSON packet preview,
  and protected by one-shot consent. This superseded document is not an
  exhaustive packet-field contract; users must inspect the one-shot preview.
- Wingman packets exclude raw task identifiers, full paths, working and rollout
  paths, git and account metadata, system and developer instructions, tool
  outputs, and credentials. Unknown or tool events fail closed.
- The CLI authentication file is copied opaquely into a private temporary Codex
  home; user rules and configuration files are not copied. Beta2 attempts but
  does not verify cleanup. AiWingman requests the CLI's read-only sandbox mode;
  this is not OS-level isolation or a zero-filesystem-write guarantee.
- Research logging is disabled by default and its export excludes task content
  and raw task identifiers.
- High-impact lifecycle decisions require an explicit, reversible user action.

A report that demonstrates a violation or bypass of one of these constraints
is in scope.

## Coordinated disclosure

Please allow maintainers a reasonable opportunity to investigate and prepare a
fix before public disclosure. Maintainers will credit reporters when requested
and when doing so is safe.
