# AiWingman: Design and Specification-Based Evaluation of a Local Continuity Overlay for Codex Task Portfolios

Mehmet Solak

Department of Biosystems Engineering, Faculty of Agriculture, Siirt University, Siirt, Türkiye

ORCID: 0000-0002-0800-0334 | Correspondence: mehmetsolak@siirt.edu.tr

Draft 0.3 - 23 August 2026 - Corrected major-revision manuscript; author confirmation required before public deposit

## Abstract

Persistent coding-agent tasks can leave a user with several simultaneous requests for input, completed results, blocked tasks, and quiet but unfinished work. AiWingman is an open-source macOS menu-bar companion that presents continuity cues from locally retained Codex task evidence. Its ordinary dashboard and optional Wingman review are separate data pipelines. The ordinary dashboard selects non-archived top-level user tasks, reduces each selected root task's own bounded rollout evidence, applies deterministic continuity rules, and can return the user to a selected Codex task through a local deep link. The optional Wingman pipeline separately resolves parent-child task trees, computes descriptive tree-level signals and a cumulative token-counter comparison proxy, and can construct a previewed packet for a consented Codex CLI review. The software does not infer confirmed obsolete or abandoned states from silence or age; those labels require reversible user confirmation.

This report evaluates only the pure continuity-policy layer, not either reader, the graphical interface, Codex compatibility, graph analysis, token accounting, or remote review quality. A written specification and 155 synthetic fixtures were frozen before execution. A same-project Python oracle generated expected outputs as a separate implementation at the language boundary from the Swift policy. The Swift runner matched all 155 fixtures and produced one canonical output digest across 15,500 within-process evaluations. All 100 fresh benchmark processes produced that same 155-fixture corpus digest on one arm64 Mac; each fresh process computed its digest after the runner's 100 within-process repetitions per fixture. Five seeded content sentinels produced zero occurrences in serialized policy outputs, and 70 unconfirmed lifecycle fixtures produced zero confirmed-obsolete or confirmed-abandoned states. Two deliberately simplified technical baselines agreed with 40/75 and 59/75 triage decisions and violated 35 and 16 frozen no-recommendation cases, respectively. Median policy latency at 1,000 synthetic inputs was 0.511 ms for triage and 0.388 ms for lifecycle assessment on the measured machine. These results establish specification conformance only within the frozen synthetic scope. They do not establish external validation, human benefit, comparative superiority, exact token cost or waste, security isolation, cross-architecture policy determinism, or stable compatibility with Codex.

Keywords: coding agents; work continuity; local-first software; deterministic ranking suppression; specification-based testing; human oversight

## 1. Introduction

Coding-agent work is often organized as a portfolio rather than a single conversation. A user may delegate several tasks, answer one agent's question, leave another task waiting on an external event, receive a result in a third task, and later attempt to resume work after the original plan has faded. The newest timestamp is not necessarily the next useful task. Conversely, age and silence do not establish that work is obsolete or abandoned.

Prior work has already established task-context restoration, interruption-resumption cues, developer-awareness dashboards, personalized triage, multi-agent interfaces, and agent observability [1-13]. Current GitHub Copilot documentation also describes parallel agent sessions, progress and token inspection, session-history queries, summaries, cost guidance, task resumption, deep links, and a separate critique agent [14-16]. AiWingman therefore makes no first-of-kind or superiority claim for dashboards, session recall, token guidance, or agent-assisted critique.

AiWingman's narrower contribution is an implementation-specific design case: a Codex-specific retrospective overlay that combines read-only inspection of locally retained task evidence, an offline-default ordinary dashboard, explicit and reversible user-owned lifecycle decisions, and deterministic ranking suppression under written evidence rules. Each constituent idea has prior art. The contribution is their auditable integration and the preparation of a versioned source and evaluation package.

AiWingman is not a coding agent, an autonomous project manager, an official OpenAI product, or a stable Codex integration. It observes local behavior that is not documented as a public compatibility contract. It writes AiWingman-owned preferences and continuity metadata but is not a write-free application. Its optional remote review is not part of the offline ordinary dashboard.

This report makes four bounded contributions:

1. It documents two distinct implementation pipelines without attributing task-tree aggregation or graph analysis to the ordinary dashboard.
2. It specifies a deterministic continuity policy that separates observed evidence from reversible lifecycle decisions and can return no recommendation under explicit conditions.
3. It reports a frozen, participant-free, specification-based evaluation of the pure policy layer, including exact conformance, determinism, content-neutrality, a confirmed-state invariant, technical-baseline, and descriptive-performance results.
4. It provides a claim ledger that distinguishes historical release engineering evidence, current policy evidence, and untested reader, interface, remote, security, compatibility, and human-outcome claims.

No recruited participants, surveys, interviews, private task histories, or human-outcome measurements were used. The report does not claim faster resumption, improved recall, lower workload, better decisions, fewer wasted tokens, or increased productivity.

## 2. Related Work and Positioning

### 2.1 Programmer task context and resumption

Kersten and Murphy's Mylar work captured task context, filtered development artifacts by degree of interest, and restored context across task switches [1]. Parnin and DeLine investigated cues for resuming interrupted programming tasks through a survey and controlled study [2], while Parnin and Rugaber characterized resumption behavior across a large set of programming sessions [3]. These studies make generic task-context restoration and programming-resumption novelty untenable. They motivate AiWingman's checkpoints, next actions, and continuity cues, but they do not validate those features for coding-agent portfolios.

Research on user-authored source annotations also shows how developers use externalized cues for reminding and refinding [4]. AiWingman's next actions, waiting conditions, and lifecycle labels serve a related design function. Their usefulness in this product remains unmeasured.

### 2.2 Awareness dashboards and triage

Developer-awareness dashboards and feeds predate AiWingman [5]. Personalized issue-tracking views have likewise been studied as a way to reduce information overload [6]. These systems establish awareness and portfolio triage as prior concepts. AiWingman's policy is evaluated for agreement with its own frozen specification, not for relevance to a person's real work and not against these systems as a human-performance comparator.

### 2.3 Multi-agent interfaces, oversight, and observability

AutoGen Studio provides interfaces for building, running, evaluating, and debugging multi-agent workflows [7]. AgentScope, AgentBoard, and AgentOps offer multi-agent development, evaluation, monitoring, or observability abstractions [8-10]. AgentTrace proposes runtime instrumentation and structured operational, cognitive, and contextual traces [11]. AiWingman does not define or instrument an agent runtime; it retrospectively reads evidence retained by a local client.

Kitano et al. describe a dashboard for asynchronous review and human oversight of coordinating research agents [12]. Dhanorkar et al. identify a priori control, co-planning, real-time monitoring, and post-hoc review in interviews with experienced developers [13]. These are direct precedents for catch-up and oversight across agent activity. AiWingman's optional review is an implementation feature, not evidence that oversight quality improves. The Kitano workshop paper is cited by its author-hosted URL because the paper's displayed DOI is a placeholder and is not treated as a valid identifier.

Within the targeted primary-source comparison set reviewed on 23 August 2026, GitHub Copilot showed the greatest documented feature overlap. This comparison was not a systematic review and does not establish novelty. Official Copilot documentation describes monitoring parallel sessions, viewing logs and token/session information, archiving, sharing, and resuming sessions, querying past sessions, producing stand-up summaries and cost or instruction-improvement suggestions, opening app deep links, and invoking a separate Rubber Duck critic [14-16]. Those capabilities rule out feature-firstness claims. AiWingman's distinction is limited to its inspectable Codex-specific local integration, source architecture, and consent boundary.

### 2.4 Local-first design and deterministic ranking suppression

Local-first software emphasizes user control and continued operation without a service dependency [17]. Privacy engineering guidance emphasizes data minimization and explicit disclosure boundaries [18]. AiWingman's ordinary dashboard adopts these as design principles; they are not inventions or privacy proofs. The optional remote path is excluded from the offline-default claim.

Classical reject-option and selective-classification research formalizes risk-error or risk-coverage relationships for predictors [19,20]. AiWingman is not a learned predictor, has no confidence calibration, and provides no statistical guarantee. It instead uses **deterministic ranking suppression**: fixed rules return no recommendation when eligible evidence is absent, the top score is below a threshold, or top candidates are too close. The term does not imply statistical selective prediction.

## 3. System Scope and Two Separate Pipelines

AiWingman is a native Swift application targeting macOS 13 or later. SwiftUI and AppKit provide the menu-bar interface. The source package separates reusable policy and reader components from the application interface, diagnostics, and self-tests. Selected executable, bundle, preference, and application-support identifiers retain the earlier Activity Radar name so upgrades preserve existing user-owned state.

The implementation has two distinct evidence pipelines. They share selected types and presentation surfaces, but they do not perform the same aggregation.

| Pipeline | Input and reduction | Outputs and permitted claims |
| --- | --- | --- |
| Ordinary dashboard | The `CodexActivityReader` queries non-archived top-level user/root task rows in read-only SQLite mode and reduces each selected root task's own bounded rollout evidence. It does not aggregate descendant rollouts into the root. | Per-root attention and continuity cues, explicit lifecycle controls, and a user-selected local deep link back to Codex. |
| Optional Wingman analysis/review | The separate `CodexWingmanEvidenceReader` resolves parent-child task trees, scans bounded root and descendant rollout tails, and derives tree-level descriptive evidence. | Tree summaries, descriptive graph/theme signals, a maximum cumulative token-counter comparison proxy, and construction of a bounded packet for an optional consented CLI request. |

<!-- FIGURE:architecture -->

Figure 1. AiWingman's two pipelines and trust boundaries. The upper ordinary-dashboard path is local and per-root. The lower optional Wingman path constructs task trees and may cross a remote boundary only after packet preview and one-shot consent. The policy benchmark reported in this paper evaluates neither reader nor the remote path.

### 3.1 Ordinary dashboard

The ordinary path opens the local Codex SQLite database with `SQLITE_OPEN_READONLY` and `PRAGMA query_only=ON`. It selects non-archived top-level user tasks by excluding rows that appear as children in retained spawn relationships. Each selected row's own rollout is sampled within fixed bounds and reduced to a local observation such as explicit input requested, unseen final result, blocked, recently active, quiet open work, or incomplete history. The dashboard combines these observations with AiWingman-owned continuity metadata and applies the pure policy layer described in Section 4.

These SQLite controls prevent AiWingman from issuing SQL statements that modify database content; they do not establish filesystem immutability. When the source database uses write-ahead logging, SQLite's virtual filesystem may create or update the auxiliary `-shm` file while establishing shared-memory and locking state, even for a read-only/query-only connection. “Read-only SQLite” in this report therefore denotes database access mode, not a guarantee that opening a WAL database causes no auxiliary-file activity.

The ordinary dashboard may open a user-selected task through a `codex://threads/<thread-id>` deep link. This route is based on observed local behavior rather than a documented stable API. Unsupported schemas, absent files, or unreadable evidence are intended to fail neutrally instead of causing a source-state migration.

The current revision requires a standardized lexical descendant of the configured Codex root and opens each path component relative to that root with no-follow semantics. It rejects symbolic-link components and non-regular or untrusted files and bounds the session-index tail read. The SQLite adapter canonicalizes the parent path and requests a no-follow final open. These are property-specific implementation controls. They do not establish that every local input is safe or that the whole application is sandboxed. Reader robustness is outside the policy benchmark reported in Sections 5 and 6.

### 3.2 Optional Wingman analysis and review

The optional reader constructs a parent-child forest from retained spawn relationships, identifies roots and descendants, and samples bounded rollout tails across the tree. Duplicate edges are not intended to multiply evidence, and cycles or structurally inconsistent graphs are treated as compatibility failures. The tree reader is not used to make the ordinary dashboard's per-root continuity observation.

Spawned rollouts may share a cumulative token-counter lineage. Summing all counters in a tree can therefore double count shared history. The Wingman pipeline uses the largest observed cumulative counter in a tree as a **tree-level cumulative comparison proxy**. It is not a billed-token total, a period-specific quantity, a cost, a measure of usefulness, or a measure of waste. A date filter selects trees by recent activity; it does not turn a lifetime counter into usage during that date interval.

Text similarity, weighted degree, PageRank, and connected components are descriptive summaries of retained tree evidence. They are not measures of success, scientific interest, personality, cognitive load, or causal importance. They have no result in the frozen policy evaluation and are not part of the paper's core empirical claim.

### 3.3 User-owned state

Interface language, date range, and lifecycle choices are stored separately from Codex state. Continuity records pseudonymize task identifiers and are bounded by record and per-task history counts; the optional research ledger is additionally bounded by age and event count. The application therefore reads Codex state through adapters while writing its own state. It does not repair or migrate the Codex database.

## 4. Continuity Policy and Confirmation Contract

The frozen policy layer receives normalized observations and optional user-authored continuity metadata. It does not open databases, parse rollout files, construct graphs, invoke a model, or navigate the interface.

### 4.1 Precedence and deterministic scoring

Policy evaluation follows four stages:

1. Apply absolute deferrals.
2. Exclude an eligible item if its history is incomplete.
3. Derive ordered, content-free reason codes and integer weights.
4. Sort eligible candidates and apply deterministic ranking-suppression rules.

A future snooze is deferred as `snoozed`; a non-empty waiting condition is deferred as `waitingOnExternal`. Terminal work is also deferred when the frozen terminal conditions hold and no direct attention signal, near deadline, or due snooze overrides that state. Deferred items are not scored.

An incomplete, non-deferred item is excluded from scoring. Its presence does **not** suppress a recommendation supported by another complete item. If no candidate remains and an eligible incomplete item was observed, the policy returns `incompleteHistory` and exposes no ranking.

Table 1 gives the normative reason order and weights. The order is part of serialized output.

| Order | Condition | Reason code | Weight |
| ---: | --- | --- | ---: |
| 1 | Explicit input requested | `explicitInput` | 100 |
| 1 | Blocked goal | `goalBlocked` | 90 |
| 1 | Unseen final result | `unseenResult` | 80 |
| 1 | Usage limited | `usageLimited` | 70 |
| 1 | Budget limited | `budgetLimited` | 70 |
| 2 | Deadline due or overdue | `deadlineOverdue` | 65 |
| 2 | Deadline within one day | `deadlineWithinDay` | 55 |
| 2 | Deadline within three days | `deadlineWithinThreeDays` | 40 |
| 2 | Deadline within seven days | `deadlineWithinWeek` | 20 |
| 3 | Planned return is due and no later opening exists | `plannedReturnDue` | 45 |
| 4 | Critical importance | `criticalImportance` | 30 |
| 4 | High importance | `highImportance` | 20 |
| 4 | Low importance | `lowImportance` | -10 |
| 5 | Non-empty next action | `nextActionRecorded` | 10 |
| 5 | No plan and age 7 to less than 30 days | `agingWithoutPlan` | 12 |
| 5 | No plan and age at least 30 days | `agingWithoutPlan` | 18 |
| 6 | Recently active execution | `recentlyActive` | 8 |
| 7 | Opened between 0 and 15 minutes ago, inclusive | `recentlyOpened` | -15 |

Candidates are sorted by descending score and then ascending activity identifier. A recommendation requires a score of at least 30 and a lead of at least 10 over the second candidate. A top score below 30 returns `insufficientEvidence`; a lead below 10 returns `competingSignals`. When the policy returns no recommendation, it exposes no ranked candidates. A result with no candidates distinguishes `incompleteHistory`, `noEligibleWork`, and `insufficientEvidence` according to the frozen precedence.

<!-- FIGURE:triage -->

Figure 2. Frozen continuity-policy flow. Future snooze, waiting, and terminal rules defer an item; incomplete eligible history excludes that item; remaining complete items are scored; a score below 30 or a lead below 10 suppresses the ranking. An incomplete item does not suppress a recommendation from another complete item.

### 4.2 Lifecycle states

Observed evidence and lifecycle decisions are separate. A user confirmation is authoritative and maps directly to its reversible lifecycle state. Only explicit `abandoned` or `obsolete` confirmations can produce `abandonedConfirmed` or `obsoleteConfirmed`.

Without confirmation, the policy maps direct attention to `waitingHuman`, `blocked`, or `current`; an external waiting condition to `waitingExternal`; future snoozes, paused work, and sufficiently old quiet work to `dormant`; completed work to `completed`; and missing or unknown evidence to `uncertain`. Age can add inactive-evidence codes, but silence, age, and an aborted turn cannot infer a confirmed obsolete or abandoned state.

### 4.3 Optional remote-review boundary

The dashboard starts no background agent request. A Wingman request is separately triggered. The user is shown the intended user-derived packet before one-shot consent. The packet builder intentionally omits raw task identifiers, raw paths, configuration files, tool outputs, and authentication-file contents. It always includes sanitized task titles and may include sanitized prompt excerpts only after an explicit opt-in. Human-authored continuity text is excluded.

Sanitization is best-effort and cannot prove removal of every secret, especially a secret embedded in a title or allowed text. Users must inspect the preview. Unexpected CLI JSONL items or tool events invalidate the returned review, but invalidation does not prove that the child process performed no earlier filesystem read, network exchange, or tool attempt. The child read-only mode is not an operating-system sandbox for the application.

The CLI is invoked with `--ephemeral`, which requests a turn intended not to save a local rollout; it does not prove that no local artifact exists and does not define service-side retention. The compatibility probe and review use private temporary roots whose names begin with the exact prefixes `ActivityRadar-CLI-Probe-` and `ActivityRadar-Wingman-`, respectively. A process-wide gate permits only one such remote operation at a time. Normal completion and error paths attempt removal and verify absence. If absence cannot be verified, the result is rejected, the unresolved root is latched, and later remote operations in the same application process retry cleanup and remain blocked while it fails. A crash or forced termination can bypass that path and leave a prefixed directory; restarting the application does not itself prove that residue was removed. These are implementation controls outside the frozen policy benchmark, not proof of security isolation or complete credential removal under every failure mode.

The ordinary dashboard contains no intended network path in the evaluated source architecture. Source-level checks for network APIs are bounded static evidence, not runtime non-interference. The optional CLI path intentionally reaches an external service after consent.

## 5. Evaluation Method

### 5.1 Scope and research questions

The evaluation covers only `WorkContinuityRanker` and `WorkContinuityLifecycle`. It excludes the ordinary reader, Wingman tree reader, Codex database and rollout compatibility, graph analysis, token proxies, interface behavior, deep links, diagnostics, local storage, optional CLI execution, remote output, and user outcomes.

The study asks four questions:

- **RQ1, conformance:** Does the Swift policy match every expected output in the frozen synthetic corpus?
- **RQ2, repeatability and content boundary:** Are canonical policy outputs stable across repeated executions on one recorded machine, free of the five seeded content sentinels, and free of inferred confirmed-obsolete or confirmed-abandoned states?
- **RQ3, technical comparisons:** How often do two deliberately simplified rules produce the same selected identifier as the frozen policy, and how often do they select an item where the frozen policy requires no recommendation?
- **RQ4, descriptive performance:** What latency distribution and process-level peak resident memory are observed for synthetic portfolios of 10, 50, 200, and 1,000 inputs?

### 5.2 Freeze and chronology

The evaluation artifacts were created in a staged chronology so expected outputs were fixed before the Swift benchmark ran.

| Stage | Immutable checkpoint | Role |
| --- | --- | --- |
| Public source release | `5e212181ae177cd555ab6bb92f5f71ac8be9173a`, tag `v1.2.0-beta.2` | Historical product and CI evidence; not the policy-result commit |
| Protocol freeze | `53aa3e28862ff76092ad83d1347635fb1209a17d` | Written specification, Python generator, 155-fixture corpus, and freeze manifest |
| Swift runner | `fa5186e5d04fedfd75daac72e533a1daf9dbfa89` | Standalone benchmark executable; clean detached-worktree execution is author-reported rather than machine-attested by the result files |
| Result package | `e46686588793173d1b299b1829a92dbab7e9528d` | arm64 report, 100-process summary, execution script, and result manifest |

The specification SHA-256 is `ee6ab6568a3fcf8332facf9ef0a2d3bae66ab15d7f09a63ca6cbef6ce44e6f11`. The corpus SHA-256 is `183025163326aeb7f95470d2ecf494b31bc8239c8abb3e74e939967cf3ad8f30`, and the Python generator SHA-256 is `2c27f2bd7950e0aa26b8878ae27e13dfcd3332571f32b61444feb1111a8aae3c`. The freeze manifest records 75 triage fixtures and 80 lifecycle fixtures, for 155 total.

The authors report building and running the Swift checkpoint from a clean detached worktree. The V1 result package does not independently attest that procedure: the fresh-process driver's `--runner-commit` value is operator supplied, and the driver neither compares it with Git `HEAD`, requires a clean worktree, nor records the built executable's hash. The checkpoint association is therefore a provenance boundary to be verified through the revision, worktree-status, and source-hash checks in Section 9.

The Python standard-library generator does not import, invoke, parse, or copy Swift source. It implements the written specification as a separate oracle at the language boundary. However, the same project produced the specification, oracle, fixtures, and Swift implementation. This is therefore a **same-project, specification-derived, separately implemented oracle**, not external independent validation.

### 5.3 Exact-output checks

The Swift runner strictly decodes the corpus and checks schema version, counts, and hashes. For triage fixtures it compares the recommendation or no-recommendation result, candidate identifiers and order, scores, ordered reason codes, weights, evidence times, and deferrals. For lifecycle fixtures it compares state, ordered evidence codes, evidence times, and ages. A fixture passes only if every specified field matches.

For in-process repeatability, every fixture is evaluated 100 times. Canonical JSON uses sorted keys, and a corpus digest frames the frozen fixture identifier and canonical actual policy output in frozen order. Timing, environment metadata, and expected outputs are excluded from the digest.

Fresh-process repeatability launches the release benchmark 100 times. Each process checks conformance over all 155 fixtures and separately performs the runner's 100-repetition-per-fixture determinism loop before returning one canonical corpus-output digest. The fresh-process evidence unit is therefore the process-level digest: 100/100 processes passed and returned one unique digest. It is not an additional 15,500-evaluation denominator.

**Result-package erratum.** The archived cross-process JSON contains `"evaluationCount": 15500`, computed by the V1 driver as 100 processes multiplied by 155 fixtures; `RESULTS_MANIFEST_V1.json` carries the analogous `crossProcessEvaluationCount`. Those labels describe process-fixture summary coverage, not individual policy-function calls. The fixed determinism loop actually contains 1,550,000 policy evaluations across the 100 fresh processes (100 processes multiplied by 155 fixtures multiplied by 100 repetitions), excluding separate conformance and performance calls. Draft 0.3 preserves the committed JSON files and hashes, treats both field names as an erratum recorded in `Research/results/RESULTS_ERRATA_V1.md`, and reports fresh-process repeatability as 100/100 process-level digests rather than using either count as a total of every call made by those processes.

The content-neutrality check searches serialized actual policy-output data transfer objects for five sentinels seeded in title, path, checkpoint, next-action, and waiting text. It does not inspect either reader, the UI, logs outside the runner, diagnostics, preview packets, or remote requests. The confirmation-gated lifecycle invariant is checked over 70 fixtures without user confirmation; any `obsoleteConfirmed` or `abandonedConfirmed` output is a violation.

### 5.4 Technical baselines

The two baselines are fixed technical contrasts, not competing products and not human-quality measures.

1. **Recency-only** always selects the input with the latest timeline activity, breaking ties by ascending identifier. It ignores deferrals, history completeness, metadata, score thresholds, and lead suppression.
2. **Same-score/no-suppression** applies the frozen deferrals, incomplete-history exclusion, weights, sorting, and identifier tie-break, but removes the 30-point threshold and 10-point lead requirement.

For each of the 75 triage fixtures, exact decision agreement means equality of the recommended activity identifier; `nil` means no recommendation. A must-suppress violation occurs when a baseline selects an identifier for a fixture whose frozen expected result exposes no recommendation.

### 5.5 Performance procedure and environment

The runner performs five warm-up calls followed by 30 measured repetitions for each input size. It reports the median, linearly interpolated p95, interquartile range, and maximum using `DispatchTime.uptimeNanoseconds`. Triage measures one ranking call over (N) synthetic inputs. Lifecycle measures (N) assessment calls over the same synthetic inputs.

The recorded environment was a MacBook Pro model `Mac16,7` with Apple M4 Pro, 14 active processors, 48 GB memory, arm64 architecture, macOS 26.6.2 build 25G83, and Apple Swift 6.3.3 targeting `arm64-apple-macosx26.0`. The benchmark used a release build. Process peak resident memory was sampled after all series using macOS `getrusage(RUSAGE_SELF)`; it is a process-lifetime peak, not an allocation total or a per-operation measurement.

## 6. Results

### 6.1 Conformance, repeatability, and bounded contract checks

Table 2 summarizes the machine-readable policy-result ledger. The primary report SHA-256 is `fa7e271a436be62bf9c7f9979122ccc6a01d36fe03abaea7b4a0277472a9957e`. The fresh-process summary SHA-256 is `9d1dcd88b2dca1672ccfabee076ee2c9274ebb63458275b30e6a4269b37b4af1`.

| Check | Denominator | Result | Supported interpretation |
| --- | ---: | ---: | --- |
| Frozen exact-output conformance | 155 fixtures | 155/155 passed | Swift policy matched all same-project specification-derived expected outputs |
| In-process repeatability | 155 × 100 | 15,500/15,500 passed | One canonical policy-output digest on the recorded process and machine |
| Fresh-process repeatability | 100 fresh processes | 100/100 passed; one unique digest | Every process produced the same 155-fixture corpus digest on one arm64 machine after its internal repetition loop |
| Content-neutral policy outputs | 155 outputs; 5 sentinels | 0 sentinel occurrences | Seeded content did not appear in the serialized pure-policy output surface |
| Confirmation-gated lifecycle invariant | 70 unconfirmed fixtures | 0 confirmed-state violations | No unconfirmed fixture produced confirmed obsolete or abandoned |

The canonical corpus-output digest was `fd72e52b8098d2f62f6c6f7ccc6de7e744de7ed03722d08c7f983527601db8e6` in the primary run and all 100 fresh processes. These results answer RQ1 and the frozen portion of RQ2 affirmatively on the recorded arm64 environment. They do not establish cross-architecture determinism, external correctness, reader privacy, or remote-model repeatability.

### 6.2 Technical baseline comparisons

Table 3 reports exact decision agreement and must-suppress violations over all 75 triage fixtures.

| Technical contrast | Exact agreement with frozen decision | Must-suppress violations |
| --- | ---: | ---: |
| Recency-only | 40/75 (53.333%) | 35 |
| Same-score/no-suppression | 59/75 (78.667%) | 16 |

The recency-only rule disagreed with the frozen policy in 35 fixtures; every disagreement was also a case where it selected an item despite a frozen no-recommendation result. The same-score/no-suppression rule disagreed in 16 fixtures, again all must-suppress cases. The comparison shows that deferrals, evidence completeness, score thresholds, and lead rules materially alter synthetic contract outputs. It does not show that the frozen policy is more useful, accurate, efficient, or preferable for people.

### 6.3 Descriptive performance

Table 4 reports the complete summary statistics in milliseconds. Every cell is based on 30 measured repetitions after five warm-ups.

| Operation | Inputs | Median (ms) | p95 (ms) | IQR (ms) | Maximum (ms) |
| --- | ---: | ---: | ---: | ---: | ---: |
| Triage portfolio | 10 | 0.003750 | 0.003856 | 0.000042 | 0.012542 |
| Triage portfolio | 50 | 0.023167 | 0.024065 | 0.000291 | 0.039625 |
| Triage portfolio | 200 | 0.093563 | 0.094806 | 0.000240 | 0.095125 |
| Triage portfolio | 1,000 | 0.510688 | 0.566846 | 0.029230 | 0.568875 |
| Lifecycle batch | 10 | 0.003625 | 0.003690 | 0.000000 | 0.003833 |
| Lifecycle batch | 50 | 0.019042 | 0.019360 | 0.000115 | 0.019416 |
| Lifecycle batch | 200 | 0.075771 | 0.094915 | 0.002667 | 0.102875 |
| Lifecycle batch | 1,000 | 0.387979 | 0.425284 | 0.018093 | 0.470666 |

The process-lifetime peak resident memory after all performance series was 12,992,512 bytes, approximately 12.4 MiB. Because that value covers the entire runner process and all series, it cannot be attributed to a particular operation or input size. The latency and memory results are descriptive for synthetic policy inputs on one machine and cannot be converted into human time saved.

### 6.4 Historical release engineering evidence

GitHub Actions run `32648392604` evaluated the older public release commit `5e212181ae177cd555ab6bb92f5f71ac8be9173a` on 23 August 2026. The arm64 macOS 15 and native x86_64 macOS 15 jobs each reported 52 Swift tests and 16 deterministic self-tests passed. The Intel job built the release application; the arm64 gate also ran enumerated source, diagnostics, storage, manifest, and local Universal 2 package checks.

This is regression and packaging evidence only for the named release commit. It is separate from the arm64 policy benchmark at `fa5186e5...` and does not validate the later manuscript, protocol, reader-hardening, or result branch. A successful Swift command with zero discovered tests is not counted as evidence.

## 7. Limitations and Threats to Validity

**Same-project oracle.** The written specification, Python oracle, fixtures, Swift implementation, and benchmark runner were produced within the same project. Language-boundary separation reduces direct code reuse but does not provide external independence. Shared misunderstandings can survive 155/155 conformance.

**Synthetic and finite coverage.** The 155 fixtures cover the frozen policy contract, not every state combination. Content neutrality covers five sentinels and only the serialized policy-output surface. It is not a general noninterference, privacy, or secret-removal proof.

**Policy-only scope.** Neither Codex reader, graph construction, token proxy, UI, deep link, local storage, diagnostics, preview, child process, or remote response is part of the reported benchmark. Reader and remote-boundary tests must be reported separately and must not be added to the 155-fixture denominator.

**Unreported gates.** No separately frozen metamorphic ledger, complete adversarial reader ledger, end-to-end remote disclosure ledger, or current-branch cross-architecture release ledger is reported in this result package. The absence of those results is an open gate, not a pass inferred from unit tests.

**One-machine policy result.** Both repeatability checks ran on one arm64 Mac. One hundred fresh processes do not establish native x86_64 or cross-machine equality. Historical dual-architecture regression tests ran at a different commit and cannot fill that gap.

**Simplified baselines.** The baselines deliberately remove policy mechanisms. Their disagreement demonstrates mechanical policy effects but provides no external reference standard, user preference, or comparative superiority.

**Performance scope.** Timings use synthetic normalized inputs and exclude database I/O, rollout parsing, interface rendering, graph analysis, and remote calls. The process-level memory peak is not isolated by series.

**Undocumented integration and SQLite boundary.** AiWingman depends on observed Codex filenames, SQLite schemas, JSONL events, and deep-link routes that may change. Read-only/query-only opening prevents application SQL writes to database content but, for a WAL database, does not exclude SQLite VFS creation or update of the auxiliary `-shm` file. Neutral failure and logical read-only access cannot establish filesystem immutability or create a stable third-party API contract.

**Token and graph interpretation.** The optional tree maximum is a cumulative comparison proxy. It is neither period usage nor billed, useful, or wasted tokens. Graph summaries are descriptive and unevaluated.

**Remote and security boundary.** Packet minimization, preview, opt-in, event rejection, path checks, serialized temporary-auth use, and verified normal/error cleanup are narrow controls. Best-effort sanitization cannot guarantee secret removal. Output rejection does not prove absence of prior I/O, and a crash can leave a temporary root before cleanup or latch handling completes. The application is not claimed to be security-isolated, and no external security audit is reported.

**No human-outcome evidence.** No participants or private task histories were studied. The report cannot answer whether AiWingman improves recall, resumption time, workload, decision quality, productivity, or token use.

**Revision reproducibility remains gated.** At this draft, the policy-result checkpoints and major-revision work are local review checkpoints until pushed. The final revision still requires an exact public manifest, privacy scan, enforced non-zero test discovery, full release gate, document rebuild, all-page inspection, and a second blind-style review at one immutable commit. No preprint upload or submission is claimed.

## 8. Discussion

The evaluation supports a narrow conclusion: the Swift continuity policy reproduced every output of a frozen same-project synthetic specification on one machine, remained byte-stable across the recorded repetitions, omitted five seeded content sentinels from its serialized output surface, and respected the explicit-confirmation boundary in the tested lifecycle fixtures. It does not establish whether the policy chooses the right task for a person.

The baseline results are useful as implementation evidence because they locate the effect of policy structure. A pure recency rule ignored all 35 frozen no-recommendation cases, while retaining scores but removing the threshold and lead rules ignored 16. This shows that ranking suppression is active rather than decorative. It does not establish calibrated uncertainty or improved decisions.

The product-level design contribution is likewise integrative. Task context, reminders, dashboards, post-hoc oversight, and agent-session summaries are established. AiWingman combines selected versions of these ideas around locally retained Codex evidence and keeps three distinctions explicit: ordinary per-root inspection versus optional task-tree analysis; observed evidence versus user-owned lifecycle confirmation; and offline-default local analysis versus a previewed, consented remote request.

Further evidence should remain finite and claim-driven. A native x86_64 policy run would address cross-architecture equality. Frozen adversarial ledgers for both readers and the temporary remote boundary would address only enumerated path, graph, disclosure, event, and cleanup properties. External reproduction of the oracle would reduce same-project bias. A later human study would require a new protocol and would be necessary before any efficacy claim.

## 9. Reproducibility and Availability

The public source release is available at:

https://github.com/mehmetsolakedu/activity-radar

The historical source tag and CI record are:

- Release `v1.2.0-beta.2`: https://github.com/mehmetsolakedu/activity-radar/releases/tag/v1.2.0-beta.2
- GitHub Actions run `32648392604`: https://github.com/mehmetsolakedu/activity-radar/actions/runs/32648392604

The protocol, runner, result, erratum, and manuscript-revision checkpoints named in this report are local review checkpoints at Draft 0.3. They must not be described as publicly retrievable until they are pushed and an immutable public result commit or release is verified. The final public URL and artifact hashes should be added only after that gate.

After those checkpoints become public, reproduction should begin from a separate detached worktree at the exact runner revision:

```sh
git worktree add --detach ../aiwingman-fa5186e \
  fa5186e5d04fedfd75daac72e533a1daf9dbfa89
cd ../aiwingman-fa5186e
git rev-parse HEAD
git status --porcelain
shasum -a 256 \
  Package.swift \
  Sources/AiWingmanResearchBenchmark/main.swift \
  Research/protocol/SPECIFICATION_V1.md \
  Research/generate_continuity_corpus.py \
  Research/fixtures/continuity-policy-corpus-v1.json
```

The `git rev-parse HEAD` command must report `fa5186e5d04fedfd75daac72e533a1daf9dbfa89`, and `git status --porcelain` must be empty. In the listed order, the expected SHA-256 values are `03389531d1cd8aea9222e2663a603b89fbacbba1fa48e4813d2e415dae107425`, `068f085273f8a7638c7a0e05d13b32f0f39cc3ed519bd2327b4ef5551417906b`, `ee6ab6568a3fcf8332facf9ef0a2d3bae66ab15d7f09a63ca6cbef6ce44e6f11`, `2c27f2bd7950e0aa26b8878ae27e13dfcd3332571f32b61444feb1111a8aae3c`, and `183025163326aeb7f95470d2ecf494b31bc8239c8abb3e74e939967cf3ad8f30`. These checks establish source identity before building; the V1 result files themselves did not attest executable provenance.

The primary benchmark command is:

```sh
swift run -c release AiWingmanResearchBenchmark \
  --corpus Research/fixtures/continuity-policy-corpus-v1.json \
  --output Research/results/continuity-benchmark-reproduction.json
```

The fresh-process driver additionally requires the built executable and the
runner commit recorded in the result ledger:

```sh
swift build -c release --product AiWingmanResearchBenchmark

python3 Research/run_cross_process_determinism.py \
  --executable .build/release/AiWingmanResearchBenchmark \
  --corpus Research/fixtures/continuity-policy-corpus-v1.json \
  --output Research/results/cross-process-determinism-reproduction.json \
  --runner-commit fa5186e5d04fedfd75daac72e533a1daf9dbfa89 \
  --processes 100 \
  --work-directory .
```

The reproduction target is 155/155 exact conformance and the canonical corpus digest `fd72e52b8098d2f62f6c6f7ccc6de7e744de7ed03722d08c7f983527601db8e6`, followed by 100/100 fresh processes returning that digest. A new full-report JSON is not expected to reproduce the archived report SHA-256 because timestamps, performance measurements, and per-run report hashes can differ. The archived result-manifest hashes instead verify the integrity of the archived artifacts. The repository includes versioned citation metadata in keeping with software-citation principles [21] and is licensed under the MIT License. This manuscript is intended for CC BY 4.0 distribution only after the named author confirms the declaration and licensing gates. Public fixtures are synthetic. Private Codex databases, rollout files, task text, local paths, credentials, and real-work screenshots are outside the publication package.

## 10. Claim Ledger

| Claim | Status in Draft 0.3 | Exact boundary |
| --- | --- | --- |
| AiWingman is an open-source Codex-specific retrospective overlay | Supported as a project description | Independent community software; not an official OpenAI product or stable API integration |
| Ordinary dashboard and optional Wingman use separate readers | Supported by source architecture | Ordinary path is per-root; tree aggregation and graph signals belong only to Wingman |
| Codex source state is queried through logical read-only adapters | Implementation property under engineering review | No application SQL write to database content; WAL-mode SQLite VFS may create or update `-shm`; application writes its own state; no whole-application write-free claim |
| Pure Swift continuity policy conforms to the frozen corpus | 155/155 passed on recorded arm64 environment | Same-project specification-derived oracle; policy layer only |
| Local policy output is repeatable | 15,500 within-process evaluations produced one digest; 100/100 fresh processes returned that digest | The archived fresh-process `evaluationCount` is an erratum, not a function-call denominator; one machine and architecture; excludes readers, UI, graphs, and remote output |
| Serialized policy output omitted seeded content | Zero occurrences for five sentinels over 155 outputs | Only specified output DTOs and sentinels; not a privacy or secret-removal proof |
| Confirmed obsolete/abandoned requires user confirmation | Zero violations over 70 unconfirmed fixtures | Synthetic lifecycle contract only; not an audit of every application path |
| Ranking suppression changes contract decisions | Baselines violated 35 and 16 frozen no-recommendation cases | Mechanical synthetic comparison; no quality or superiority inference |
| Policy performance is sub-millisecond at 1,000 inputs on the measured Mac | Median 0.511 ms triage and 0.388 ms lifecycle | Normalized synthetic policy inputs on one named environment only |
| Historical dual-architecture release regression evidence | 52 tests and 16 self-tests passed per architecture at `5e212181...` | Older release commit; not current policy-result or revision branch |
| Wingman tree token quantity measures exact cost or waste | Not supported | Maximum cumulative tree counter is only a comparison proxy |
| Graph signals measure importance or success | Not supported | Descriptive and unevaluated |
| Runner revision and clean-worktree provenance are machine-attested by V1 results | Not supported | Clean detached execution is author-reported; reproduction must verify `HEAD`, empty status, and source hashes before building |
| Optional remote review is security-isolated, residue-free under crashes, or sole-context | Not supported | Preview, a process-wide gate, two bounded temporary prefixes, and verified normal/error cleanup narrow intended disclosure; they do not prove isolation, crash cleanup, or service retention |
| Human efficacy or productivity benefit | Untested | No participants or outcome measures |
| Comparative superiority or first-of-kind status | Not claimed | Prior research and current products provide overlapping capabilities |
| Cross-architecture policy determinism and current-branch release reproducibility | Open gate | Requires exact result commit, native x86_64 run, manifest match, and full release gate |

## 11. Declarations and Author Confirmation Gates

**Ethics and data statement.** This report describes software architecture and synthetic engineering evaluation. It collected no human-participant, animal, survey, interview, or private task-history data. No human-outcome inference is made.

**Funding.** Author confirmation is required before public deposit. The final statement must identify all funding or explicitly state that no external funding supported the work.

**Competing interests.** Author confirmation is required before public deposit. The final statement must disclose relevant interests or explicitly declare none.

**Author contribution.** Mehmet Solak conceived the product direction, defined the intended use, supervised iterative development, and is the sole named author. The author must confirm this wording and responsibility for the final manuscript.

**AI assistance.** OpenAI Codex assisted with source discovery, code inspection, literature organization, benchmark and manuscript development, and document formatting. The named author must verify every claim and reference, revise the prose as needed, and assume full responsibility. AI is not listed as an author.

**Software and manuscript licenses.** The software is distributed under the MIT License. The manuscript is intended for Creative Commons Attribution 4.0 International distribution only after the named author confirms the right to grant that license.

**Identity and correspondence.** Before any deposit, the named author must personally confirm the public name form “Mehmet Solak,” ownership of ORCID `0000-0002-0800-0334`, the Siirt University Biosystems Engineering affiliation, and `mehmetsolak@siirt.edu.tr` as the correspondence address. The same identity must appear in the manuscript, document metadata, submission metadata, citation file, and portal.

**Deposit boundary.** No repository push, preprint upload, or portal submission is represented by this draft. Public deposit requires a separate final-file review and explicit author approval. A preprint identifier would document deposit, not peer-review acceptance.

## References

[1] M. Kersten and G. C. Murphy, “Using Task Context to Improve Programmer Productivity,” Proceedings of the 14th ACM SIGSOFT International Symposium on Foundations of Software Engineering, 2006. https://doi.org/10.1145/1181775.1181777

[2] C. Parnin and R. DeLine, “Evaluating Cues for Resuming Interrupted Programming Tasks,” Proceedings of the SIGCHI Conference on Human Factors in Computing Systems, 2010. https://doi.org/10.1145/1753326.1753342

[3] C. Parnin and S. Rugaber, “Resumption Strategies for Interrupted Programming Tasks,” Software Quality Journal, vol. 19, pp. 5-34, 2011. https://doi.org/10.1007/s11219-010-9104-9

[4] M.-A. Storey, J. Ryall, J. Singer, D. Myers, L.-T. Cheng, and M. Muller, “How Software Developers Use Tagging to Support Reminding and Refinding,” IEEE Transactions on Software Engineering, vol. 35, no. 4, pp. 470-483, 2009. https://doi.org/10.1109/TSE.2009.15

[5] C. Treude and M.-A. Storey, “Awareness 2.0: Staying Aware of Projects, Developers and Tasks Using Dashboards and Feeds,” Proceedings of the 32nd ACM/IEEE International Conference on Software Engineering, 2010. https://doi.org/10.1145/1806799.1806854

[6] O. Baysal, R. Holmes, and M. W. Godfrey, “No Issue Left Behind: Reducing Information Overload in Issue Tracking,” Proceedings of the 22nd ACM SIGSOFT International Symposium on Foundations of Software Engineering, pp. 666-677, 2014. https://doi.org/10.1145/2635868.2635887

[7] V. Dibia et al., “AutoGen Studio: A No-Code Developer Tool for Building and Debugging Multi-Agent Systems,” Proceedings of the 2024 Conference on Empirical Methods in Natural Language Processing: System Demonstrations, pp. 72-79, 2024. https://doi.org/10.18653/v1/2024.emnlp-demo.8

[8] D. Gao et al., “AgentScope: A Flexible yet Robust Multi-Agent Platform,” arXiv:2402.14034, 2024. https://arxiv.org/abs/2402.14034

[9] C. Ma, J. Zhang, Z. Zhu, C. Yang, Y. Yang, Y. Jin, Z. Lan, L. Kong, and J. He, “AgentBoard: An Analytical Evaluation Board of Multi-turn LLM Agents,” Advances in Neural Information Processing Systems, vol. 37, Datasets and Benchmarks Track, 2024. https://doi.org/10.52202/079017-2365

[10] L. Dong, Q. Lu, and L. Zhu, “AgentOps: Enabling Observability of LLM Agents,” arXiv:2411.05285, 2024. https://arxiv.org/abs/2411.05285

[11] A. AlSayyad, K. Y. Huang, and R. Pal, “AgentTrace: A Structured Logging Framework for Agent System Observability,” arXiv:2602.10133, 2026. https://arxiv.org/abs/2602.10133

[12] B. Kitano, E. Carlson, B. Russett, and A. Kesling, “Managing Multi-Agent Research Systems: A Dashboard for Human Oversight of Coordinating AI Agents,” Proceedings of Human-centered Evaluation and Auditing of Language Models (HEAL@CHI'26), 4 pp., 2026. https://heal-workshop.github.io/chi2026_papers/Managing%20Multi-Agent%20Research%20Systems%20A%20Dashboard%20for%20Human%20Oversight%20of%20Coordin.pdf

[13] S. Dhanorkar, S. Passi, and M. Vorvoreanu, “Human Oversight of Agentic Systems in Practice: Examining the Oversight Work, Challenges, and Heuristics of Developers Using Software Agents,” arXiv:2606.05391, 2026. https://arxiv.org/abs/2606.05391

[14] GitHub, “Managing Agent Sessions,” GitHub Copilot documentation. Accessed 23 August 2026. https://docs.github.com/en/copilot/how-tos/copilot-on-github/use-copilot-agents/manage-and-track-agents

[15] GitHub, “About GitHub Copilot CLI Session Data,” GitHub Copilot documentation. Accessed 23 August 2026. https://docs.github.com/en/copilot/concepts/agents/copilot-cli/chronicle

[16] GitHub, “Working with Agent Sessions in the GitHub Copilot App,” GitHub Copilot documentation. Accessed 23 August 2026. https://docs.github.com/en/copilot/how-tos/github-copilot-app/agent-sessions

[17] M. Kleppmann, A. Wiggins, P. van Hardenberg, and M. McGranaghan, “Local-First Software: You Own Your Data, in Spite of the Cloud,” Proceedings of the ACM SIGPLAN International Symposium on New Ideas, New Paradigms, and Reflections on Programming and Software, pp. 154-178, 2019. https://doi.org/10.1145/3359591.3359737

[18] IETF, “Privacy Considerations for Internet Protocols,” RFC 6973, 2013. https://www.rfc-editor.org/rfc/rfc6973.html

[19] C. K. Chow, “On Optimum Recognition Error and Reject Tradeoff,” IEEE Transactions on Information Theory, vol. 16, no. 1, pp. 41-46, 1970. https://doi.org/10.1109/TIT.1970.1054406

[20] R. El-Yaniv and Y. Wiener, “On the Foundations of Noise-Free Selective Classification,” Journal of Machine Learning Research, vol. 11, no. 53, pp. 1605-1641, 2010. https://www.jmlr.org/papers/v11/el-yaniv10a.html

[21] A. M. Smith, D. S. Katz, K. E. Niemeyer, and FORCE11 Software Citation Working Group, “Software Citation Principles,” PeerJ Computer Science, vol. 2, e86, 2016. https://doi.org/10.7717/peerj-cs.86
