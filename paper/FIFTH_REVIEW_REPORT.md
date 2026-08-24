# Fifth Codex-assisted internal scientific and reference review

Date: 24 August 2026

Decision: `NO_SUBMIT` until the named-author declarations, research-package
license grant, declaration-complete final artifacts, exact-commit provenance,
clean-clone and public-CI gates, and a separate irreversible portal confirmation
are complete. This was a same-project AI-assisted adversarial review, not human
peer review, external validation, independent reproduction, editorial
screening, or acceptance.

## Verdict

No P0 issue was found. One new P1 methods defect was identified and corrected
with an explicitly post-freeze supplement; the historical V1 artifacts remain
unchanged. The already known author, license, final-artifact, and exact-commit
P1 gates remain fail-closed.

After the corrections in this report, the manuscript is defensible as a narrow
software Technical Note about an implementation and retrospective synthetic
policy-layer evaluation. It is not evidence of a scientific breakthrough,
product efficacy, improved productivity, correct task choice, exact token waste,
security isolation, exhaustive coverage, or comparative superiority.

## P1 methods finding and disposition

### V1 output observability gap

The frozen V1 exact-output corpus does not expose every written triage
reason/weight rule. The ranker deliberately returns an empty `rankedCandidates`
array whenever it abstains for a low score or close competition. Across all 75
frozen triage outputs, `deadlineWithinWeek`, `lowImportance`,
`agingWithoutPlan`, and triage `recentlyActive` never appear as visible reason
codes; the corpus also has no zero-input portfolio. A change to one of those
rules could therefore preserve the same final abstention and still pass V1
155/155.

The correction does not rewrite or reinterpret V1 as stronger evidence. It:

1. narrows the manuscript to exact agreement with the finite frozen expected
   outputs;
2. discloses the unobservable reason codes and missing zero-input boundary in
   Methods, Results, Limitations, Discussion, and the claim ledger;
3. adds six current-branch focused tests that expose the four reason codes,
   both `agingWithoutPlan` weights, and the zero-input result;
4. adds a standard-library temporary-copy mutation harness; and
5. records a separate post-freeze matrix and machine-readable result.

The unmodified supplement baseline passed 6/6 focused tests. Five compiling
weight mutations covered the four hidden reason codes, with separate mutations
for the two aging weights; a sixth mutation changed the empty-portfolio result.
Every corresponding named test failed, so 6/6 enumerated mutations were killed.
The harness did not edit the repository working tree.

Artifacts:

- `Tests/ActivityRadarCoreTests/WorkContinuityTests.swift`
- `Research/run_rule_observability_mutations.py`
- `Research/results/POST_FREEZE_RULE_OBSERVABILITY_V1.md`
- `Research/results/post-freeze-rule-observability-v1.json`

This closes the enumerated observability defect as current-branch regression
evidence. It is not part of V1, a complete mutation analysis, exhaustive path or
state coverage, an external oracle, or human-utility evidence.

## P2 scientific and source corrections

1. **Baseline-mechanism attribution.** The manuscript no longer calls all 35
   recency-only selections ranking-suppression violations. Those cases comprise
   18 `insufficientEvidence`, 12 `noEligibleWork`, two `incompleteHistory`, and
   three `competingSignals` results, and combine the removal of deferrals,
   eligibility, scoring, threshold, and lead rules. The 16
   same-score/no-suppression cases comprise 13 `insufficientEvidence` and three
   `competingSignals` results and isolate only threshold and lead removal.
2. **Source-comment semantics.** The current source comment now says that the
   ranker does not inspect lexical text content but does use the trimmed
   presence of next-action and waiting text. The historical wording and source
   hash remain preserved at the evaluated checkpoints; current executable logic
   is unchanged, while the comment-only current source bytes intentionally
   differ.
3. **Scientific text versus release operations.** The dirty-worktree state,
   number of internal review rounds, provisional document QA, and unresolved
   portal workflow were removed from the manuscript's Limitations section and
   retained in the submission-readiness records. The manuscript keeps only the
   scholarly archival and independence boundary.
4. **Contribution-evidence mapping.** The Introduction now states that the
   first two contributions are source-backed descriptions, only the pure policy
   layer in the third contribution is evaluated by the frozen experiment, and
   the claim ledger is an audit artifact rather than outcome evidence.
5. **Performance precision.** Table 4 now presents rounded descriptive values
   and points to the archived JSON for full recorded precision.
6. **AI disclosure granularity.** Methods, declarations, and portal metadata now
   explicitly name assistance with the specification, Python oracle, synthetic
   fixtures, benchmark runner, tests, manuscript, formatting, and internal
   adversarial review. AI remains excluded from authorship and independent
   validation.

## Reference-integrity audit

All 32 references are present, sequential, cited, non-duplicated, and connected
to a nearby claim. Seventeen DOI records resolved with matching metadata, and
all 15 direct authoritative URLs returned successfully on 24 August 2026. No
fabricated reference, dead identifier, stale product title, duplicate, or
silently used placeholder was found.

Three corrections were made:

- Reference [27] now uses the authoritative proceedings title, including “New
  Ideas, New Paradigms.”
- Reference [18] enumerates its five authors rather than inconsistently using
  `et al.`.
- The Introduction now uses prior-feature overlap only to reject first-of-kind
  claims. The absence of a direct comparative evaluation is the reason the
  report makes no superiority claim; the cited prior work is not misused as a
  superiority test.

Reference [12] remains a live workshop-hosted PDF whose displayed DOI is a
literal placeholder. The placeholder is deliberately not cited, and the
manuscript discloses the weaker persistence boundary.

## Current automated verification

- Enforced Swift discovery found and passed 100/100 tests, including the six
  post-freeze observability tests.
- All 16/16 deterministic self-tests passed.
- A current-tree benchmark rerun passed 155/155 exact conformance and returned
  canonical digest
  `fd72e52b8098d2f62f6c6f7ccc6de7e744de7ed03722d08c7f983527601db8e6`.
- The mutation supplement passed 6/6 focused tests and killed 6/6 enumerated
  mutations.
- Python compilation and `git diff --check` passed after the corrections.

These are local current-tree checks. They do not close the exact-commit,
clean-clone, hosted dual-architecture, final-artifact, or author-declaration
gates.

## Provisional document and public-source package QA

The declaration-pending Draft 0.5 candidate was rebuilt only for internal
review; it is not a deposit artifact.

- The DOCX rendered to 30 pages. A page-by-page inspection found no clipping,
  overlap, broken glyph, split code block, unjustified blank page, orphaned
  heading, or table/figure defect. Its OOXML package contains 18 parts, 469
  paragraphs, seven tables, 64 non-splitting table rows, two drawings, 37
  external hyperlinks, and two image relationships, with no tracked changes,
  comment/people/custom-XML part, or non-unit ordered-list restart.
- The direct PDF rendered to 17 A4 pages after the final-page bibliography
  imbalance was corrected. A second complete page-by-page inspection passed;
  all 32 references remain readable, and the last reference has safe footer
  clearance. The searchable PDF has the intended title, author, subject, and
  keywords; it is unencrypted and contains no form, JavaScript, embedded file,
  stale Draft 0.4 marker, internal search identifier, or private local path.
- The standard-library compressed-artifact privacy scanner passed on copies of
  the actual provisional DOCX and direct PDF.
- The DOCX SHA-256 is
  `0f5fe50fceb1872491fab0232f90e50c72600fed9583c052fe4311902b020d0f`;
  the direct-PDF SHA-256 is
  `3d553317286e5355f2141e097271b8074ac04b677c9179c83b68fd8c0afe6554`.
- `PUBLIC_SOURCE_MANIFEST.txt` contains 113 sorted, unique, existing paths. A
  manifest-only export of the current dirty revision passed the complete
  public-source preparation gate: 100 Swift tests, 16 self-tests, arm64 and
  x86_64 cross-builds, Universal2 bundle/signature/topology/archive contracts,
  packaging metadata, acceptance schemas, and adversarial privacy fixtures.

These checks are bounded current-tree evidence. Author declarations will alter
the artifact bytes, and no clean exact-commit reproduction or hosted-current-
revision CI result exists yet. Therefore none of this closes the final-artifact,
source-provenance, or submission gate.

## Preprints.org route compliance audit

Official pages were rechecked on 24 August 2026:

- https://www.preprints.org/instructions-for-authors
- https://www.preprints.org/help-center/submission-guidelines
- https://www.preprints.org/news/post/openalex-indexing
- https://www.preprints.org/

The planned `Technical Note` type and `Computer Science and Mathematics` /
`Software` subjects fit the stated platform categories. The canonical draft has
English text, first-page title, author, affiliation, corresponding-author
contact, abstract, keywords, a comprehensive bibliography, Methods AI
disclosure, Data Availability, and a separate conflict-of-interest section.
Word submission is accepted. A graphical abstract is recommended rather than
required.

The route remains free and uses CC BY 4.0. The platform describes editorial
screening, commonly targeting about one working day, but this is not peer review
or an acceptance guarantee. It states that posted content is discoverable
through Google Scholar and OpenAlex, but no indexing date is guaranteed. It also
assigns a DOI, requires a permanent non-exclusive distribution license, and may
retain or mirror the record after withdrawal. Those irreversible terms remain
part of the author-confirmation gate.

## Remaining fail-closed gates

1. The named author must confirm identity, affiliation, funding, competing
   interests, sole-author contribution, AI disclosure, rights, duplicate status,
   institution/journal/funder/patent compatibility, corresponding-author
   responsibilities, the MIT/CC BY 4.0 license map, and Preprints.org permanence
   terms.
2. Activate and record the final research-package CC BY 4.0 grant only after
   that authority is confirmed.
3. Rebuild the declaration-complete DOCX and PDF; inspect every page; verify
   structure, metadata, links, references, and compressed privacy; and record
   exact final hashes. The 30-page DOCX and 17-page PDF results above are only
   provisional rehearsals of this gate.
4. Freeze, commit, and push the exact revision; require exact manifest/tree
   equality, reproduce from a clean detached clone, and pass public exact-commit
   CI on the supported hosted architectures.
5. Obtain a separate explicit confirmation immediately before the portal's
   final **Submit** action.

No file has been uploaded to a preprint portal and no preprint submission has
occurred.
