# Second Codex-assisted internal submission audit

> Historical second-pass record. The current decision and source-level
> corrections are in `paper/THIRD_REVIEW_REPORT.md`.

Date: 23 August 2026

Decision: `NO_SUBMIT` until the named author confirms the declaration and
licensing gates and the final canonical artifacts pass the complete release
check. This audit is an internal, author-directed AI-assisted review. It is not
human peer review, external validation, or editorial acceptance.

## Scope

The second pass inspected the canonical manuscript, the generated DOCX and PDF,
the builders, portal metadata, licensing boundary, citation links, claim
ledger, declarations, and public-package privacy surface. It specifically
looked for unsupported novelty, efficacy, determinism, privacy, security,
compatibility, and provenance claims.

## P0 findings

None found. The reviewed package did not expose private Codex task content,
credentials, local file URLs, tracked changes, comments, custom XML, or private
workspace paths. No internal review is presented as peer review or independent
validation.

## P1 findings and disposition

1. **First-page front matter.** The prior DOCX split the abstract across pages
   1 and 2 and moved the keywords to page 2. The DOCX builder now uses a compact
   abstract-specific style while preserving the complete canonical text. A
   provisional rebuild was rendered to 25 page images; page 1 contains the
   title, author, affiliation, correspondence, full abstract, and keywords.
2. **Claim-ledger row splitting.** The prior DOCX split table rows at two page
   boundaries. The builder now emits `w:cantSplit` for every table row while
   preserving repeated headers. Provisional rendered pages 21 and 22 show only
   complete rows.
3. **License transition.** The manuscript and scholarly outputs remain outside
   the software's MIT license until the named author explicitly confirms CC BY
   4.0 distribution and the right to grant Preprints.org its permanent,
   non-exclusive distribution license. This remains an author gate and cannot
   be closed by automated review.

## P2 corrections

- Ordered Markdown items now become real Word numbering and ReportLab numbered
  lists instead of one flattened paragraph.
- The DOCX now contains external hyperlink relationships for repository,
  documentation, DOI, arXiv, and reference URLs.
- PDF reference records are kept together when each record fits on one page, so
  the last page no longer begins with an orphaned DOI continuation.
- The provisional DOCX accessibility audit reported zero high- or
  medium-severity issues. It reported 27 low-severity raw-URL labels; explicit
  scholarly URLs are retained to make citation targets auditable.

## Link and structure checks

All 27 public HTTP(S) targets in the manuscript reached the expected repository,
documentation, preprint, DOI, or publisher destination during the audit.
Nineteen returned HTTP 200, two IEEE targets returned HTTP 202, and six DOI
chains reached the expected ACM or PeerJ publisher target before that publisher
rejected the automated fetch with HTTP 403. This is a bounded resolver check,
not independent verification of every bibliographic fact.

Those counts describe the provisional manuscript before the later deep
bibliography audit expanded the related-work set to 32 references. The expanded
set requires a fresh final link, metadata, and layout check and does not inherit
the 27-target result above.

The provisional DOCX contained 198 body paragraphs, seven tables, two inline
figures with descriptions, 27 hyperlink relationships, real numbering
properties, no custom XML, and no high-severity accessibility finding. The
provisional review PDF was searchable, unencrypted, and 15 pages. All 25 DOCX
page images and all 15 PDF page images were visually inspected; no blank page,
clipped object, overlapping text, or split claim-ledger row was observed.

## Remaining submission gates

- Confirm author identity, affiliation, correspondence address, ORCID, funding,
  competing interests, contribution wording, AI-assistance disclosure, and
  responsibility for the final manuscript.
- Confirm CC BY 4.0 authority, Preprints.org distribution terms, record
  permanence, absence of duplicate publication, material rights, and
  institution, funder, journal, and patent-policy permission.
- Replace draft-only declarations and license status only after those
  confirmations.
- Rebuild the final DOCX and review PDF from the confirmed canonical source;
  repeat structural, metadata, privacy, all-page visual, manifest, clean-clone,
  and full test gates.
- Use a separate explicit confirmation before the irreversible portal submit
  action. Screening and a DOI record would not constitute peer review.
