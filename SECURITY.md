# Security Policy

Activity Radar reads sensitive local development activity. Privacy failures
are treated as security issues.

## Supported versions

| Target | Security support |
| --- | --- |
| Current default branch | Supported |
| Latest tagged release | Supported |
| Older revisions and releases | Best effort |

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
- Activity Radar-owned state is stored outside the Codex directory.
- Codex message text and user-authored continuity text are not transmitted.
- Research logging is disabled by default and its export excludes task content
  and raw task identifiers.
- High-impact lifecycle decisions require an explicit, reversible user action.

A report that demonstrates a violation or bypass of one of these constraints
is in scope.

## Coordinated disclosure

Please allow maintainers a reasonable opportunity to investigate and prepare a
fix before public disclosure. Maintainers will credit reporters when requested
and when doing so is safe.
