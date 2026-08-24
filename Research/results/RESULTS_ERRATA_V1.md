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
evaluations for each of the 155 fixtures before producing its canonical corpus
digest. The correct result-level statement is:

> All 100 fresh benchmark processes passed and produced the same canonical
> digest for the 155-fixture corpus. Each process generated that digest after
> 100 within-process evaluations per fixture; evaluations 2-100 matched
> evaluation 1 for every fixture.

The fixed determinism portion therefore contains 1,550,000 policy evaluations
and 1,534,500 nontrivial equality comparisons across the 100 fresh processes
(`100 × 155 × 100` evaluations and `100 × 155 × 99` comparisons). These numbers
exclude the runner's separate conformance calls, baseline contrasts,
performance warm-ups, and performance measurements and must not be presented
as total counts of every policy call made by those processes.

The corresponding `crossProcessEvaluationCount` value in
`Research/results/RESULTS_MANIFEST_V1.json` has the same terminology defect.
Neither committed JSON file is modified by this erratum.

## Protocol chronology and fresh-process status

The frozen protocol specified 100 within-process evaluations of every fixture.
Evaluation 1 established the per-fixture baseline and evaluations 2-100 were
compared with it.
It did not specify a 100-fresh-process driver. The fresh-process script and its
result first appeared together in the result-package commit. The 100/100
fresh-process result is therefore supplementary post-freeze repeatability
evidence, not a preregistered or frozen check.

The evaluated Swift policy implementation also predated the protocol freeze.
`Sources/ActivityRadarCore/WorkContinuity.swift` has SHA-256
`ff68e565bb1cebff47d66a23488e84b4e7bc2bf39cf8b75740683a7a055fa895`
at the historical public release, protocol-freeze, runner, and result
checkpoints. The freeze fixed a written specification and expected outputs
before the archived benchmark execution; it did not precede implementation and
must not be described as a preregistration. The frozen manifest value
`FROZEN_BEFORE_SWIFT_BENCHMARK_EXECUTION` has the same bounded meaning: it is
supported by repository chronology and author report for the archived result,
not machine attestation that no earlier exploratory or unarchived run occurred.

## Source-comment terminology

The frozen Swift source comment says the ranker “never uses free text as a
ranking input.” The executable policy does not inspect lexical text content,
but it does use the trimmed presence or absence of selected user-text fields,
including waiting and next-action text. That historical wording and its
recorded source hash remain preserved at the evaluated checkpoints. The current
branch corrects only the comment; the executable policy logic is unchanged, but
the current file is intentionally no longer byte-identical to the frozen source.

## Frozen specification terminology

The frozen specification describes the Python oracle as
“implementation-independent at the language boundary.” In this project, that
historical phrase means only that the Python generator was separately
implemented without importing, invoking, parsing, or copying the Swift source.
The same project produced the pre-existing Swift implementation, the later
written specification, and the Python oracle. The phrase must not be interpreted
as independent authorship, external validation, or an implementation-independent
reference standard.

The specification also uses “content-free output” for the seeded-string check.
That phrase is bounded to the same five exact seeded strings searched in one
serialized conformance output per fixture. It does not mean that outputs contain
no identifiers or no other content, and it does not establish semantic content
independence, anonymity, privacy, noninterference, or secret removal. The frozen
specification remains unchanged so its recorded hash continues to identify the
historical protocol artifact.

## `contentNeutrality` terminology

The historical `contentNeutrality` field denotes only absence of five exact
seeded strings from one scanned serialized conformance output per fixture. It
does not establish semantic content independence, anonymity, noninterference,
privacy, absence of identifiers, or secret removal. The corrected name for the
performed check is **five-sentinel non-propagation**. The committed JSON remains
unchanged so its existing hash continues to describe the archived artifact.

## Result-report granularity

The V1 primary result is a summary report, not a complete per-fixture result
ledger. Passing actual outputs are not retained as individual rows; the report
retains fixture counts, failure records, and the canonical corpus-output digest.
The frozen corpus remains the expected-output ledger. Reproduction must rerun
the benchmark to obtain actual outputs and compare the reported digest rather
than infer that passing rows were archived.

## Execution provenance boundary

The `runnerCommit` field in the cross-process JSON records the command-line
value supplied by the operator. The V1 driver did not independently compare
that value with Git `HEAD`, require a clean worktree, or record the built
executable's SHA-256. The manuscript must therefore describe the detached
worktree execution as author-reported procedure, not as machine-attested
provenance. Reproduction should verify the exact Git revision and source hashes
before building and compare conformance plus the canonical output digest rather
than expecting an environment-dependent whole-report JSON hash.
