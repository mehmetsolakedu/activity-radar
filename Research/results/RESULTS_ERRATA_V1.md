# Results package V1 errata

Date recorded: 23 August 2026

This note preserves, rather than silently rewrites, the committed V1 result
artifacts and their published SHA-256 values.

## Cross-process counter terminology

`Research/results/cross-process-determinism-v1-arm64.json` contains
`"evaluationCount": 15500`. The generating script calculated that field as
`100 processes × 155 fixtures`. It is therefore a count of process-fixture
summary coverage, not a count of individual policy-function calls.

Every fresh benchmark process ran the benchmark's frozen 100 within-process
repetitions for each of the 155 fixtures before producing its canonical corpus
digest. The correct result-level statement is:

> All 100 fresh benchmark processes passed and produced the same canonical
> digest for the 155-fixture corpus. Each process generated that digest after
> 100 within-process repetitions per fixture.

The fixed determinism portion therefore contains 1,550,000 policy evaluations
across the 100 fresh processes (`100 × 155 × 100`). This number excludes the
runner's separate performance warm-ups and measurements and must not be
presented as a total count of every policy call made by those processes.

The corresponding `crossProcessEvaluationCount` value in
`Research/results/RESULTS_MANIFEST_V1.json` has the same terminology defect.
Neither committed JSON file is modified by this erratum.

## Execution provenance boundary

The `runnerCommit` field in the cross-process JSON records the command-line
value supplied by the operator. The V1 driver did not independently compare
that value with Git `HEAD`, require a clean worktree, or record the built
executable's SHA-256. The manuscript must therefore describe the detached
worktree execution as author-reported procedure, not as machine-attested
provenance. Reproduction should verify the exact Git revision and source hashes
before building and compare conformance plus the canonical output digest rather
than expecting an environment-dependent whole-report JSON hash.
