# Fourth Codex-assisted internal methods and artifact review

Date: 24 August 2026

Decision: `NO_SUBMIT` until the named-author declarations, research-package
license grant, final publication artifacts, exact-commit provenance, clean-clone
gates, and separate irreversible portal confirmation are complete. This was an
internal AI-assisted review with separate methods, artifact-reproducibility, and
editorial tracks. It was not human peer review, external validation, independent
scholarly reproduction, editorial screening, or acceptance.

## Verdict

No P0 issue was found. Two previously hidden P1 boundaries were identified. One
is corrected in the canonical Draft 0.5 manuscript; the other remains
fail-closed pending the author's authority to grant a license. The already
acknowledged final exact-commit and artifact-provenance gate also remains open.

## P1 findings and disposition

1. **Post-freeze baseline chronology.** The written frozen protocol specified
   conformance, within-process repetitions, the bounded sentinel check, and
   descriptive performance, but it did not specify the recency-only or
   same-score/no-suppression baselines. Those definitions first appeared in the
   later Swift runner commit. Draft 0.5 now labels RQ3, Section 5.4, Section 6.2,
   the Discussion, and the claim-ledger result as post-freeze exploratory
   technical contrasts. The numerical results remain unchanged and are not
   represented as frozen or confirmatory evidence.
2. **Research-package reuse license.** The repository MIT license clearly
   covered software, tests, scripts, and software documentation, while the
   draft-status file addressed `paper/` and `output/`. The written protocol,
   synthetic fixture corpus, archived result data, and erratum therefore lacked
   an explicit reuse-license map. `paper/LICENSE_STATUS.md` now records their
   current all-rights-reserved status and the intended CC BY 4.0 map. That map
   cannot become a public grant until the named author explicitly confirms the
   right and intent to license it. The author gate now covers this scope.

## P2 methods corrections

- Draft 0.5 states that the reason weights and the 30-point score and 10-point
  lead thresholds are author-designed constants inherited from the pre-existing
  implementation, not empirically optimized, participant-derived, or calibrated
  probabilities, confidence values, risks, or utilities.
- The sentinel denominator now states the actual seeding boundary: five exact
  strings in 10 field placements across nine fixtures, with all 155 serialized
  outputs searched for all five strings.
- RQ4 now separates the size-specific latency distributions from the single
  process-lifetime peak-RSS observation made after the complete runner workload.
- The 1,000-input performance rows are labeled as synthetic policy-layer stress
  sizes above the current 200-row ordinary-dashboard return cap.
- The performance limitation now records the absence of independent-process
  reruns, randomized series order, thermal or frequency control, and confidence
  intervals; p95 is identified as a descriptive interpolated quantile of 30
  observations.
- The abstract now reports exact agreement with 155 frozen same-project
  specification-derived fixture outputs rather than general specification
  correctness.

## P2 artifact and reproducibility corrections

- Section 9 now includes a non-overwriting command sequence that regenerates the
  frozen expected-output corpus from the Python oracle and compares it byte for
  byte with the committed fixture.
- Section 9.1 now records the Python version, pinned package installation,
  manuscript build commands, font fallbacks, and why cross-environment DOCX/PDF
  byte identity is not expected.
- The final document hashes are deliberately not invented. A final publication
  artifact manifest must record the declaration-complete DOCX and PDF SHA-256
  values plus the visual, structural, metadata, and privacy gate results.
- Official OpenAI product documentation was rechecked on 24 August 2026. The
  manuscript now distinguishes ChatGPT desktop Activity and goal surfaces from
  Codex clients, Codex App Server, and review surfaces across the OpenAI product
  family instead of attributing every surface to Codex alone.

## P2 document-generation corrections and provisional verification

- All-page visual QA exposed a Word numbering-instance defect: the second
  non-adjacent ordered list continued at 5 instead of restarting at 1. The DOCX
  builder now assigns a distinct numbering instance to each Markdown ordered
  list. The three current ordered-list blocks render from 1.
- The vector PDF policy figure placed the descending arrow across the last
  letters of its `FAIL` label. The label was moved left of the stroke and the
  regenerated figure is legible.
- After those corrections, every page of a provisional, non-deposit Draft 0.5
  rebuild was visually inspected: 29 DOCX-rendered Letter pages and 18 direct
  A4 PDF pages. No remaining clipping, overlap, truncated row, orphaned final
  reference, or unreadable figure label was observed.
- The provisional DOCX contains no comment/people/custom-XML parts or tracked
  changes; its 63 body-table rows all carry `cantSplit`, its three ordered-list
  blocks use unique numbering instances starting at 1, and its two figures and
  37 external hyperlink relationships are present. The direct PDF has 18 pages,
  no encryption, form, JavaScript, or custom metadata, and extracted text
  contains references 1-32, the author gate, and no Draft 0.4 marker.
- The fail-closed compressed-artifact scanner passed separately on the
  provisional DOCX and direct PDF, and the 109-file manifest export passed the
  public privacy scan. A LibreOffice PDF used only to rasterize the DOCX could
  not be decoded by that scanner because of an unsupported PDF stream filter;
  it is a QA byproduct, not a planned deposit artifact. The actual DOCX bytes,
  their embedded members, and the direct PDF bytes were scanned successfully.
- These are provisional checks only. The named-author declarations change the
  manuscript text and metadata, so the final declaration-complete bytes must be
  rebuilt and the complete visual, structural, metadata, link, and privacy gate
  repeated before any upload.

## Separate internal verification evidence

- Numerical recomputation matched 155/155 conformance, 15,500 evaluations,
  15,345 nontrivial within-process comparisons, 1,550,000 actual policy calls and
  1,534,500 nontrivial comparisons across the historical 100-process loops, the
  70 unconfirmed lifecycle fixtures, both baseline tables, eight latency rows,
  and the 12.390625 MiB process-lifetime RSS conversion.
- The current working revision passed 94/94 discovered Swift tests and 16/16
  deterministic self-tests.
- A fresh remote clone reproduced the six source hashes listed in Section 9,
  verified freeze ancestry, regenerated the corpus byte-identically, and
  reproduced 155/155 and the canonical digest at the exact runner revision.
- A bounded two-process rerun of the supplementary driver returned the canonical
  digest in 2/2 processes. It was a wiring check, not a replacement claim for the
  archived 100-process result.
- Archived result hashes matched their manifests. Before this report was added,
  a manifest-only export contained 108 sorted, unique regular files and passed
  94/94 tests plus 16/16 self-tests. These current-tree results remain internal
  and uncommitted; the now 109-file manifest must be rerun after the final freeze.

## Remaining fail-closed gates

1. The named author must confirm identity, affiliation, funding, competing
   interests, sole-author contribution, AI assistance, rights, duplicate status,
   institutional/journal/funder/patent compatibility, CC BY 4.0 scope, and the
   permanent non-exclusive Preprints.org distribution terms.
2. Activate and record the final MIT/CC BY 4.0 license map only after that
   authority is confirmed.
3. Rebuild the declaration-complete DOCX and PDF; inspect every rendered page;
   verify metadata, links, structure, and compressed privacy; and record exact
   hashes in the publication artifact manifest.
4. Freeze, commit, and push the exact revision; reproduce from a clean detached
   clone; require exact manifest/tree equality and public exact-commit CI.
5. Obtain a separate explicit confirmation immediately before the portal's final
   **Submit** action. No file has been uploaded and no submission has occurred.
