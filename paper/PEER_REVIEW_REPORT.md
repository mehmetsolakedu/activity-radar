# Peer-review audit of the AiWingman technical report

> **Historical internal audit of Draft 0.1.** Retained for correction provenance;
> this is not the current submission decision and is not external peer review.
> Later corrections are recorded in the V1 result errata, Draft 0.5 manuscript,
> submission-readiness record, and later claim-and-artifact reviews.
> The later evaluation did not satisfy every broader ledger proposed below: the
> primary result archived summary counts and failures rather than passing
> per-fixture rows, and no frozen G4-G6 or G8 ledger was added. The current paper
> was therefore narrowed to the checks actually archived and labels those
> omitted gates as unreported. This historical checklist must not be read as
> completed evidence. A later bounded related-work audit also identified native
> Codex Activity, goal, App Server, and review surfaces plus closer 2024-2026
> trajectory interfaces. It supersedes the “potentially defensible”
> Codex-specific novelty wording below; the current manuscript treats direct
> SQLite and deep-link access as compatibility risk, not novelty.

**Audit date:** 23 August 2026  
**Manuscript reviewed:** `paper/aiwingman_technical_report.md`, draft 0.1  
**Software release claimed by the manuscript:** `v1.2.0-beta.2`, commit `5e212181ae177cd555ab6bb92f5f71ac8be9173a`  
**Protocol checkpoint additionally inspected:** commit `53aa3e28862ff76092ad83d1347635fb1209a17d`  
**Review type:** internal, adversarial, reviewer-facing audit of claims, methods, related work, artifact evidence, security boundaries, and submission readiness. This is not external peer review or independent validation.

## Decision

**MAJOR REVISION / DO NOT SUBMIT THE CURRENT DRAFT.**

The project is credible as an open software artifact, and the evaluated public release has real regression evidence. The present paper is nevertheless not ready for public deposit. Two central technical descriptions do not match the implementation; the novelty argument omits direct prior work and current product baselines; the publication benchmark has not yet produced results; several security statements exceed what the code and tests establish; and the current manuscript/protocol branch fails its own public-manifest gate.

This decision is not a judgment that the product is trivial or without publication value. It means that the defensible contribution is narrower than the current framing and that the evidence required for even that narrower contribution is not yet complete.

The most defensible contribution statement is:

> AiWingman is a Codex-specific, read-only and offline-default retrospective work-continuity overlay that separates observed task evidence from explicit, reversible user lifecycle decisions and applies deterministic ranking-suppression rules under specified evidence conditions.

This should be presented as a design integration and open software artifact, not as the first agent dashboard, a statistically calibrated selective-prediction method, a productivity intervention, a token-waste detector, or a security-isolated execution system.

## Review basis and evidence boundary

The audit distinguished four evidence classes:

1. **Verified release evidence.** GitHub Actions run `32648392604` for release commit `5e212181...` reports 52 Swift tests and 16 self-tests on both the arm64 and native x86_64 jobs, plus the enumerated release checks. This supports only those regression and packaging properties at that exact commit.
2. **Source inspection.** Claims were compared with the Swift sources, packaging scripts, public manifest, and manuscript text at the checkpoints named above.
3. **Local audit observations.** The current branch's release gate, tag verification, and PDF metadata were inspected directly. These observations are diagnostic, not cross-machine validation.
4. **Not yet established.** Human benefit, comparative superiority, exact token waste, runtime network non-interference, sole-context isolation, externally independent conformance, and broad Codex compatibility remain untested.

The release commit and the manuscript/protocol branch must not be treated as the same evaluated artifact. Results generated after `5e212181...` require a new immutable commit identifier and a new claim ledger.

## P0 findings — submission blockers

### P0.1 The manuscript conflates two distinct data pipelines

The architecture section says that the **ordinary path** resolves a parent-child forest, groups spawned tasks under the root, performs bounded tree sampling, and computes graph signals (`paper/aiwingman_technical_report.md:77-97`, especially line 83). That is not the ordinary dashboard implementation at the audited checkpoint.

The ordinary UI instantiates `CodexActivityReader` (`Sources/ActivityRadar/RadarViewModel.swift:130-132`). That reader:

- selects non-archived, top-level user/root rows using `NOT EXISTS` on child edges (`Sources/ActivityRadarCore/CodexActivityReader.swift:249-279` at commit `53aa3e2`); and
- reads and reduces each selected row's own rollout (`Sources/ActivityRadarCore/CodexActivityReader.swift:155-198`).

The separate optional Wingman reader is the component that constructs the graph, finds roots and descendants, takes the maximum cumulative token counter over a tree, orders task trees, and scans root plus descendant rollout tails (`Sources/ActivityRadarCore/CodexWingmanEvidenceReader.swift:109-159`).

**Required correction.** Split the architecture, figures, methods, limitations, and claim ledger into two explicitly named pipelines:

| Pipeline | Actual scope | Claims that may attach to it |
| --- | --- | --- |
| Ordinary dashboard | Top-level user/root task selection; per-root rollout reduction; attention, lifecycle, continuity display; local deep link | Local task overview, per-item continuity cues, explicit lifecycle controls |
| Optional Wingman analysis/review | Parent-child graph; descendant aggregation; maximum cumulative tree-token proxy; tree-tail evidence; graph/theme summaries; optional consented CLI request | Tree-level descriptive analysis and bounded packet construction, with the remote-path limitations stated separately |

No abstract, figure, table, or discussion sentence may attribute descendant aggregation, tree token proxies, or graph analysis to the ordinary dashboard. Add a pipeline-level test or trace for every data-flow statement retained in the paper.

Suggested replacement for the ordinary-path paragraph:

> The ordinary dashboard uses `CodexActivityReader` to query non-archived top-level user tasks from the local database in read-only mode, reduce each selected root task's rollout, compute per-item attention and continuity signals, and open a user-selected task through a local deep link. The optional Wingman pipeline is separate: its evidence reader resolves parent-child task trees, scans bounded root and descendant rollout tails, and derives tree-level token proxies and descriptive graph signals.

### P0.2 The partial-history and “abstention” wording is technically false

The abstract and related-work text imply that any partial history suppresses ranking globally (`paper/aiwingman_technical_report.md:13` and `:41`). The implementation instead skips an incomplete, non-deferred item and continues scoring complete items (`Sources/ActivityRadarCore/WorkContinuity.swift:174-195`). A complete item may still be recommended (`Sources/ActivityRadarCore/WorkContinuity.swift:203-248`). The result is `incompleteHistory` only if no candidate remains and at least one eligible incomplete item was observed. The frozen specification now states this correctly (`Research/protocol/SPECIFICATION_V1.md:37-42`).

**Required correction.** Replace global wording everywhere with:

> An incomplete, non-deferred item is excluded from scoring. Its presence does not suppress a recommendation supported by another complete item. If no candidate remains and an eligible incomplete item was observed, the policy returns `incompleteHistory` and exposes no ranking.

Use **deterministic ranking suppression** or **no-recommendation policy** as the primary term. If “abstention” is retained for interface consistency, define it as a software policy label with no statistical confidence, calibration, risk-coverage, or selective-prediction meaning. SelectiveNet is at most an analogy and should not carry the scientific argument.

### P0.3 No publication-grade evaluation has been completed

The 52 Swift tests and 16 self-tests are valuable implementation-authored regression evidence, but they are not a publication benchmark. They do not provide an independent oracle, a frozen denominator for the broad artifact, adversarial outcome ledger, cross-process determinism result, privacy disclosure matrix, or performance distribution.

Commit `53aa3e2` improves the situation by freezing a candidate policy specification and a corpus of 155 fixtures: 75 triage and 80 lifecycle cases (`Research/protocol/FREEZE_MANIFEST_V1.json:1-21`). However:

- the freeze status is explicitly pre-execution;
- the scope covers only `WorkContinuityRanker` and `WorkContinuityLifecycle`, not either reader, graph analysis, token proxies, UI, deep links, or remote review (`Research/protocol/SPECIFICATION_V1.md:3-10` and `:154-159`); and
- no benchmark result is present at the reviewed checkpoint.

The Python oracle is separate from the Swift implementation at the language boundary, but **it is not externally independent**. The same project produced the written specification, Python oracle, fixtures, and Swift implementation (`Research/protocol/SPECIFICATION_V1.md:122-139`; `Research/protocol/FREEZE_MANIFEST_V1.json:15`). The paper must call it a **same-project, specification-derived, separately implemented oracle**, not an independent validation.

**Required correction.** Run and archive the finite participant-free gates below, then rewrite the results section from the machine-readable ledger. Until that happens, the paper may describe a frozen protocol but may not report conformance, determinism, robustness, privacy, or performance as results.

### P0.4 The current branch fails its public release gate

At audit checkpoint `53aa3e2`, `git ls-files` listed 89 tracked files while `PUBLIC_SOURCE_MANIFEST.txt` listed 78. The 11 unlisted files were:

- `Research/fixtures/continuity-policy-corpus-v1.json`
- `Research/generate_continuity_corpus.py`
- `Research/protocol/FREEZE_MANIFEST_V1.json`
- `Research/protocol/SPECIFICATION_V1.md`
- `output/docx/aiwingman-technical-report-draft.docx`
- `output/pdf/aiwingman-technical-report-draft.pdf`
- `paper/SUBMISSION_READINESS.md`
- `paper/aiwingman_technical_report.md`
- `paper/build_preprint.py`
- `paper/build_submission_docx.py`
- `paper/preprints_metadata.yaml`

Running `zsh scripts/public-release-check.sh` stopped immediately with:

```text
==> Checking tracked public files against the explicit manifest
ERROR: Git tracked files and PUBLIC_SOURCE_MANIFEST.txt do not match exactly
```

This is the intended behavior of the exact-manifest check (`scripts/public-release-check.sh:34-44`). The clean archive of release commit `5e212181...` passed its historical gate; that does not make the later paper/protocol branch pass.

**Required correction.** Decide which manuscript, generated-document, and research files are public release artifacts; conduct a privacy/rights review of each; make the allowlist and branch topology consistent without weakening the fail-closed check; and rerun the complete release gate at the exact commit cited by the revised paper. Preserve generated outputs if they remain part of the package; do not silently delete evidence merely to obtain a green manifest comparison.

### P0.5 The broad novelty position is not sustainable

The current eight-reference bibliography (`paper/aiwingman_technical_report.md:226-242`) omits direct work on programmer task context, resumption cues, awareness dashboards, issue triage, and human oversight of multi-agent systems. It also does not compare against current agent-session products.

Current official GitHub documentation describes an agents panel with session monitoring, logs, token usage, session length, archive/share/resume flows, natural-language queries over past sessions, `/chronicle` summaries and cost tips, a rubber-duck critique agent, and app deep links. These features do not make AiWingman identical, but they eliminate any defensible “first agent task dashboard,” “first session recall,” “first token guidance,” or “first critique companion” claim:

- [Managing agent sessions](https://docs.github.com/en/copilot/how-tos/copilot-on-github/use-copilot-agents/manage-and-track-agents)
- [About GitHub Copilot CLI session data](https://docs.github.com/en/copilot/concepts/agents/copilot-cli/chronicle)
- [Working with agent sessions in the GitHub Copilot app](https://docs.github.com/en/copilot/how-tos/github-copilot-app/agent-sessions)

The closest research comparators also include Mylar/Mylyn task context, interruption-resumption studies, awareness dashboards, AutoGen Studio, a CHI 2026 workshop dashboard for human oversight of coordinating agents, and agent observability work. The related-work revision must include at least the sources listed later in this report.

**Required correction.** Make no first-of-kind or superiority claim. Frame novelty as the particular integration of: (i) a Codex-specific local retrospective adapter; (ii) an offline-default ordinary path; (iii) separation of observations from explicit and reversible lifecycle decisions; and (iv) deterministic, explainable ranking suppression. Each element has prior art; the proposed contribution is the integration and its auditable implementation.

### P0.6 Security and privacy prose exceeds the demonstrated boundary

The manuscript appropriately disclaims sole-context isolation (`paper/aiwingman_technical_report.md:115`), but several preceding sentences are still too absolute (`:111-113`). At the audited baseline:

1. **“Credentials are excluded” is too broad.** The packet builder always includes task titles after best-effort sanitization (`Sources/ActivityRadarCore/WingmanCodexContract.swift:92-104`). Sanitization removes a finite set of known path, e-mail, UUID, key, and token patterns (`Sources/ActivityRadarCore/CodexWingmanEvidenceReader.swift:698-743`), but it cannot guarantee removal of arbitrary secrets embedded in titles or allowed prompt text. Raw authentication-file contents are not intentionally added to the packet; that narrower statement is supportable.
2. **Temporary-auth cleanup is best effort, not guaranteed.** The auth copy is written into the temporary home (`Sources/ActivityRadar/WingmanFeature.swift:848-883`), while cleanup uses non-throwing `try?` removal and a retry without a final error or verified absence (`Sources/ActivityRadar/WingmanFeature.swift:1186-1202`). “Removed after the attempt” must be weakened unless cleanup is made verifiable and cleanup failure is surfaced.
3. **Unexpected/tool-event rejection is not preventive isolation.** The JSONL parser rejects an unexpected item or event and discards the result (`Sources/ActivityRadarCore/WingmanCodexContract.swift:375-416`). This proves output invalidation, not that the child performed no earlier filesystem read, network exchange, or tool attempt.
4. **The ordinary reader trusted database-provided rollout paths.** At the audited baseline it read the `rollout_path` value from SQLite and opened that path directly (`Sources/ActivityRadarCore/CodexActivityReader.swift:237-245` and `:550-617`) without an explicit containment, symlink, owner, or regular-file boundary. A corrupted or hostile local state database could therefore redirect reads.
5. **The session index was loaded as one unbounded `Data` object.** `session_index.jsonl` was read wholesale (`Sources/ActivityRadarCore/CodexActivityReader.swift:517-547`). This is a denial-of-service and memory-boundary gap, even though the file is local.
6. **The app is not OS-sandboxed.** `Packaging/ActivityRadar.entitlements` contains an empty dictionary (`:1-5`). The child CLI's `--sandbox read-only` option must not be described as an application sandbox.
7. **The no-network gate is source-level, not runtime proof.** The release script rejects selected network API strings in `Sources` (`scripts/public-release-check.sh:827-831`). That is useful static evidence; it is not runtime non-interference, and the optional CLI path intentionally reaches an external service after consent.

**Required correction.** Replace absolute claims with property-specific statements, harden path and size boundaries, make sensitive temporary cleanup observable, and add sentinel/adversarial tests. Suggested wording:

> The packet builder intentionally omits raw task identifiers, raw paths, configuration files, tool outputs, and authentication-file contents. It always includes sanitized task titles and may include sanitized prompt excerpts after explicit opt-in. Sanitization is best-effort and cannot prove removal of every secret. Unexpected CLI JSONL events invalidate the returned review; this does not prove that the child process had no other readable context or prior I/O.

### P0.7 The draft used another person's ORCID

The submission metadata at audit checkpoint `53aa3e2` paired Mehmet Solak's Siirt University Biosystems Engineering affiliation with ORCID `0000-0003-2528-7960` (`paper/preprints_metadata.yaml:39-47` at that commit). The official ORCID public record for [0000-0003-2528-7960](https://orcid.org/0000-0003-2528-7960) resolves to **Mehmet Şahin Solak** and a current Kahramanmaraş İstiklal University Faculty of Communication affiliation. It must not be used for this manuscript.

The official public record for [0000-0002-0800-0334](https://orcid.org/0000-0002-0800-0334) resolves to **MEHMET SOLAK** with Siirt University, Biosystems Engineering employment and is the matching candidate. The working metadata and `CITATION.cff` were corrected to `0000-0002-0800-0334` after discovery, but an API match is not author attestation.

**Required correction.** Retain the corrected identifier consistently across manuscript, metadata, CFF, portal, and document properties; have the named author personally confirm the public name form, ORCID ownership, affiliation, and corresponding address before deposit; and perform an exact cross-file identity check in the final package. This is a critical reputational and attribution gate.

## P1 findings — major revisions required

### P1.1 Related work must be rebuilt around the actual problem

The paper should distinguish four literatures instead of relying mainly on general coding-agent benchmarks:

- **Programmer task context and resumption:** Kersten and Murphy, “Using Task Context to Improve Programmer Productivity,” FSE 2006, [doi:10.1145/1181775.1181777](https://doi.org/10.1145/1181775.1181777); Parnin and DeLine, “Evaluating Cues for Resuming Interrupted Programming Tasks,” CHI 2010, [doi:10.1145/1753326.1753342](https://doi.org/10.1145/1753326.1753342); Parnin and Rugaber, “Resumption Strategies for Interrupted Programming Tasks,” *Software Quality Journal* 2011, [doi:10.1007/s11219-010-9104-9](https://doi.org/10.1007/s11219-010-9104-9).
- **Awareness, refinding, and dashboard triage:** Storey et al., “How Software Developers Use Tagging to Support Reminding and Refinding,” *IEEE TSE* 2009, [doi:10.1109/TSE.2009.15](https://doi.org/10.1109/TSE.2009.15); Treude and Storey, “Awareness 2.0,” ICSE 2010, [doi:10.1145/1806799.1806854](https://doi.org/10.1145/1806799.1806854); Baysal et al., “No Issue Left Behind,” FSE 2014, [doi:10.1145/2635868.2635887](https://doi.org/10.1145/2635868.2635887).
- **Human oversight and multi-agent interfaces:** Dibia et al., “AutoGen Studio,” EMNLP 2024 Demo, [doi:10.18653/v1/2024.emnlp-demo.8](https://doi.org/10.18653/v1/2024.emnlp-demo.8); Kitano et al., “Managing Multi-Agent Research Systems: A Dashboard for Human Oversight of Coordinating AI Agents,” HEAL@CHI 2026 [workshop PDF](https://heal-workshop.github.io/chi2026_papers/Managing%20Multi-Agent%20Research%20Systems%20A%20Dashboard%20for%20Human%20Oversight%20of%20Coordin.pdf). The workshop PDF contains a placeholder DOI and that placeholder must not be cited as a real DOI.
- **Agent observability and developer oversight:** “AgentTrace: A Structured Logging Framework for Agent System Observability,” [arXiv:2602.10133](https://arxiv.org/abs/2602.10133); Dhanorkar et al., “Human Oversight of Agentic Systems in Practice,” [arXiv:2606.05391](https://arxiv.org/abs/2606.05391).

Chen et al. (2021) is historical context for code models, not evidence about the current Codex desktop app or its local storage contract. SWE-bench and SWE-agent are useful general agent background but are not direct comparators for task continuity. Do not use any of these sources to imply an official, stable Codex local API.

### P1.2 The evaluated revision and result revision are drifting apart

The manuscript identifies `v1.2.0-beta.2`/`5e212181...` as the artifact (`paper/aiwingman_technical_report.md:23` and `:202-208`), while the frozen protocol was added at `53aa3e2` and any runner/results will necessarily be later. A revised paper must provide a table mapping every result to the exact commit, toolchain, operating system, architecture, and immutable artifact hash. If code changes after the freeze, regenerate a versioned protocol/corpus or document why the hash-preserving evaluation remains applicable.

### P1.3 Test discovery must be reported with an actual denominator

On the audit machine, a plain `swift test` command returned without discovering the expected tests. The canonical gate anticipates this condition by checking for a known test before accepting standard discovery and by using a Command Line Tools fallback (`scripts/public-release-check.sh:675-738`). CI evidence at the release commit shows 52 tests, but a local zero-test exit must never be reported as a pass. Reproducibility instructions must record test listing, discovered count, executed count, failures, and the fallback path used. Run the publication benchmark through a standalone executable so its denominator does not depend on XCTest/Swift Testing discovery.

### P1.4 Artifact provenance is adequate for a draft but weak for archival claims

`git tag -v v1.2.0-beta.2` reports “no signature found.” An unsigned tag is not proof of a compromised artifact, but the paper must not imply cryptographic tag provenance. For the evaluated publication revision, publish SHA-256 hashes for source archive, benchmark corpus, result ledger, PDF, and DOCX; use a signed tag or signed release attestation if feasible; and state exactly which mechanism was used.

### P1.5 Accessibility and document QA are unfinished

`pdfinfo` reports `Tagged: no` for `output/pdf/aiwingman-technical-report-draft.pdf`. The current PDF therefore lacks a tagged reading structure. Before deposit, provide a tagged accessible PDF where the target repository supports it, verify reading order and alternative text, inspect every rendered page, confirm copy/paste text order, and run reference/link validation. Visual cleanliness alone is not accessibility evidence.

### P1.6 Declarations and metadata still require the named author's decisions

Funding, competing interests, contribution wording, AI-assistance disclosure, the corrected ORCID `0000-0002-0800-0334`, public author-name form, and the right to grant CC BY 4.0 must be explicitly confirmed; placeholders remain in the manuscript (`paper/aiwingman_technical_report.md:212-224`). No portal upload should precede that confirmation. Submission is not acceptance, and a preprint identifier is not peer-reviewed publication evidence.

## P2 findings — clarity and maintainability

1. Use “AiWingman” consistently for the product while explaining once that `ActivityRadar` identifiers remain for state compatibility. Avoid switching names in scientific claims.
2. Shorten the abstract and separate implementation evidence from future work. A protocol without results should not dominate the abstract's contribution claim.
3. Label all token quantities as cumulative comparison proxies at first mention, in every table, and in figure captions; never abbreviate them to “usage,” “cost,” or “waste.”
4. Move exploratory PageRank, similarity, connected-component, and prompt-critique features out of the core contribution unless they receive their own frozen specification and evaluation.
5. Define “read-only” separately for SQLite opening, source-file access, AiWingman-owned continuity storage, and the child CLI. The whole application is not write-free.
6. State the observed Codex schema/event/deep-link versions and fail-neutral behavior. The integration is based on observed local behavior, not an official stable API.
7. Add a limitations row for title leakage through best-effort sanitization and another for user inspection of the consent preview.
8. Keep the remote model output out of local determinism and conformance totals.
9. Use a single reference style; validate every DOI; archive access dates for mutable product documentation.
10. Report automated, manual, screen-observed, and still-open checks separately. Do not collapse them into one “verified” label.

## Claim and novelty matrix

| Candidate claim | Closest evidence/comparator | Audit verdict | Permitted wording after revision |
| --- | --- | --- | --- |
| First dashboard for parallel coding-agent tasks | GitHub Agents panel; Kitano et al. dashboard; AutoGen Studio | **Reject** | No first-of-kind claim |
| First way to query/summarize prior agent sessions | GitHub session queries and `/chronicle` | **Reject** | Compare scope, storage, and consent differences only |
| First agent critique/“wingman” feature | GitHub rubber-duck agent and general review agents | **Reject** | Describe the optional flow as an AiWingman feature, not a novel class |
| Codex-specific retrospective local overlay | Current comparators are mostly GitHub-synced or agent-runtime-specific | **Potentially defensible integration** | “A Codex-specific local retrospective overlay,” with unofficial-contract caveat |
| Offline-default ordinary dashboard | Source architecture and static network-string gate | **Supported only as a bounded source-level property** | “The ordinary dashboard contains no intended network path in the evaluated source”; do not claim runtime proof |
| Read-only Codex integration | SQLite read-only adapter plus file reads; app writes its own state | **Partially supported** | “Reads Codex state through read-only adapters and writes only AiWingman-owned state,” after path hardening |
| User-owned obsolete/abandoned decisions | Explicit, reversible lifecycle code and tests | **Defensible design property** | “Does not infer confirmed obsolete/abandoned state from silence or age” |
| Deterministic ranking suppression | Pure policy code and frozen same-project corpus | **Implemented; publication result pending** | Report exact frozen-corpus results only after execution |
| Statistically calibrated abstention | No learned uncertainty, confidence, or risk-coverage analysis | **Reject** | Use deterministic ranking suppression/no-recommendation terminology |
| Tree-level token analysis in the ordinary dashboard | Tree aggregation exists only in the optional Wingman reader | **Reject as currently phrased** | Attribute the maximum cumulative proxy only to the Wingman pipeline |
| Exact token waste/cost detection | No validated billing or value model | **Reject** | “Cumulative comparison proxy; not billed, period-specific, useful, or wasted tokens” |
| Improved recall, resumption time, workload, or productivity | No participant or outcome study | **Untested** | State as a future research question only |
| Security isolation or sole-context execution | Unsandboxed app; read-only child; best-effort redaction; external service | **Reject** | Enumerate narrow controls and residual access explicitly |
| Cross-architecture regression evidence | CI run `32648392604` at `5e212181...` | **Supported for the enumerated tests at that commit** | Preserve exact run, count, platform, and non-generalization boundary |

## Minimum participant-free evaluation gates

These gates are the minimum for the current technical-report scope. They do not establish usability or human benefit. All inputs, scripts, outputs, failures, and environment metadata must be archived. Any kill condition leaves the decision at **DO NOT SUBMIT**.

| Gate | Required execution and evidence | Pass condition | Kill condition |
| --- | --- | --- | --- |
| G0 — freeze integrity | Recompute SHA-256 for specification, generator, and corpus before build and before result packaging | Every hash matches `FREEZE_MANIFEST_V1.json`; working tree and result commit recorded | Any mismatch or post-hoc expected-output edit |
| G1 — exact policy conformance | Run the standalone Swift benchmark against all 155 frozen fixtures and emit per-fixture actual/expected records | 155/155 exact matches; zero skipped; denominator and failures retained | Any mismatch, skip, crash, or timeout |
| G2 — local within-process repeatability | Evaluate each fixture 100 times in one benchmark process; use evaluation 1 as the baseline and compare evaluations 2-100 | One canonical output per fixture across 15,500 evaluations and 15,345 nontrivial comparisons, with environment fixed and recorded | Any unexplained divergence |
| G3 — five-sentinel non-propagation | Seed the five frozen private sentinels and inspect the specified serialized policy-output surface | Zero exact sentinel occurrences in that bounded surface | Any exact sentinel occurrence |
| G4 — metamorphic policy checks | Freeze and run input-permutation, stable tie-break, irrelevant-text substitution, and bounded-limit relations | Every predeclared relation holds on every applicable seed | Any post-hoc relation deletion or violation |
| G5 — reader and compatibility robustness | Use isolated synthetic SQLite/JSONL roots for both readers; include malformed/truncated data, incompatible schema, partial tails, duplicate/cyclic edges, extreme sizes, missing files, symlinks, and path escapes | Complete ledger; no mutation, crash, hang, unsafe path read, or silent schema acceptance | Any unsafe read, mutation, crash, unbounded resource use, or unreported exclusion |
| G6 — privacy and remote-boundary tests | Seed sentinels in identifiers, titles, paths, prompts, checkpoints, tool events, configuration, and auth fixtures; inspect preview, diagnostics, logs, child home, and cleanup outcome | Only explicitly allowed, previewed fields appear; unexpected events invalidate output; cleanup absence is verified or failure is surfaced | Forbidden sentinel, unpreviewed field, silent cleanup failure, or accepted forbidden event |
| G7 — descriptive performance | After five warm-ups, run 30 measurements at 10, 50, 200, and 1,000 policy inputs; report median, p95, IQR, maximum, and peak memory on the named machine | Complete distributions and raw measurements; no human-time interpretation | Missing denominator/environment, selective reporting, or unsupported extrapolation |
| G8 — platform and release reproducibility | Run policy benchmark, 52-test suite with enforced discovery, 16 self-tests, and full public release gate on arm64 and native x86_64 at the exact result commit | All required jobs pass; manifest matches; artifact/result hashes published | Zero-test “pass,” manifest mismatch, architecture omission, or result/commit mismatch |

If G5 or G6 cannot be completed within the finite revision, narrow the paper to the pure policy layer and clearly label both readers and the remote path as unevaluated implementation context. Even under that narrower route, the incorrect architecture and security wording must still be fixed.

## Finite resubmission checklist

The package is eligible for one second review only when every item below has objective evidence. The checklist has 16 items and should not expand during this revision; new desirable work goes to a post-preprint backlog.

- [ ] 1. Rewrite the abstract, architecture, figures, token section, and limitations to separate the ordinary dashboard and optional Wingman pipelines.
- [ ] 2. Correct partial-history behavior in every occurrence and replace statistical “abstention” framing with deterministic ranking-suppression terminology.
- [ ] 3. Replace absolute credential, cleanup, tool-event, sandbox, and no-network claims with the property-specific security wording in this report.
- [ ] 4. Harden and regression-test rollout-path containment, symlink/regular-file checks, and bounded streaming of `session_index.jsonl`, or explicitly remove the affected security claim.
- [ ] 5. Add the direct related work and current product baselines; delete all first/superiority language; do not cite the Kitano placeholder DOI.
- [ ] 6. Freeze any additional metamorphic/robustness fixtures before executing them; record all hashes and stop rules.
- [ ] 7. Complete gates G0-G8 with machine-readable ledgers, raw denominators, environment metadata, and no hidden exclusions.
- [ ] 8. Describe the Python oracle as same-project and separately implemented, never externally independent.
- [ ] 9. Rebuild the results and claim-ledger sections from the archived outputs; leave human benefit, exact waste, and comparative superiority explicitly untested.
- [ ] 10. Cite one exact immutable result commit/release and map each table to its producing command and artifact hash.
- [ ] 11. Resolve the 89-versus-78 manifest failure at the audited checkpoint, privacy-scan every newly public artifact, and rerun the complete release gate without weakening it.
- [ ] 12. Record standard-test discovery and executed counts; do not accept a zero-test successful exit.
- [ ] 13. Validate every DOI/URL and archive mutable web-source access dates; use no placeholder DOI.
- [ ] 14. Obtain explicit author confirmation for public name/ORCID, affiliation, funding, competing interests, contribution, AI assistance, and CC BY 4.0 authority.
- [ ] 15. Rebuild DOCX and PDF; inspect every rendered page; verify links, text extraction, tables/figures, metadata, accessibility tags/reading order, and absence of private paths or task data.
- [ ] 16. Conduct a second internal claim-and-artifact audit against this report. The terminal decision is **SUBMISSION-READY** only if no P0 remains, every retained claim has a cited evidence row, and all applicable gates pass.

## Recommended second-round decision rule

The second reviewer should answer only three questions:

1. Does every architectural statement identify the correct pipeline?
2. Does every empirical claim point to a frozen input, complete result ledger, exact commit, and stated validity boundary?
3. Could a reasonable reader still infer first-of-kind status, human benefit, exact waste, guaranteed secret removal, or security isolation?

Any “no” to questions 1 or 2, or “yes” to question 3, preserves **MAJOR REVISION / DO NOT SUBMIT**. Portal upload should occur only after the named author separately approves the final files and declarations.
