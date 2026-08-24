# Third Codex-assisted internal claim and security audit

Date: 24 August 2026

Decision: `NO_SUBMIT` until author declarations, final exact-commit provenance,
clean-clone gates, and declaration-complete document rebuilds are complete. This
is an internal AI-assisted adversarial review, not human peer review, independent
validation, editorial screening, or acceptance.

## Scope

Three independent review tracks examined numerical claims and archived results,
nearby literature and current product precedents, and source-to-claim/privacy
alignment. The source review used static inspection plus synthetic adversarial
fixtures. It did not run a real remote Wingman review, inspect service retention,
exercise macOS 13, or execute the current revision on x86_64.

## Verdict

No P0 issue was found. Two P1 implementation/documentation mismatches and seven
source/claim P2 issues were found. The current working revision fixes each issue below, but
it remains a moving dirty tree and is not yet an archival or uploadable artifact.

## P1 findings and disposition

1. **Unbounded ordinary goal inclusions.** The base dashboard page was capped,
   but all goal rows and all active/blocked/limited goal-linked IDs could be
   appended. A 250-goal synthetic fixture returned 250 rows for a requested
   limit of 200. The reader now returns at most 200 rows, admits at most 64
   deduplicated priority/goal inclusions, scans at most 200 rows from a reverse-
   `rowid` goal window with conservative truncation signaling, fetches status metadata only for the
   bounded returned IDs, and enforces per-field and aggregate SQLite-text byte
   ceilings. A closure audit found that 65--200 eligible inclusions were capped
   without setting `hasMore`; a separate truncation flag and a 100-goal fixture
   now cover that edge. Row, inclusion, goal-window, per-field, and aggregate
   overflow fixtures pass.
2. **Authenticated CLI probe on sheet appearance.** Opening Wingman previously
   started version/help/login-status commands and copied `auth.json` into a
   private temporary root before packet-transfer consent. Opening the sheet now
   performs local analysis only. CLI compatibility probing requires a separate
   explicit action; it starts no agent turn and sends no AiWingman task packet.
   The UI and privacy documentation disclose that the explicit probe still uses
   the temporary opaque authentication-copy lifecycle. A model regression test
   confirms that `prepare()` performs no probe.

## P2 findings and disposition

- The exact packet is available inside a collapsed disclosure control; consent
  does not prove that the user expanded it. UI, policy, and manuscript wording
  now say “available for inspection” and the paper states the collapsed-control
  limitation.
- Deep-link construction now accepts the standard hyphenated UUID layout,
  normalizes hexadecimal case, builds one URL path segment, and rejects query,
  fragment, traversal, braces, alternate layout, slash, and encoded-slash
  inputs. UI and research-event documentation treat a successful
  `NSWorkspace.open` return as an accepted request, not observed navigation.
- Blank parent or child graph-edge endpoints now fail closed and are covered by
  adversarial fixtures.
- Public test instructions now use `scripts/run-swift-tests.sh`, which refuses
  success unless a known test is discovered and supports the bundled Command
  Line Tools Testing fallback. Plain zero-test `swift test` success is not
  accepted as evidence.
- Continuity files are now created through a private `0600` descriptor before
  the first byte, then fully written, synced, closed, atomically renamed, and
  parent-directory synced. The regression harness observes both the open and
  pre-write phases and passes under `umask 000` and `0777`.
- Default-branch wording now distinguishes current `main` at `2248203...` from
  the unsupported beta2 application source at `5e212181...`.
- Goal-inclusion truncation at the 64-row boundary now sets `hasMore` even when
  the separate 200-row reverse-`rowid` window is not exhausted.

## Verification on the current arm64 working revision

- Enforced Swift discovery: 94 tests found; 94/94 passed.
- Deterministic application self-test: 16/16 passed.
- Continuity-store permission/retention harness: passed under `umask 000` and
  `umask 0777`.
- Debug application build and diff whitespace check: passed.
- A fresh manifest-only export passed the complete public-source preparation
  gate: adversarial plain/compressed privacy scans, diagnostics, manifest
  regular-file checks, 94 tests, 16 self-tests, release builds, arm64 and x86_64
  cross-builds, local Universal 2 bundle construction/signature/topology checks,
  and canonical ZIP checks. The x86_64 slice was built, not executed.
- Independent POSIX review of the secure-write patch: no remaining P0/P1/P2.
- Bibliography: 32/32 references cited in first-use order; closest native Codex,
  GitHub, and recent trajectory/debugging precedents are included. A bounded
  resolver check reached the intended destination for all 37 manuscript URLs;
  publisher anti-automation responses are not counted as content validation.
- Numerical recomputation: no remaining mismatch in the reported frozen-policy
  results. The historical cross-process counter label remains preserved and is
  corrected through the published erratum.
- Provisional all-page visual inspection caught a stale `DRAFT 0.4` running
  header in the Draft 0.5 PDF builder. The builder now emits `DRAFT 0.5`; final
  document bytes remain gated on author declarations and a fresh rebuild.

These checks do not attest the later document bytes from a public exact commit,
do not replace external peer review, and do not establish human benefit,
security isolation, broad determinism, stable Codex compatibility, or macOS 13
runtime support.

## Remaining fail-closed gates

1. Named-author identity, affiliation, funding, competing-interest,
   contribution, AI-assistance, rights, license, duplicate-publication,
   institutional, journal, funder, and patent declarations.
2. Final Draft 0.5 DOCX/PDF rebuild after those declarations, followed by
   all-page visual QA, structural inspection, metadata checks, and compressed-
   artifact privacy scans.
3. Freeze, commit, and push the exact revision; rerun full gates from a clean
   detached clone; record final hashes and public CI for that exact commit.
4. Explicit author confirmation immediately before the irreversible portal
   **Submit** action. No portal upload or submission has occurred.
