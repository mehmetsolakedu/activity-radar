# Post-freeze continuity-rule observability supplement

Status: supplementary engineering regression; not part of frozen V1.

Date: 24 August 2026

## Why this supplement exists

The frozen V1 triage corpus compares exact public `WorkTriageResult` values.
Whenever the policy abstains for a low score or close competition, that result
intentionally contains no ranked candidates. The isolated V1 fixtures for four
reason codes therefore confirm only the final abstention; they do not expose the
corresponding reason code or weight. V1 also has no zero-input portfolio.

The V1 specification, oracle, corpus, manifests, and result JSON remain
unchanged. This supplement adds current-branch tests that combine each hidden
rule with sufficient independent evidence to make one candidate visible. It
also checks the empty-portfolio result. A temporary-copy mutation harness then
changes each asserted value separately and requires the corresponding focused
test to fail.

## Coverage and mutation matrix

| Rule or boundary | V1 output-level blind spot | Focused test | Exact visible assertion | Temporary mutation | Result |
| --- | --- | --- | --- | --- | --- |
| `deadlineWithinWeek`, weight 20 | Isolated score stays below 30, so reasons are hidden | `postFreezeObservabilityDeadlineWithinWeek` | score 30; ordered reasons 20 + 10; deadline evidence time | 20 to 21 | Killed |
| `lowImportance`, weight -10 | Isolated result abstains with no candidates | `postFreezeObservabilityLowImportance` | score 90; ordered reasons 100 - 10 | -10 to -9 | Killed |
| `agingWithoutPlan`, weight 12 | Isolated 7-to-30-day result abstains with no candidates | `postFreezeObservabilityAgingWithoutPlanSevenToThirtyDays` | score 32; ordered reasons 20 + 12; activity evidence time | 12 to 11 | Killed |
| `agingWithoutPlan`, weight 18 | Isolated 30-day-or-older result abstains with no candidates | `postFreezeObservabilityAgingWithoutPlanThirtyDaysOrMore` | score 38; ordered reasons 20 + 18; activity evidence time | 18 to 17 | Killed |
| triage `recentlyActive`, weight 8 | Isolated result abstains with no candidates | `postFreezeObservabilityRecentlyActive` | score 38; ordered reasons 20 + 10 + 8; activity evidence time | 8 to 9 | Killed |
| zero-input portfolio | No zero-input V1 fixture | `postFreezeObservabilityEmptyPortfolio` | `insufficientEvidence`; no recommendation, candidates, or deferrals | result changed to `noEligibleWork` | Killed |

All six focused tests passed in the unmodified temporary package copy, and all
six enumerated mutations were killed by their corresponding named test. The
machine-readable run record is
`Research/results/post-freeze-rule-observability-v1.json`.

## Reproduction

From the repository root:

```sh
python3 Research/run_rule_observability_mutations.py \
  --output /tmp/aiwingman-rule-observability.json
```

The harness copies `Package.swift`, `Sources/`, and `Tests/` to a new temporary
directory. It never edits the repository working tree. It fails closed if a
source mutation does not match exactly once, a baseline test is absent or
fails, a mutation survives, or failure output does not name the intended test.

## Interpretation boundary

This result demonstrates only that the six named current-branch tests expose
and detect the six enumerated simple mutations. It is not a complete mutation
analysis, path or state-combination proof, external reproduction, retrospective
repair of V1, evidence of calibrated ranking, or evidence of human benefit.
