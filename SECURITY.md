# Security Policy

AiWingman reads sensitive local development activity. Privacy failures
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

- AiWingman issues no SQL writes to Codex records or schema and does not
  intentionally create or modify Codex rollout files, the main database, or
  its WAL. SQLite uses read-only open flags and query-only mode. SQLite's VFS
  may still create or update an auxiliary `state_5.sqlite-shm` or
  `goals_1.sqlite-shm` file for WAL coordination; this narrow exception is
  documented rather than represented as a directory-immutability guarantee.
  The `-shm` file may persist according to the SQLite/Codex lifecycle.
- AiWingman-owned state is stored outside the Codex directory.
- Dashboard, diagnostics, and research-ledger paths transmit no Codex content
  and never start a background agent call.
- The sole optional Wingman transmission remains user-triggered, bounded,
  redacted, schema-validated, preceded by the exact intended JSON packet preview,
  and protected by one-shot consent. Prompt excerpts, prompt-derived themes, and
  local text signals remain separately opt-in; with that option off the packet
  contains task titles and numeric measurements only. User-authored continuity
  text is never included.
- Wingman packets exclude raw task identifiers, full paths, working and rollout
  paths, git and account metadata, system and developer instructions, tool
  outputs, and authentication-file contents. Allowed titles and separately
  opted-in text can still contain a secret outside the finite sanitizer rules;
  sanitization is best-effort and the user must inspect the exact preview.
  Unknown or tool events fail closed.
- The CLI authentication file is copied opaquely into a private temporary Codex
  home; user rules and configuration files are not copied. Cleanup is attempted
  after every normal result or error and absence is checked. If absence cannot
  be verified, a visible error is returned and the current app process blocks
  later remote calls until cleanup succeeds. Only one remote Wingman operation
  may cross this temporary-auth lifecycle at a time. A crash or forced
  termination can still leave a temporary `ActivityRadar-Wingman-` or
  `ActivityRadar-CLI-Probe-` directory. Quit the app, inspect only immediate
  children of the current user's macOS temporary directory with either exact
  prefix, remove only those residue directories, and then reopen; never delete
  a broader temporary path. The read-only child sandbox prevents writes but is
  not treated as proof that other local files cannot be read.
- Research logging is disabled by default and its export excludes task content
  and raw task identifiers.
- High-impact lifecycle decisions require an explicit, reversible user action.

A report that demonstrates a violation or bypass of one of these constraints
is in scope.

## Coordinated disclosure

Please allow maintainers a reasonable opportunity to investigate and prepare a
fix before public disclosure. Maintainers will credit reporters when requested
and when doing so is safe.
