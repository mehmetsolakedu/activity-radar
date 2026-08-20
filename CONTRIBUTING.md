# Contributing to Activity Radar

Thank you for helping improve Activity Radar. Contributions of code, tests,
documentation, accessibility fixes, privacy reviews, and reproducible bug
reports are welcome.

Activity Radar is an independent community project. Participation is governed
by [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).

## Before starting

- Search the existing issues before opening a new one.
- For a substantial behavior, storage, schema, or UI change, open an issue
  first so the scope and acceptance evidence can be agreed.
- Report security or privacy vulnerabilities through the private process in
  [SECURITY.md](SECURITY.md), not through a public issue.
- Use [SUPPORT.md](SUPPORT.md) for usage questions and troubleshooting.

## Privacy and safety requirements

Every contribution must preserve these project invariants:

- Treat the user's Codex directory as read-only.
- Open SQLite state with read-only flags and query-only mode.
- Keep Activity Radar-owned preferences and metadata outside the Codex
  directory.
- Do not transmit task titles, prompts, checkpoints, paths, message text, or
  user-authored next actions.
- Keep research logging opt-in, local, content-free, and retention-bounded.
- Do not infer abandonment or obsolescence from inactivity alone.
- Keep high-impact lifecycle decisions explicit and reversible.
- Preserve abstention when evidence is incomplete or user intent suppresses a
  recommendation.

Never commit real task transcripts, rollout files, database copies, task
identifiers, local paths, screenshots of private work, or exported research
ledgers. Tests and documentation must use synthetic fixtures. Redaction should
remove content, not merely blur or crop it.

## Development setup

The package targets macOS 13 or later and uses Swift Package Manager. A recent
Swift toolchain with the macOS SDK is required.

Clone your fork, create a focused branch, and make the smallest coherent
change. Avoid mixing formatting-only changes with behavior changes.

## Verification

Run the same deterministic gates used by CI:

~~~sh
swift run ActivityRadarSelfTest

swift test

swiftc -parse-as-library \
  Sources/ActivityRadar/RadarContinuityStore.swift \
  scripts/continuity-store-self-test.swift \
  -o /tmp/activity-radar-continuity-store-self-test
/tmp/activity-radar-continuity-store-self-test

swift build -c release --product ActivityRadar
~~~

For packaging changes, also run:

~~~sh
./scripts/package-app.sh "/tmp/Activity Radar.app"
~~~

The `ActivityRadarDiagnostics` executable reads the local task corpus but emits
only aggregate compatibility counts and explicit privacy-boundary flags. Its
output contract excludes task identifiers, titles or messages, local paths,
and checkpoints. Review the generated output before attaching it to an issue
or pull request; if that contract appears to be violated, stop and use the
private process in [SECURITY.md](SECURITY.md).

The release check first uses normal Swift test discovery. On Apple's minimal
Command Line Tools installation, it can retry with that installation's bundled
Testing framework in a temporary scratch directory without changing system
settings. A successful empty `swift test` invocation is not test evidence and
is never accepted as a substitute for the executable self-test and store
harness above.

## Tests and evidence

- Add a deterministic regression fixture for changed domain behavior.
- Use fixed timestamps and synthetic identifiers.
- Test the failure or abstention path as well as the success path.
- For storage changes, test default-off behavior, retention, pseudonymization,
  and rejection of unsafe locations.
- For UI changes, describe the macOS and accessibility checks actually
  performed. Do not claim checks that were not run.

Automated checks are evidence about the implementation, not evidence of user
effectiveness, scientific novelty, or publication value.

## Pull requests

A pull request should:

- Explain the user problem and the bounded solution.
- Identify privacy, read-only, lifecycle, and abstention effects.
- List exact verification commands and their observed results.
- Keep unrelated files out of the change.
- Update tests and public documentation when the contract changes.
- Avoid personal names, machine paths, account data, and real task content.

By contributing, you agree that your contribution is licensed under the MIT
License in [LICENSE](LICENSE).
