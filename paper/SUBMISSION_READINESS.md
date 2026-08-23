# AiWingman preprint submission readiness

Status: `HOLD_MAJOR_REVISION_DO_NOT_SUBMIT`, not submitted.

The generated PDF and DOCX still represent the superseded Draft 0.1 package and
must not be uploaded. The canonical Markdown is now Draft 0.3, but author
attestation is necessary and not sufficient: the current source checkpoint,
dual-architecture CI, rebuilt documents, artifact gate, and second review below
must all pass first.

## Selected route

Candidate platform after the hold is cleared:
[Preprints.org](https://www.preprints.org/)

Planned record type: `Technical Note`

Primary subject: `Computer Science and Mathematics`

Secondary subject: `Artificial Intelligence and Machine Learning`

Platform rationale only: the platform accepts English Word or LaTeX manuscripts, is free,
assigns a Crossref DOI to each posted version, requires CC BY 4.0, and reports
that its content is discoverable through Google Scholar. Screening normally
targets about one working day, but neither public posting nor Scholar indexing
is guaranteed on a particular date.

## Superseded draft files — do not upload

- Editable main manuscript: `output/docx/aiwingman-technical-report-draft.docx`
- Searchable review PDF: `output/pdf/aiwingman-technical-report-draft.pdf`
- Canonical text: `paper/aiwingman_technical_report.md`
- Portal metadata: `paper/preprints_metadata.yaml`

These files are preserved for review provenance. They are not submission-ready.
The generated files identify the historical source release
`v1.2.0-beta.2`, commit `5e212181ae177cd555ab6bb92f5f71ac8be9173a`,
and GitHub Actions run `32648392604`, but they do not contain the Draft 0.3
methods, 21-reference related-work section, result erratum, or corrected claim
ledger.

## Evidence boundary

The paper reports current automated engineering checks as regression and
contract evidence. It does not claim independent conformance, human efficacy,
scientific superiority, exact token waste, a complete privacy proof, a signed
public binary, or verified macOS 13 runtime behavior.

No private Codex state, task text, prompt excerpt, local path, real-work
screenshot, credential, or participant record is included.

## Major-revision gates

All gates are fail-closed.

- [x] Methods, novelty, and artifact/security reviewers issued written findings.
- [x] A separate specification and 155-fixture Python-oracle corpus were frozen
  at commit `53aa3e2` before the Swift benchmark was executed.
- [x] The Swift implementation matches all 155 frozen expected outputs on the
  recorded arm64 environment.
- [x] Every fixture was stable across 100 within-process evaluations, and all
  100 fresh processes returned the same canonical corpus digest on that arm64
  machine; the V1 fresh-process counter terminology is corrected by an erratum.
- [x] Five seeded content sentinels did not appear in serialized policy outputs.
- [x] Baselines and policy perturbations are reported without human-benefit
  interpretation.
- [x] Confirmed dashboard-reader path, bounded-read, malformed-tail, graph, and
  temporary-auth lifecycle weaknesses are corrected and locally regression-
  tested; the enforced fallback suite currently discovers 82 tests, and 16/16
  deterministic self-tests pass. This is not macOS 13 runtime evidence.
- [x] The manuscript separates the ordinary dashboard and optional Wingman
  evidence pipelines.
- [x] The manuscript replaces broad novelty and statistical-abstention wording
  with the narrower design-integration and ranking-suppression claims.
- [x] The nearest programming-resumption, dashboard, agent-observability, and
  current GitHub Copilot precedents are included.
- [x] Credentials, temporary-auth cleanup, subprocess, network, sandbox,
  SQLite WAL `-shm`, and undocumented Codex integration claims are narrowed to
  the tested boundary.
- [ ] `PUBLIC_SOURCE_MANIFEST.txt` matches all tracked publication artifacts and
  the full public release gate passes from a clean archive.
- [ ] Rebuilt DOCX and PDF pass all-page visual inspection, structural checks,
  privacy scan, and metadata review.
- [ ] A second reviewer round returns no P0 issue.
- [ ] The author identity, declarations, and permanence attestations below are
  confirmed.

## Author confirmation gate

Before removing the draft notice or sending the submission, the author must
confirm all of the following as true:

1. The public author name is `Mehmet Solak` and the corresponding ORCID is
   `0000-0002-0800-0334`. This identifier currently resolves through the
   public ORCID API to `MEHMET SOLAK`, Siirt University, Biosystems
   Engineering; the author must still confirm it before deposit.
2. The affiliation and corresponding email printed on the manuscript are
   correct.
3. The funding statement to publish.
4. The competing-interests statement to publish.
5. The author-contribution statement accurately describes authorship.
6. The AI-assistance disclosure is complete, and the author has reviewed every
   claim and reference and accepts full responsibility.
7. The manuscript may be distributed under CC BY 4.0 while the software remains
   MIT licensed.
8. Preprints.org may receive a permanent, non-exclusive distribution license;
   the author has the right to grant it; and the public record may remain visible
   or mirrored even after withdrawal.

Only after both the major-revision gates and these author statements are
confirmed should the draft notice and `AUTHOR_CONFIRMATION_REQUIRED` values be
replaced and the portal's final submit action used.

## Post-publication verification

After screening and public posting:

1. Record the public URL, DOI, date, and version.
2. Add the DOI to `CITATION.cff` and the repository documentation in a new
   commit; do not rewrite the evaluated release tag.
3. Verify that the public page and PDF are accessible without authentication.
4. Search Google Scholar by the exact quoted title periodically. A same-day
   result is not expected or guaranteed.
