# AiWingman preprint submission readiness

Status: `READY_FOR_AUTHOR_ATTESTATION`, not submitted.

## Selected route

Primary platform: [Preprints.org](https://www.preprints.org/)

Planned record type: `Technical Note`

Primary subject: `Computer Science and Mathematics`

Secondary subject: `Artificial Intelligence and Machine Learning`

Rationale: the platform accepts English Word or LaTeX manuscripts, is free,
assigns a Crossref DOI to each posted version, requires CC BY 4.0, and reports
that its content is discoverable through Google Scholar. Screening normally
targets about one working day, but neither public posting nor Scholar indexing
is guaranteed on a particular date.

## Prepared files

- Editable main manuscript: `output/docx/aiwingman-technical-report-draft.docx`
- Searchable review PDF: `output/pdf/aiwingman-technical-report-draft.pdf`
- Canonical text: `paper/aiwingman_technical_report.md`
- Portal metadata: `paper/preprints_metadata.yaml`

The manuscript contains 2 figures, 3 evidence/claim/protocol tables, and 8
verified references. It identifies source release `v1.2.0-beta.2`, commit
`5e212181ae177cd555ab6bb92f5f71ac8be9173a`, and GitHub Actions run
`32648392604`.

## Evidence boundary

The paper reports current automated engineering checks as regression and
contract evidence. It does not claim independent conformance, human efficacy,
scientific superiority, exact token waste, a complete privacy proof, a signed
public binary, or verified macOS 13 runtime behavior.

No private Codex state, task text, prompt excerpt, local path, real-work
screenshot, credential, or participant record is included.

## Author confirmation gate

Before removing the draft notice or sending the submission, the author must
confirm all of the following as true:

1. The public author name is `Mehmet Solak` and the corresponding ORCID is
   `0000-0003-2528-7960`.
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

Only after these statements are confirmed should the draft notice and
`AUTHOR_CONFIRMATION_REQUIRED` values be replaced, the two output files rebuilt,
and the portal's final submit action used.

## Post-publication verification

After screening and public posting:

1. Record the public URL, DOI, date, and version.
2. Add the DOI to `CITATION.cff` and the repository documentation in a new
   commit; do not rewrite the evaluated release tag.
3. Verify that the public page and PDF are accessible without authentication.
4. Search Google Scholar by the exact quoted title periodically. A same-day
   result is not expected or guaranteed.
