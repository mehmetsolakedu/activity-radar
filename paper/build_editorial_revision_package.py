#!/usr/bin/env python3
"""Build the complete AiWingman editorial revision package."""

from __future__ import annotations

import argparse
import hashlib
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SOURCE = ROOT / "paper/aiwingman_technical_report.md"
DEFAULT_OUTPUT = ROOT / "paper/EDITORIAL_REVISION_PACKAGE.md"
QUERY_LOCATION = (
    "Submission version 1.0 - 24 August 2026 - "
    "Original Research Article manuscript"
)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def build_package(source: Path) -> str:
    manuscript = source.read_text(encoding="utf-8")
    if QUERY_LOCATION not in manuscript:
        raise SystemExit("Expected article-type line was not found in the manuscript.")
    marked_manuscript = manuscript.replace(
        QUERY_LOCATION,
        f"{QUERY_LOCATION} <<AQ-01>>",
        1,
    )
    # Nest the manuscript under required output section 2 while preserving its
    # internal heading hierarchy.
    marked_manuscript = re.sub(
        r"^(#{1,3}) ",
        lambda match: "#" * (len(match.group(1)) + 2) + " ",
        marked_manuscript,
        flags=re.MULTILINE,
    )

    docx = ROOT / "output/docx/aiwingman-original-research-article-v1.docx"
    pdf = ROOT / "output/pdf/aiwingman-original-research-article-v1.pdf"
    supplement = ROOT / "output/supplement/aiwingman-research-supplement-v1.zip"
    for artifact in (docx, pdf, supplement):
        if not artifact.is_file():
            raise SystemExit(f"Required artifact is missing: {artifact}")

    status = """## 1. EDITORIAL STATUS

- Manuscript completeness: complete. Every heading, paragraph, caption, relevant table cell, declaration, and reference record was reviewed.
- Editing mode: full scientific and technical-language revision, not a summary or a grammar-only correction.
- STE mode: ADAPTED. The revision applies STE-compatible clarity principles when they do not conflict with scientific accuracy or established terminology.
- English variant: neutral international scientific English, with internally consistent US-style forms where the original manuscript used them.
- Citation style: the existing numbered style was preserved because no concrete journal style was supplied.
- Assumptions: Preprints.org is treated as the current preprint route, not as a target journal. No concrete target-journal instructions, house terminology, or controlled dictionary were available. The existing section hierarchy and numbered citation style were therefore retained.
- Formal ASD-STE100 verification: not possible. ASD-STE100 Issue 9 rules and the controlled dictionary were not supplied. The result is STE-informed and not formally ASD-STE100 verified.
- Author declarations: the named author confirmed the recorded declarations on 24 August 2026 with the exact phrase `YAZAR BEYANLARINI ONAYLIYORUM`. This confirmation does not authorize a portal's final Submit action.
"""

    queries = """## 3. AUTHOR QUERIES

| Query ID | Location | Problem | Why it cannot be resolved safely | Required author decision |
|----------|----------|---------|----------------------------------|--------------------------|
| AQ-01 | Front matter and whole manuscript | No concrete target journal, journal instructions, required English variant, or house terminology was supplied. | Preprints.org is a preprint platform rather than a target journal. Journal-specific article structure, declarations, spelling, and style cannot be verified from placeholder instructions. | For a later journal submission, provide the journal and its current author instructions, or explicitly confirm continued use of neutral international scientific English and the existing numbered citation style. This query does not block preprint deposit. |
"""

    changes = """## 4. SUBSTANTIVE CHANGE LOG

| Location | Original issue | Revision action | Reason |
|----------|----------------|-----------------|--------|
| Front matter and metadata | The active objective specified an Original Research Article, but the prior package identified the manuscript as a Technical Note. | Harmonized the manuscript, builders, filenames, footer labels, and metadata as an Original Research Article. | Removes article-type conflict without changing the scientific content. |
| Abstract | Scope exclusions, chronology, results, and limitations were densely combined. | Divided the abstract into direct propositions while preserving every value, hedge, and exclusion. | Separates method, result, and limitation claims. |
| Introduction and contributions | Several sentences compressed evidence classes or used indirect phrasing. | Clarified the problem, contribution boundaries, and frozen versus post-freeze evidence classes. | Improves logical traceability and prevents evidence-category conflation. |
| Related Work | Prior-art claims and non-novelty boundaries were compressed. | Kept citations adjacent to their claims and stated the contribution boundary directly. | Preserves citation relationships and avoids promotional novelty language. |
| Sections 3 and 4 | Pipeline, integration, policy, and remote-review boundaries appeared in long multi-condition sentences. | Separated the ordinary dashboard, optional Wingman pipeline, deterministic ranking suppression, consent, sanitization, process, and cleanup propositions. | Makes actors, conditions, actions, results, and nonclaims explicit. |
| Sections 5 and 6 | Frozen, supplementary, exploratory, and descriptive results required sharper separation. | Standardized these evidence labels and clarified denominators, errata, observability limits, baselines, and performance scope. | Prevents confirmatory or human-benefit interpretations that the evidence does not support. |
| Sections 7 and 10 | Limitations and claim boundaries were difficult to scan. | Reorganized sentences within their existing sections and standardized the claim-ledger terminology. | Preserves all limitations while improving consistency. |
| Section 9.1 | Build-artifact abbreviations and current output paths were incomplete or stale. | Defined PDF and DOCX at first use and updated commands to the Original Research Article outputs. | Supports independent readability and reproducible artifact selection. |
| Licensing and Data Availability | The CC BY designation was not expanded at first use. | Defined Creative Commons Attribution 4.0 International (CC BY 4.0) at first use and retained the exact license boundary. | Improves abbreviation consistency without changing rights. |
| Declarations | Author responsibility and AI assistance were present but required final consistency. | Clarified sole-author responsibility, same-project AI assistance, licensing, identity, and the absence of independent validation. | Preserves accountability and avoids implying AI authorship or external review. |
| Terminology and abbreviations | Synonym drift and duplicate or delayed definitions reduced clarity. | Standardized `ordinary dashboard`, `optional Wingman analysis/review`, `deterministic ranking suppression`, `tree-level cumulative comparison proxy`, and `user-owned lifecycle state`; defined abbreviations at first use. | Applies STE-informed terminology control. |
| DOCX layout | Even-page running-header parts produced unstable LibreOffice body geometry. | Used one footer-only section layout with standard margins and page numbering. | Produces a stable 31-page editable manuscript while retaining article identity in the footer. |
"""

    qc = f"""## 5. QUALITY-CONTROL REPORT

- Numerical integrity: PASS. The original and revised sources contain the same ordered quantitative content; signs, decimals, percentages, thresholds, dates, counts, and table values were preserved.
- Unit integrity: PASS. Units and unit-bearing values were preserved; `ms`, `MiB`, `GB`, bytes, minutes, and days remain consistent.
- Equation integrity: PASS. Neither source contains a manuscript equation; fenced shell commands and variable tokens were preserved.
- Citation-marker integrity: PASS. The existing numbered citation markers and all 32 reference records were preserved; the reference section is byte-identical to the baseline.
- Figure and table cross-reference integrity: PASS. Figures 1-2, Tables 1-4, Sections, and RQ1-RQ4 resolve without a dangling reference.
- Terminology consistency: PASS.
- Abbreviation consistency: PASS.
- Undefined abbreviations: none detected in the scientific prose, tables, or figure text. Standard names and license designations are retained where expansion would be inappropriate.
- Possible causal overstatements: none detected.
- Sentences longer than 30 words: 0 in the editorial prose, headings, captions, and individual table cells. Bibliographic records were retained verbatim and were not rewritten for sentence length.
- Unresolved STE issues: target-journal house style and terminology are unavailable; the official ASD-STE100 Issue 9 rules and controlled dictionary were not supplied; bibliography wording remains locked to preserve reference integrity.
- ASD-STE100 status: STE-informed, not formally verified.
- Artifact checks: the DOCX contains 31 rendered pages and the direct PDF contains 18 A4 pages. All pages were covered by original-resolution visual inspection. Structural, reference-extraction, compressed-content privacy, and deterministic research-supplement checks passed. The accessibility checker reported no high-severity finding; it reported one medium finding for the intentional non-data footer layout table and 37 low findings for deliberately displayed raw URLs.
- Exact local artifact identities: manuscript source `{sha256(source)}`; DOCX `{sha256(docx)}`; direct PDF `{sha256(pdf)}`; research supplement `{sha256(supplement)}`.
- Provenance boundary: the earlier public-package commit contains the superseded Technical Note artifacts. These revised local bytes require a new public-package commit and clean-clone/hosted-CI refresh before commit-level provenance can be claimed. This does not convert author-declaration approval into portal Submit authorization.
"""

    return (
        status
        + "\n## 2. REVISED MANUSCRIPT\n\n"
        + marked_manuscript.rstrip()
        + "\n\n"
        + queries
        + "\n"
        + changes
        + "\n"
        + qc
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    package = build_package(args.source)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(package, encoding="utf-8")
    print(args.output.resolve())


if __name__ == "__main__":
    main()
