# AiWingman publication artifact manifest

Status: `FINAL_ARTIFACT_QA_PASS_EXACT_PUBLIC_COMMIT_PENDING`

Recorded: 24 August 2026

This manifest identifies the declaration-complete AiWingman Technical Note
submission-version artifacts. It records the exact local bytes and bounded QA
evidence. It does not represent a portal upload, a Preprints.org submission,
screening, public posting, DOI assignment, Google Scholar indexing, peer review,
or acceptance.

## Exact artifacts

| Artifact | Intended role | Size | Extent | SHA-256 |
| --- | --- | ---: | ---: | --- |
| `output/docx/aiwingman-technical-note-v1.docx` | Editable main manuscript | 206,417 bytes | 30 rendered pages | `49800b75b2d33ab85507defec85c814c9844b8c2a53496f2f0c4515852829dfb` |
| `output/pdf/aiwingman-technical-note-v1.pdf` | Author-rendered QA/reference copy; not a second main manuscript | 210,658 bytes | 17 A4 pages | `575aef866b6dda6a5165218bec79479424ab192a90291ec9c690729d2778481c` |
| `output/supplement/aiwingman-research-supplement-v1.zip` | CC BY 4.0 non-executable research supplement | 32,595 bytes | 10 files plus 5 directory entries | `142dca3e1924ff91997126ba6c9ce2b02e323e93d2fc02d5c8b588510fe987d0` |

## Canonical inputs

| Input | SHA-256 |
| --- | --- |
| `paper/aiwingman_technical_report.md` | `152e8d7849488f7fbf08b502a3a6350e1bebbc09b32cbb21acd0735781524f43` |
| `paper/build_submission_docx.py` | `7ed8edd8d5ac30d27600111802746c7160347a1905c6e0f5e431e2b1f50a9d2b` |
| `paper/build_preprint.py` | `7bf6898d5b5eed9b43327964a71dbe8d07376ea04192fba291f4af911234a330` |
| `scripts/build-preprint-supplement.sh` | `26a4fb27884ec296ce8976fcfecaa3e9d8d1dff062f4262e3749b9860667d860` |

The final artifacts were built from the current publication branch working
revision whose pre-finalization base was
`99faac3ef52d0da72d082706f64903a6aacd2c6d`. The exact public package commit is
recorded only after the manifest-listed tree is committed, pushed, cloned back,
and checked; that provenance gate remains open at the time of this manifest.

## Build environment

- macOS 26.6.2, build 25G83, arm64
- Python 3.12.13
- python-docx 1.2.0
- ReportLab 4.4.9
- Pillow 12.3.0
- DOCX rasterization for visual QA: LibreOffice through the bundled document
  renderer
- PDF rasterization for visual QA: Poppler 26.05.0 at 144 dpi

## QA record

### DOCX

- PASS: 30 of 30 rendered pages were inspected after the final pagination
  correction. The RQ lead-in remains with the first item, the three-hash
  paragraph remains intact, references are not split, and no clipping,
  overlap, missing glyph, malformed table, broken code block, orphaned heading,
  or excess terminal page was found.
- PASS: the package contains 18 ZIP members, 469 XML paragraphs, 7 tables and
  64 rows; every table row carries `cantSplit`. It contains 2 drawings, 37
  hyperlinks, and 2 image relationships.
- PASS: no comments, people part, custom XML, tracked insertion/deletion/move,
  private local path, draft warning, or author-confirmation placeholder is
  present.
- PASS: core metadata records Mehmet Solak, the final title, submission-version
  subject/keywords, an empty `lastModifiedBy`, and fixed 24 August 2026
  created/modified dates.
- Accessibility audit: 0 high, 0 medium, and 37 low findings. Every low finding
  is a deliberately displayed raw repository, DOI, documentation, or reference
  URL; no higher-severity finding remains.

### Direct PDF

- PASS: 17 of 17 A4 pages were inspected. Pages 1-15 are byte-render equivalent
  to the previously accepted final-layout candidate; pages 16-17 were inspected
  again after the declaration and Data Availability edits. No clipping,
  overlap, missing glyph, malformed table/figure/code block, or incomplete
  declaration was found. References `[1]` through `[32]` are complete and
  readable.
- PASS: title, author, subject, keywords, submission version, declarations, Data
  Availability, conflicts statement, and all 32 references are extractable.
- PASS: the PDF is unencrypted and contains no form, JavaScript, OpenAction, or
  additional-action entry.
- The direct PDF is untagged. It is retained as the author's fixed-layout QA and
  reference copy; the editable DOCX is the planned portal main manuscript.

### Privacy and supplement

- PASS: the fail-closed compressed-artifact scanner accepted the final DOCX and
  direct PDF, including decoded package and stream surfaces. It found no private
  home path, non-synthetic task URI or UUID, or credential pattern.
- PASS: the supplement contains exactly `paper/SUPPLEMENT_README.md` plus the
  nine listed non-executable protocol, synthetic-fixture, result, manifest,
  summary, and erratum files. Every file is byte-equal to its repository source,
  mode 0644, and free of symlinks, unsafe paths, hidden macOS entries,
  encryption, archive comments, and extra fields.
- PASS: CRC verification and `ZipFile.testzip()` succeeded. Two delayed rebuilds
  were byte-for-byte identical to the recorded ZIP; all archive timestamps are
  fixed at 24 August 2026 00:00.
- PASS: the supplement README grants CC BY 4.0 only to the listed non-executable
  research package and keeps executable software, tests, scripts, builders, and
  research drivers under MIT.

### Public-source preparation

- PASS: a final 117-file manifest-only export passed the complete local
  `REQUIRE_STANDARD_TESTS=1` public-source preparation gate. The run included
  adversarial privacy and archive-path fixtures, 16/16 deterministic self-tests,
  100/100 Swift tests through the fail-closed Command Line Tools fallback,
  fixed-schema diagnostics, arm64 and x86_64 macOS 13-targeted cross-builds,
  Universal 2 bundle/signature/topology checks, and the canonical metadata-free
  ZIP contract.
- PASS: the public exporter accepts only
  `output/supplement/aiwingman-research-supplement-v1.zip`; a negative fixture
  confirms that any other ZIP path is rejected.
- This was a manifest-only copy of the uncommitted working revision. It is not
  the still-open clean exact-commit or hosted-CI provenance gate.

## Remaining release gates

1. Commit exactly the paths in `PUBLIC_SOURCE_MANIFEST.txt` on the publication
   branch.
2. Verify manifest/tree equality and all release checks in a clean detached
   clone of that exact commit.
3. Push the exact commit and obtain passing hosted macOS verification and Intel
   runtime jobs for that commit.
4. Stage the record in Preprints.org without using the final **Submit** action.
5. Obtain a separate explicit author approval before the portal's final
   **Submit** action.
