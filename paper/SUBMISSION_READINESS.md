# AiWingman preprint submission readiness

Status: `FINAL_ARTIFACTS_VERIFIED_PUBLIC_COMMIT_PENDING`, not submitted.

The named author confirmed all 12 declarations on 24 August 2026. The canonical
Markdown and declaration-complete DOCX, direct PDF, and research supplement are
now submission version 1.0 and have passed their final local artifact gates.
Exact-commit source CI has passed for hardened software checkpoint `99faac3...`,
but it does not attest this declaration-complete manuscript package. A clean
exact public-package checkpoint and hosted CI must still pass before portal
staging.

## Selected route

Candidate platform after the hold is cleared:
[Preprints.org](https://www.preprints.org/)

Planned record type: `Technical Note`

Primary subject: `Computer Science and Mathematics`

Secondary subject: `Software`

Platform rationale only: the platform accepts English Word or LaTeX manuscripts, is free,
assigns a Crossref DOI to each posted version, requires CC BY 4.0, and reports
that its content is discoverable through Google Scholar. Screening normally
targets about one working day, but neither public posting nor Scholar indexing
is guaranteed on a particular date.

## Declaration-complete finalization targets

- Editable main manuscript: `output/docx/aiwingman-technical-note-v1.docx`
- Author-rendered reference PDF: `output/pdf/aiwingman-technical-note-v1.pdf`
- Research supplement: `output/supplement/aiwingman-research-supplement-v1.zip`
- Canonical text: `paper/aiwingman_technical_report.md`
- Portal metadata: `paper/preprints_metadata.yaml`

The final targets must contain all 32 references, the V1 errata, declaration
statements, corrected reproduction commands, and the final claim ledger. Only
the final DOCX is planned as the portal's main manuscript. The direct PDF is an
author-rendered QA/reference artifact; the supplement contains only the
CC-BY-4.0-scoped non-executable research package.

The corrected builders produced the declaration-complete submission artifacts.
All 30 DOCX-rendered pages and all 17 direct-PDF pages were inspected after the
final pagination and declaration edits. The DOCX structural and accessibility
checks, direct-PDF text/metadata checks, compressed-artifact privacy scan, and
deterministic supplement audit passed. The exact SHA-256 values are
`49800b75b2d33ab85507defec85c814c9844b8c2a53496f2f0c4515852829dfb`
for the DOCX,
`575aef866b6dda6a5165218bec79479424ab192a90291ec9c690729d2778481c`
for the direct PDF, and
`142dca3e1924ff91997126ba6c9ce2b02e323e93d2fc02d5c8b588510fe987d0`
for the research supplement. The full bounded evidence and remaining provenance
gates are recorded in `paper/PUBLICATION_ARTIFACT_MANIFEST.md`.

## Evidence boundary

The paper reports current automated engineering checks as regression and
contract evidence. It does not claim independent conformance, human efficacy,
scientific superiority, exact token waste, a complete privacy proof, a signed
public binary, or verified macOS 13 runtime behavior.

No private Codex state, task text, prompt excerpt, local path, real-work
screenshot, credential, or participant record is included.

## Major-revision gates

All gates are fail-closed.

- [x] Internal Codex-assisted methods, novelty, and artifact/security review
  passes produced written findings; these were not human or external peer review.
- [x] A separate specification and 155-fixture Python-oracle corpus were
  committed at `53aa3e2` before the archived benchmark execution. The policy
  implementation predated that freeze; the manuscript states that this was not
  a preregistration and that repository chronology does not exclude earlier
  exploratory or unarchived runs.
- [x] The Swift implementation matches all 155 frozen expected outputs on the
  recorded arm64 environment.
- [x] Every fixture was evaluated 100 times; evaluations 2-100 matched
  evaluation 1 for every fixture (15,500 total evaluations and 15,345
  nontrivial equality comparisons). A separately labeled post-freeze supplementary
  check had 100/100 fresh processes return the same corpus digest on that arm64
  machine; the V1 counter and chronology terminology is corrected by an erratum.
- [x] The historical `contentNeutrality` label is corrected to a five-sentinel
  non-propagation check and is not presented as anonymity, noninterference,
  privacy, identifier removal, or semantic content independence.
- [x] The V1 result is identified as a summary report rather than a complete
  per-fixture actual-output ledger; the missing passing rows are not implied.
- [x] Baselines and policy perturbations are reported without human-benefit
  interpretation.
- [x] Confirmed dashboard-reader path, bounded-read, malformed-tail, graph, and
  temporary-auth lifecycle weaknesses are corrected and locally regression-
  tested; the enforced fallback suite currently discovers 100 tests, and 16/16
  deterministic self-tests pass. This is not macOS 13 runtime evidence.
- [x] The manuscript separates the ordinary dashboard and optional Wingman
  evidence pipelines.
- [x] The manuscript replaces broad novelty and statistical-abstention wording
  with the narrower design-integration and ranking-suppression claims.
- [x] The nearest programming-resumption, dashboard, trajectory-debugging,
  agent-observability, current GitHub Copilot, and OpenAI ChatGPT/Codex
  product-family precedents found
  in the bounded audit are included. This is not an exhaustive novelty review.
- [x] Credentials, temporary-auth cleanup, subprocess, network, sandbox,
  SQLite WAL `-shm`, and undocumented Codex integration claims are narrowed to
  the tested boundary.
- [x] Evaluated source checkpoint
  `99faac3ef52d0da72d082706f64903a6aacd2c6d` passed exact-commit GitHub Actions
  run `32659669054`: 82 Swift tests and 16 self-tests on both hosted arm64 and
  native x86_64 jobs, 155/155 policy conformance and the same canonical digest
  on both architectures, the native Intel application build, and the arm64
  public-source preparation check. This is not external reproduction or a real
  macOS 13 runtime result.
- [x] The live `v1.2.0-beta.2` release page is marked superseded and no longer
  recommends building that historical tag; its three documentation
  overstatements and later security-relevant hardening boundary are disclosed.
- [x] A standard-library compressed-artifact privacy scanner and adversarial
  DOCX/PDF fixtures are implemented and pass locally. Final output bytes must
  still pass it after the last rebuild.
- [x] The preprint does not depend on creating a new product-release tag. It
  cites the exact evaluated hardened checkpoint `99faac3...` and labels beta2
  historical and superseded. A beta3 tag remains a separate product-release
  follow-up with its own irreversible confirmation boundary.
- [x] The second Codex-assisted internal submission audit found no P0 issue,
  corrected the first-page front matter, split claim-ledger rows, flattened
  numbered lists, non-linked DOCX URLs, and the orphaned final PDF reference,
  and recorded the remaining licensing and author gates in
  `paper/SECOND_REVIEW_REPORT.md`. This was not human or external peer review.
- [x] A third Codex-assisted source/claim/security audit found no P0 issue and
  exposed two P1 mismatches: unbounded goal-linked dashboard inclusions and an
  authenticated CLI probe on Wingman appearance. It also found seven P2 issues
  covering preview wording, deep links, blank graph edges, empty-test success,
  initial file permissions, stale branch wording, and inclusion-truncation
  signaling. The current revision
  implements and regression-tests the corrections recorded in
  `paper/THIRD_REVIEW_REPORT.md`. This remains internal AI-assisted review.
- [ ] `PUBLIC_SOURCE_MANIFEST.txt` includes the final review artifacts and the
  release check passes again from a final clean detached worktree with exact
  manifest/tree equality. A final 117-file manifest-only export of the current
  uncommitted revision passed the complete public-source preparation gate,
  including 100 tests and local arm64/x86_64 cross-builds; this does not close
  the clean-commit provenance gate or constitute x86_64 execution.
- [x] Declaration-complete rebuilt DOCX and PDF passed all-page visual
  inspection, structural checks, privacy scan, and metadata review at 30
  DOCX-rendered pages and 17 direct-PDF pages. The deterministic research
  supplement also passed content, byte-equality, path, permission, CRC, and
  privacy review.
- [x] Second and third reviewer rounds return no P0 issue.
- [x] A fourth Codex-assisted methods and artifact-reproducibility round found no
  P0 issue. It exposed two hidden P1 boundaries: post-freeze baseline analyses
  were not labeled exploratory, and the non-code research package had no
  explicit reuse-license map. The baseline chronology was corrected in Draft 0.5,
  and the named author's 24 August 2026 confirmation activated the file-level
  MIT/CC BY 4.0 map. Findings and dispositions are recorded in
  `paper/FOURTH_REVIEW_REPORT.md`.
- [x] A fifth Codex-assisted scientific, source, reference, and layout round
  found no P0 issue. It exposed one new P1 methods boundary: the frozen corpus
  did not make every written reason/weight rule observable. Draft 0.5 now
  narrows the historical V1 claim and records a separately labeled post-freeze
  supplement whose six focused tests passed and whose six enumerated mutations
  were killed. All 32 references were also audited, and the provisional DOCX
  and direct PDF passed complete visual review. Findings and dispositions are
  recorded in `paper/FIFTH_REVIEW_REPORT.md`. This remains internal AI-assisted
  review, not external peer review or independent reproduction.
- [x] The final publication artifact manifest records the declaration-complete
  DOCX and PDF SHA-256 values, build environment, and visual/privacy/structure
  gate results.
- [x] The author identity, declarations, rights, policy compatibility, and
  permanence attestations below were confirmed by the named author on 24 August
  2026 using the exact recorded confirmation phrase.

## Recorded author confirmation

On 24 August 2026, the named author supplied the exact phrase
`YAZAR BEYANLARINI ONAYLIYORUM`, confirming all of the following as true:

1. The public author name is `Mehmet Solak` and the corresponding ORCID is
   `0000-0002-0800-0334`. This identifier currently resolves through the
   public ORCID API to `MEHMET SOLAK`, Siirt University, Biosystems
   Engineering; the named author confirmed ownership before deposit.
2. The affiliation and corresponding email printed on the manuscript are
   correct.
3. The funding statement to publish.
4. The competing-interests statement to publish.
5. The author-contribution statement accurately describes authorship.
6. The AI-assistance disclosure is complete, and the author has reviewed every
   claim and reference and accepts full responsibility.
7. The manuscript, generated scholarly outputs, written research protocol,
   synthetic fixture corpus, result data, and erratum may be distributed under
   CC BY 4.0, while executable software source, tests, and scripts remain MIT
   licensed; the author has the right to grant both license scopes.
8. Preprints.org may receive a permanent, non-exclusive distribution license;
   the author has the right to grant it; and the public record may remain visible
   or mirrored even after withdrawal.
9. The work has not already been formally published or accepted, and no
   conflicting duplicate preprint exists.
10. The author has the right to share every figure, table, text, code, and
    supplementary artifact under the stated licenses; no private task history,
    personal data, credential, or restricted material is included.
11. Institutional, funder, intended-journal, and patent policies permit preprint
    posting; no planned patent filing is prejudiced by immediate disclosure.
12. As corresponding author, the named author accepts responsibility for
    answering questions or comments about the preprint and for providing the
    reported data or materials when reasonably requested and legally permitted.

This confirmation authorizes removal of the draft warnings, activation of the
recorded license map, and local/hosted finalization. It does not authorize the
portal's final **Submit** action. That irreversible action remains separately
gated after the exact files and completed portal record are shown to the author.

## Post-publication verification

After screening and public posting:

1. Record the public URL, DOI, date, and version.
2. Add the DOI to `CITATION.cff` and the repository documentation in a new
   commit; do not rewrite the evaluated release tag.
3. Verify that the public page and PDF are accessible without authentication.
4. Search Google Scholar by the exact quoted title periodically. A same-day
   result is not expected or guaranteed.
