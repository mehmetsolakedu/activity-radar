# AiWingman publication artifact manifest

Status: `SUBMITTED_PENDING_CHECK_PUBLIC_PACKAGE_PROVENANCE_PASS`

Recorded: 24 August 2026

This manifest identifies the exact AiWingman Original Research Article
submission-version artifacts and the bounded quality evidence for those bytes.
The corresponding Preprints.org record was submitted on 24 August 2026 after
separate explicit author approval. The portal assigned Preprints ID `229981`
and displayed the status `Pending Check`. This manifest does not represent a
successful screening decision, public posting, DOI assignment, indexing, peer
review, or acceptance.

## Exact artifacts

| Artifact | Intended role | Size | Extent | SHA-256 |
| --- | --- | ---: | ---: | --- |
| `output/docx/aiwingman-original-research-article-v1.docx` | Editable main manuscript | 205,492 bytes | 31 rendered pages | `edb7b5f111f1d122108516dbaf08c0aba433265588b84b1c8a39d18392026cac` |
| `output/pdf/aiwingman-original-research-article-v1.pdf` | Author-rendered QA/reference copy; not a second main manuscript | 213,105 bytes | 18 A4 pages | `bc4a1b5822552f5a90082227c5ac9619b54f34dd3558d5bb76dd0c95e6629e1b` |
| `output/supplement/aiwingman-research-supplement-v1.zip` | CC BY 4.0 non-executable research supplement | 32,600 bytes | 10 files plus 5 directory entries | `07a473573e4246b215f9dc49596a16e5951b1a521d26625806acb04f2853523a` |

The older Technical Note DOCX and PDF remain in the output tree only as
superseded historical artifacts. They are excluded from the submission set.

The required five-part editorial output is
`paper/EDITORIAL_REVISION_PACKAGE.md`: 90,928 bytes, SHA-256
`7fc9f121f6a9d6c92ba8a708750d87f71bd3f0577e89231ab4f13f33406b735b`.

## Canonical inputs

| Input | SHA-256 |
| --- | --- |
| `paper/aiwingman_technical_report.md` | `a4b8a0be0183b7cb4e303244a0725e9eb2e7a2f23598554a5dc1f4921964fa0e` |
| `paper/build_submission_docx.py` | `259b2f9dfb1007a5c8c8c7155f4bed824bd08d25afd1068ba0c3bacd14e2e89f` |
| `paper/build_preprint.py` | `932b182a424da99e2a352124a60c75ffd67e305fced51ac7cf79ac7404191219` |
| `scripts/build-preprint-supplement.sh` | `26a4fb27884ec296ce8976fcfecaa3e9d8d1dff062f4262e3749b9860667d860` |
| `paper/build_editorial_revision_package.py` | `4951ff0085bc87ed50cbc0770efa95e9bcc3de9348bdda8cadad7dece8c43387` |

## Build environment

- macOS 26.6.2, build 25G83, arm64
- Python 3.12.13
- python-docx 1.2.0
- ReportLab 4.4.9
- Pillow 12.3.0
- DOCX conversion for visual QA: LibreOffice through the bundled document
  renderer
- PDF rasterization for visual QA: Poppler at 144 dpi

## QA record

### Manuscript integrity

- PASS: the pre-edit and revised sources have the same numeric multiset: 598
  matched quantitative tokens under the locked comparison expression.
- PASS: all 55 numbered citation occurrences, 37 URLs, and 10 numbered
  Table/Figure/Section cross-references were preserved.
- PASS: the 32-entry, 7,262-byte reference section is byte-identical to the
  pre-edit source.
- PASS: no prose, heading, caption, list item, or individual table-cell sentence
  exceeds 30 words. Bibliographic records were retained verbatim.
- PASS: no causal, efficacy, superiority, privacy, security, compatibility, or
  determinism claim was strengthened.
- The language is STE-informed, not formally ASD-STE100 verified. Issue 9 rules
  and the controlled dictionary were not supplied.

### DOCX

- PASS: the final 31-page render was covered page by page at original
  resolution. Thirty pages were raster-byte identical to the fully inspected
  final candidate; the only text-changed page, page 26, was inspected again.
  No clipping, overlap, malformed glyph, broken table/code flow, orphan heading,
  or margin/footer defect was found.
- PASS: the package contains 17 ZIP members and 478 document-body XML
  paragraphs. It contains 7 tables, 64 rows with `cantSplit`, 2 drawings, 37
  hyperlinks, and 2 image relationships.
- PASS: it has no running-header part, comment, people part, custom XML, or
  tracked insertion/deletion/move. It contains one consistent footer with the
  article type, submission version, date, and page number.
- PASS: core metadata records Mehmet Solak, the final title, subject, keywords,
  an empty `lastModifiedBy`, and the Original Research Article label.
- Accessibility audit: 0 high, 1 medium, and 37 low findings. The medium finding
  is the intentional one-row, non-data footer layout table, which has no data
  header. The low findings are deliberately displayed raw repository, DOI,
  documentation, or reference URLs.

### Direct PDF

- PASS: the final 18-page A4 PDF was covered page by page at original
  resolution. Seventeen pages were raster-byte identical to the fully inspected
  final candidate; the only text-changed page, page 15, was inspected again.
  No clipping, overlap, missing glyph, malformed figure/table/code block, or
  incomplete declaration/reference was found.
- PASS: the title, author, subject, keywords, submission version, declarations,
  Data Availability statement, conflicts statement, and references `[1]` through
  `[32]` are extractable.
- PASS: the PDF is unencrypted and contains no form, JavaScript, OpenAction, or
  additional-action entry.
- The direct PDF is untagged. It is retained as a fixed-layout QA/reference copy;
  the editable DOCX is the planned portal main manuscript.

### Privacy and supplement

- PASS: the fail-closed compressed-artifact scanner accepted the exact final
  DOCX and direct PDF. It found no private home path, non-synthetic task URI or
  UUID, or credential pattern.
- PASS: the supplement contains exactly `paper/SUPPLEMENT_README.md` plus the
  nine listed non-executable protocol, synthetic-fixture, result, manifest,
  summary, and erratum files. Every file is byte-equal to its repository source,
  mode 0644, and free of symlinks, unsafe paths, encryption, archive comments,
  extra fields, and hidden macOS entries.
- PASS: CRC verification and `ZipFile.testzip()` succeeded. Two delayed rebuilds
  were byte-for-byte identical to each other and to the recorded ZIP. All archive
  timestamps are fixed at 24 August 2026 00:00.
- PASS: the supplement README grants CC BY 4.0 only to the listed non-executable
  research package and keeps executable software, tests, scripts, builders, and
  research drivers under MIT.

## Public-package provenance boundary

The earlier exact public-package commit
`328db87d8a39f7d14f32d6993990daae57fa1092` and hosted CI run `32699022868`
attest the superseded Technical Note package. They do not attest the revised
Original Research Article bytes listed above.

The revised 121-file public package is frozen at exact commit
`b3305f69fac710c77b9595cd1d269ef505d65652`. That commit was pushed without a
force update to `codex/aiwingman-technical-preprint`, cloned back through HTTPS,
checked out detached, and verified clean. Its tracked tree matches
`PUBLIC_SOURCE_MANIFEST.txt` exactly. The DOCX, PDF, and supplement bytes in the
clean clone match the sizes and SHA-256 values recorded above.

The complete fail-closed public-source preparation gate passed both before the
freeze commit and in the clean detached clone. Each run included manifest and
packaging checks, privacy adversarial fixtures, 16 deterministic self-tests,
100 standard Swift tests, fixed-schema diagnostic checks, arm64 and x86_64
macOS 13-targeted builds, and Universal 2 bundle and archive verification.

GitHub Actions run `32768213278` checked out that exact freeze commit through a
manual workflow dispatch. Its `macOS verification` and native `Intel runtime`
jobs both completed successfully. The jobs passed the complete public-release
gate, native standard tests, the 155-fixture continuity-policy benchmark,
content-free diagnostic assertion, and native application builds as applicable.

The Preprints.org record was staged and reviewed as an `Article` under
`Computer Science and Mathematics` / `Computer Science`. The uploaded files are
the exact DOCX, PDF, and supplement listed above. The sole-author record,
corresponding-author designation, ORCID, affiliation, ethics/participation
answers, repository URL, and portal terms acceptance were also reviewed. After
the author supplied the separate final-submit authorization, the record was
submitted and assigned Preprints ID `229981`; its observed portal status was
`Pending Check`.

## Remaining gates

1. Resolve the target-journal style query before a later journal submission.
   This does not block the preprint.
2. After screening and public posting, record the public URL, DOI, date, and
   version without describing `Pending Check` as acceptance or publication.
