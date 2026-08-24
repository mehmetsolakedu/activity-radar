# Publication blueprint

Status: `HISTORICAL_PLANNING_DOCUMENT_SUPERSEDED`, retained for development
provenance. It is not a preregistration, final protocol, current evidence ledger,
or submission plan. The canonical current claim boundary is the manuscript in
`paper/aiwingman_technical_report.md`; the frozen policy contract is
`Research/protocol/SPECIFICATION_V1.md`.

This document records an earlier intended route and deliberately preserves
future-tense and `NOT_YET_FROZEN` entries as historical planning text. They must
not be read as the present state of the project. In particular, the later
specification-derived oracle was produced by the same project and is not an
independent oracle, and the selected preprint route is not the earlier Zenodo
archive plan.

AiWingman is a working open-source software artifact. This blueprint defines a
publishable technical evaluation that requires no participant recruitment,
field deployment, or private Codex task data.

The frozen claim boundary is:

> AiWingman can be evaluated for technical conformance, robustness, privacy
> properties, determinism, and bounded performance on public synthetic and
> adversarial fixtures. No evidence currently establishes that it improves
> human productivity, task resumption, memory, workload, trust, decision
> quality, or any other user outcome.

GitHub distribution and a Zenodo DOI can make the artifact freely usable,
citable, and reproducible. A Zenodo record is an archival publication, not
peer-review evidence and not evidence of human efficacy.

## Working title

**AiWingman: A Conformance-Tested Local Work-Continuity Artifact for Parallel
Coding-Agent Tasks**

Alternative benchmark-led title:

**A Synthetic and Adversarial Benchmark for Evidence-Thresholded Triage of
Parallel Coding-Agent Tasks**

## Artifact-stage abstract

**Background:** Local coding-agent histories contain heterogeneous task,
rollout, lifecycle, and token-counter evidence. A technical companion must
separate observed facts from heuristics, avoid double counting, abstain under
insufficient evidence, and preserve local data boundaries.

**Artifact:** AiWingman is a native macOS menu-bar application that queries
supported local Codex state with read-only/query-only SQL, presents
task-continuity signals, keeps explicit lifecycle decisions reversible, and
offers an optional, consent-gated Wingman review. SQLite WAL coordination may
create or update a persistent auxiliary `-shm` file; this is a declared VFS
exception rather than a source-directory immutability claim.

**Evaluation:** The artifact will be evaluated with a versioned, seeded
synthetic corpus and adversarial fixtures. The frozen dimensions are
conformance, robustness, privacy, determinism, and bounded performance.
Normative oracles are specified independently of the implementation. The remote
model is excluded from deterministic quality claims and may be exercised only
as a separately labeled compatibility smoke test using synthetic data.

**Results:** Numerical results must be inserted only after the public benchmark
harness, corpus, environment manifest, and analysis scripts are frozen and run.
Passing unit tests or a successful local launch alone is not a publication
result.

**Conclusion:** The intended paper is a software-artifact and technical-method
paper. Its conclusions are limited to the tested versions, fixtures, machines,
and claim gates. `HUMAN_EFFICACY_UNTESTED` remains mandatory.

## Contribution boundary

The intended contribution is technical and reproducibility-oriented:

1. A working, inspectable macOS artifact for evidence-thresholded work
   continuity across parallel coding-agent task trees.
2. An explicit conformance contract for root-task selection, descendant
   activity, lifecycle labels, cumulative token proxies, explanations, and
   abstention.
3. A public synthetic and adversarial benchmark corpus with implementation-
   independent expected outcomes.
4. A privacy test contract covering query-only SQL and no application-authored
   Codex data mutation, the declared SQLite WAL `-shm` exception, content
   minimization, explicit transmission consent, temporary-file handling, and
   forbidden-field rejection.
5. A reproducibility package that distinguishes deterministic local analysis
   from nondeterministic remote-model compatibility.
6. A free GitHub release archived on Zenodo with exact source revision,
   checksums, environment metadata, test outputs, and citation metadata.

The paper must not claim that AiWingman is:

- the first dashboard, session monitor, task summarizer, attention allocator,
  graph analysis, reject-option system, or agent companion;
- effective at improving a person's speed, accuracy, memory, productivity,
  workload, trust, or wellbeing;
- able to infer abandonment or obsolescence from silence;
- able to measure cognition, effort, billing, exact cost, or exact wasted
  tokens;
- validated by private developer histories, informal personal use, screenshots,
  a demo, downloads, stars, or contributor counts;
- superior to another interface or workflow without an appropriate external
  study that is outside this blueprint.

## Product-continuity boundary

The publication work must not replace or redesign the working application.
Evaluation code may add test fixtures, benchmark runners, and exportable
evidence, but it must preserve the production dashboard, local continuity data,
date-range controls, explicit obsolete/abandoned decisions, TR/EN interface, and
optional Wingman boundary.

The user-visible product name is AiWingman. Existing executable, module, bundle
identifier, preference-domain, and application-support names may retain
`ActivityRadar` or `Activity Radar` where changing them would break updates or
local-data continuity. The paper and artifact manifest must label those strings
as compatibility identifiers rather than as a second product.

No benchmark may write to, migrate, repair, or delete a real `~/.codex`
directory. All write-capable test work must occur in an isolated temporary
fixture root.

## Research questions

- **RQ1 — Conformance:** Does the frozen implementation produce the specified
  labels, rankings, explanations, abstentions, and aggregate measures for every
  normative synthetic fixture?
- **RQ2 — Robustness:** Does it fail neutrally, without crashes or source-data
  mutation, under missing, partial, malformed, stale, oversized, and internally
  conflicting evidence?
- **RQ3 — Privacy:** Do local reads, local persistence, research export, support
  information, and the optional Wingman packet obey the frozen data-flow and
  forbidden-field contracts?
- **RQ4 — Determinism:** Are normalized local-analysis outputs identical for
  identical inputs and seeds across repeated runs, and are any cross-platform
  differences bounded and documented?
- **RQ5 — Bounded performance:** How do load time, analysis time, peak memory,
  and output size scale across frozen synthetic portfolio sizes on the declared
  hardware and macOS matrix?

These questions concern software behavior only. They do not use a user-outcome
proxy and cannot support a human-effect conclusion.

## Evaluation contract

### 1. Independent specification and oracle

Before running the publication benchmark, freeze a versioned technical
specification that defines:

- a top-level task tree and the descendant evidence that belongs to it;
- the timestamp used for date-range inclusion;
- observed open work, explicit input requests, unseen results, quiet open work,
  and incomplete-history states;
- explicit lifecycle decisions, including the rule that silence alone never
  proves obsolete or abandoned;
- cumulative token-proxy aggregation without root/child double counting;
- ranking features, tie handling, explanation codes, and every abstention
  condition;
- the maximum selected and detailed task counts in a Wingman packet;
- allowed and forbidden fields for diagnostics, research exports, support
  information, and remote packets;
- failure behavior for unsupported source schemas and unsafe local files.

Expected outputs must be authored from this specification before the benchmark
runner is applied. If expected values are copied from current application
output, the corpus is a regression suite and must not be described as
independent validation.

### 2. Synthetic benchmark corpus

The public corpus contains no real task title, prompt, message, repository,
path, checkpoint, next action, account identifier, credential, or rollout
record. It includes:

- small hand-audited portfolios for exact conformance;
- seeded medium and large portfolios for scaling measurements;
- root tasks with zero, one, and many descendants;
- descendant activity newer than the root;
- pending input, unseen result, open turn, aborted turn, and quiet-open cases;
- complete, partial, and unavailable rollout coverage;
- explicit snooze, waiting, completed, superseded, obsolete, abandoned, and
  duplicate decisions;
- close-score, weak-evidence, and incomplete-history abstention cases;
- repeated cumulative counters that would expose double counting;
- multilingual, Unicode, empty, maximum-length, and normalization-sensitive
  strings;
- prompt-like strings containing instructions that must remain inert data.

Every generated fixture records its generator version, seed, size class, schema
version, expected outcome digest, and license.

### 3. Adversarial suite

| Adversarial condition | Required technical outcome |
| --- | --- |
| Missing source database or required column | Neutral incompatibility state; no repair or source write |
| Truncated, malformed, or type-confused rows | Bounded failure or documented row rejection; no crash |
| Locked database and concurrent source update | Read-only retry/failure behavior; no inconsistent success claim |
| Negative, overflowing, repeated, or non-monotone counters | Clamp/reject according to the frozen contract; no exact-waste claim |
| Root/child cumulative counter duplication | One tree-level proxy according to the frozen aggregation rule |
| Stale root with recent descendant | Inclusion based on the frozen tree-activity rule |
| Silence without a lifecycle decision | No automatic obsolete or abandoned label |
| Conflicting snooze/waiting and new input evidence | Frozen visible conflict or precedence behavior |
| Extremely large task tree or text field | Enforced size/count/time bounds |
| Invalid UTF-8, control characters, or bidirectional text | Safe sanitization or rejection with deterministic output |
| Prompt injection in a title or excerpt | Treated as quoted data; no instruction-following privilege |
| Symlink, unsafe owner/mode, or swapped auth/config file | Fail closed before the optional remote call |
| Unknown or tool-emitting remote event | Reject the Wingman result |
| Consent, scope, language, or prompt-sharing change | Previously granted one-shot consent is invalidated |
| Forbidden field inserted into an export or packet | Validation failure; artifact is not published |

### 4. Measurement matrix

The manifest freezes before measurement:

- exact Git commit and clean-tree status;
- Swift, Xcode, SDK, macOS, architecture, and dependency versions;
- Apple Silicon and Intel coverage where available;
- fixture corpus version and seed list;
- warm-up count, repetition count, timeout, and resource limits;
- locale, time zone, clock control, and temporary-root layout;
- all commands, exit codes, stdout/stderr captures, and result-file hashes.

At minimum, conformance and adversarial tests run on the project's declared
minimum macOS version and on the current supported macOS version. If that matrix
cannot be completed, the paper narrows its compatibility claim to the machines
actually tested.

## Metrics and pass criteria

### Conformance

- exact-oracle pass count and denominator;
- per-rule pass counts for selection, lifecycle, tokens, explanations, and
  abstention;
- schema-version compatibility results;
- TR/EN key coverage and deterministic fallback behavior.

The normative conformance claim requires 100% passage of frozen must-pass
fixtures. Any excluded fixture and reason remain visible in the result ledger.

### Robustness

- crash-free adversarial cases;
- neutral-failure cases matching their oracle;
- timeout and memory-bound enforcement;
- mutation checks over source-fixture hashes before and after every run;
- rejected unsafe-file, unknown-schema, and unknown-event cases.

A crash, hang beyond the frozen timeout, or source mutation blocks the
robustness claim and the public artifact release.

### Privacy

- zero forbidden fields in every public fixture, diagnostic, export, log, and
  packet;
- byte-for-byte equality between the consent preview and intentional stdin
  packet;
- prompt excerpts absent by default and present only after the separate toggle;
- one-shot consent invalidation for every frozen state change;
- private permissions and verified cleanup for temporary sensitive files;
- an explicit allowlist manifest for every auth/config file copied into an
  isolated CLI home;
- no application-authored mutation of source Codex records, schema, rollouts,
  main database, or WAL, with any SQLite VFS `-shm` effect recorded separately;
  and zero reads from real user data during benchmark execution.

Passing these checks supports only the enumerated privacy properties. A
read-only child sandbox is a write boundary, not proof that the child can read
only the previewed packet.

### Determinism

- identical normalized local-analysis JSON hashes over at least 100 repeated
  runs for every hand-audited fixture;
- identical seeded corpus hashes when regenerated in the frozen environment;
- cross-architecture exact matches for discrete outputs;
- frozen numeric tolerance and serialization precision for floating-point graph
  measures;
- deterministic ordering under ties, locale changes, and fixed timestamps.

Developer-ID signing and notarization metadata may be nondeterministic and are
excluded from bit-for-bit application-bundle reproducibility. The remote model
response is also excluded from determinism claims. Its optional smoke test
reports only invocation compatibility, schema validity, and safety-boundary
behavior.

### Bounded performance

For each frozen size class, report:

- source-open and evidence-read latency;
- portfolio-analysis latency;
- packet/export construction latency;
- peak resident memory;
- generated-output size;
- timeout or truncation events.

Report medians, p95 values, repetitions, and machine specifications. Performance
measurements describe computational behavior on synthetic workloads; they do
not imply time saved by a person.

## Evidence ledger

Publication evidence is tracked separately from implementation status:

| Evidence item | Current status | Required publication state |
| --- | --- | --- |
| Working application source | `IMPLEMENTED` | Exact clean revision identified |
| Unit and self-test suite | `EXISTS` | Commands and complete logs archived |
| Independent conformance specification | `NOT_YET_FROZEN` | Versioned and reviewed |
| Public synthetic corpus and oracle | `NOT_YET_FROZEN` | Licensed, versioned, hashed |
| Adversarial benchmark results | `NOT_YET_RUN_AS_PUBLICATION_EVIDENCE` | Complete result ledger |
| Privacy boundary results | `NOT_YET_RUN_AS_PUBLICATION_EVIDENCE` | All release-blocking checks pass |
| Determinism matrix | `NOT_YET_RUN_AS_PUBLICATION_EVIDENCE` | Repetitions and cross-machine limits reported |
| Performance matrix | `NOT_YET_RUN_AS_PUBLICATION_EVIDENCE` | Environment-qualified measurements reported |
| Human efficacy | `HUMAN_EFFICACY_UNTESTED` | Remains outside this paper |

Automated tests, manual checks, clean-machine observations, and remote smoke
tests must remain separate evidence classes. A pass in one class does not imply
a pass in another.

## Free distribution and archival publication

### GitHub

Use the public GitHub repository as the collaboration and release surface:

1. Freeze an exact clean tag for the evaluated version.
2. Publish source, license, contribution guide, security process, privacy
   boundary, release notes, and machine-readable citation metadata.
3. Attach the benchmark corpus, oracle, runner, raw technical results, summary
   tables, environment manifest, and SHA-256 checksums.
4. Publish a macOS binary only if the existing signing, notarization,
   Gatekeeper, architecture, checksum, and clean-machine acceptance gates pass.
5. Use synthetic screenshots and fixtures only; never attach private Codex
   databases, rollout files, task text, paths, credentials, or real-task
   screenshots.

The source release remains useful even when a supported prebuilt binary is not
yet available. Local ad-hoc builds must not be represented as signed public
downloads.

### Zenodo

After the GitHub tag and technical evidence package are frozen:

1. Connect or upload the exact tagged snapshot to Zenodo.
2. Deposit the source snapshot, corpus, specification, runner, result ledger,
   analysis scripts, environment manifest, checksums, license, and technical
   report.
3. Record the Git commit, GitHub release URL, artifact version, creators,
   affiliations, funding statement, related identifiers, and software license.
4. Obtain a version-specific DOI and reserve the concept DOI for the evolving
   project.
5. Cite the version-specific DOI in the paper and add the DOI back to the
   repository without rewriting the archived tag.

The Zenodo deposit must be independently downloadable and must not depend on a
private account, private data, mutable branch, or unarchived external file.

## Publication routes

The immediate citable output is the GitHub release plus Zenodo archive. A
peer-reviewed submission can then take one of these honest routes:

- **Software article:** architecture, claim contract, implementation,
  conformance, robustness, privacy, determinism, performance, and reuse.
- **Artifact or system-demonstration paper:** working interface plus the public
  benchmark and reproducibility package, without user-outcome claims.
- **Benchmark or methods note:** independently specified synthetic/adversarial
  corpus, oracle design, data-minimization rules, and baseline implementations.
- **Technical evaluation protocol:** a citable, executable protocol for future
  versions, clearly labeled as protocol rather than completed evidence.

Candidate venues must be checked against their current scope, software-paper
requirements, artifact rules, anonymity policy, and archival-overlap policy at
submission time. Repository publication, a Zenodo DOI, or a demonstration does
not establish scientific novelty or peer-review acceptance.

No venue should be targeted if it requires a demonstrated user benefit as the
main contribution. A later human-outcome study would require a new protocol,
new authority, separate ethics review where applicable, and a new claim
boundary; it is not a missing section of this paper.

## Ethics and data boundary

This blueprint uses only authored synthetic and adversarial data. It does not
authorize collection, export, or analysis of another person's Codex history.

- Do not recruit, monitor, survey, interview, or log users for this paper.
- Do not convert the production content-free ledger into an efficacy dataset.
- Do not use the author's private history as benchmark evidence.
- Do not publish stable user pseudonyms, raw timestamps, event streams, or
  content-derived examples.
- Run the benchmark against isolated temporary fixture roots.
- Review every public artifact for secrets, personal paths, real task text, and
  licensing provenance before release.

Institutional policies still apply to the software and publication, but this
technical plan contains no human-participant phase.

## Falsification and stop rules

- Any real or private task data in a fixture, log, screenshot, or archive:
  quarantine the artifact and stop publication until it is removed and the
  provenance audit is repeated.
- Any source-data write, crash, unbounded hang, or silent unsafe-schema
  acceptance: fail the affected technical claim and block the public binary.
- Any must-pass normative fixture failure: do not claim conformance.
- Any expected output derived from implementation output rather than the frozen
  specification: label the suite as regression testing, not independent
  validation.
- Any forbidden field in diagnostics, support information, research export, or
  Wingman packet: fail the privacy gate.
- Any undocumented auth/config copy into the isolated CLI home: fail the remote
  privacy gate.
- Any nondeterministic local discrete result under identical frozen inputs:
  investigate, repair, or explicitly narrow the determinism claim.
- Incomplete architecture or macOS coverage: state the tested matrix; do not
  generalize to untested systems.
- Remote-model variability or unavailability: report the compatibility result
  and keep it outside conformance and determinism totals.
- A prior-art review showing no distinct technical contribution: publish the
  artifact and benchmark as engineering resources without a novelty claim.
- A failed publication gate does not authorize replacing or weakening the
  working production application.

Negative and partial results remain publishable technical evidence when the
frozen protocol, full denominator, and failure logs are preserved.

## Finite execution sequence

1. Freeze the technical specification, claim table, corpus schema, seeds,
   oracles, environment matrix, and stop rules.
2. Implement the benchmark runner outside production paths and verify that it
   uses only temporary synthetic fixture roots.
3. Run conformance, adversarial, privacy, determinism, and performance suites;
   archive complete logs and hashes.
4. Resolve release-blocking failures or narrow claims without changing the
   frozen denominator.
5. Create the exact GitHub tag and free release package.
6. Archive that version and its evidence on Zenodo; record the DOI.
7. Write the software/artifact paper from the archived evidence and run a final
   claim-to-evidence audit.

The process ends with one of three valid states:

- `ARTIFACT_READY`: all stated technical gates passed and the exact evidence
  package is archived;
- `ARTIFACT_READY_WITH_LIMITATIONS`: the artifact is archived with failed or
  untested technical claims explicitly removed;
- `ARTIFACT_NOT_READY`: a privacy, provenance, mutation, or reproducibility
  blocker remains.

None of these states changes `HUMAN_EFFICACY_UNTESTED`.

## Minimum publication artifact

- exact tagged source revision and source archive;
- license, contribution, security, privacy, and citation metadata;
- frozen technical specification and claim table;
- licensed synthetic/adversarial corpus, seeds, generator, and oracle;
- benchmark runner and machine-readable result schema;
- raw result ledger, summary tables, failure logs, and analysis scripts;
- environment and compatibility matrix;
- checksums and artifact manifest;
- signed/notarized binary evidence only if a binary is distributed;
- Zenodo version DOI and GitHub release link;
- technical report or manuscript with a transparent limitations section.

## Manuscript skeleton

1. Motivation and technical scope
2. Related systems and claim boundary
3. AiWingman architecture and compatibility identifiers
4. Conformance specification
5. Synthetic and adversarial benchmark
6. Privacy and threat model
7. Determinism and performance protocol
8. Results with complete denominators
9. Limitations and threats to validity
10. Reproduction and archival package

Until the frozen benchmark and archive exist, the scientifically accurate
statement is:

> AiWingman is a working open-source artifact with a defined technical
> evaluation protocol. Its conformance, robustness, privacy, determinism, and
> performance claims await the frozen benchmark evidence, and human efficacy is
> untested.
