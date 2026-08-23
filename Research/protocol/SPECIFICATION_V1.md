# AiWingman continuity-policy specification v1.0

Status: frozen candidate for pre-execution review

Scope: this specification covers only the pure, local continuity-policy value
layer implemented by `WorkContinuityRanker` and `WorkContinuityLifecycle`. It
does not specify Codex database compatibility, rollout parsing, task-tree token
analysis, graph heuristics, the user interface, or the optional remote Wingman
review. Passing this specification cannot establish user benefit, privacy of an
external process, or compatibility with an undocumented Codex schema.

All times are absolute seconds. One day is 86,400 seconds. String fields are
considered present only after trimming whitespace and newlines.

## 1. Triage inputs and precedence

Each input consists of one observed task, optional user-authored continuity
metadata, and an optional last-opened time. Evaluation follows this order:

1. Apply absolute deferrals.
2. Exclude an eligible item if its history is incomplete.
3. Derive content-free reason codes and integer weights.
4. Sum weights, sort candidates, and apply abstention rules.

### 1.1 Absolute deferrals

The first matching rule applies.

| Rule | Output |
| --- | --- |
| `snoozeUntil > now` | `snoozed`, retaining the due time |
| non-empty `waitingOn` | `waitingOnExternal` |
| execution is `completed`, or goal is `complete` while execution is not `openSilent`, `aborted`, or `recentlyActive`; and there is no direct attention signal, no deadline at or before `now + 3 days`, and no due snooze | `terminal` |

A deferred item is not scored. Deferrals are sorted by activity identifier.

### 1.2 Incomplete history

An incomplete, non-deferred item is ineligible for scoring. Its presence does
not suppress a recommendation supported by a different complete item. The
result is `incompleteHistory` only when no candidate remains and at least one
eligible incomplete item was observed.

### 1.3 Reason codes and weights

Reason order is normative because serialized output preserves it.

| Order | Condition | Reason code | Weight |
| --- | --- | --- | ---: |
| 1 | explicit input requested | `explicitInput` | 100 |
| 1 | blocked goal | `goalBlocked` | 90 |
| 1 | unseen final result | `unseenResult` | 80 |
| 1 | usage limited | `usageLimited` | 70 |
| 1 | budget limited | `budgetLimited` | 70 |
| 2 | deadline due or overdue | `deadlineOverdue` | 65 |
| 2 | deadline within 1 day | `deadlineWithinDay` | 55 |
| 2 | deadline within 3 days | `deadlineWithinThreeDays` | 40 |
| 2 | deadline within 7 days | `deadlineWithinWeek` | 20 |
| 3 | snooze is due and no opening occurred at or after its due time | `plannedReturnDue` | 45 |
| 4 | critical importance | `criticalImportance` | 30 |
| 4 | high importance | `highImportance` | 20 |
| 4 | low importance | `lowImportance` | -10 |
| 5 | non-empty next action | `nextActionRecorded` | 10 |
| 5 | no next action and age is at least 7 but less than 30 days | `agingWithoutPlan` | 12 |
| 5 | no next action and age is at least 30 days | `agingWithoutPlan` | 18 |
| 6 | execution is recently active | `recentlyActive` | 8 |
| 7 | last opening is between 0 and 15 minutes old, inclusive | `recentlyOpened` | -15 |

The waiting reason code is not emitted by the current policy because the
absolute waiting deferral precedes scoring.

### 1.4 Sorting, visibility, and abstention

Candidates are sorted by descending score and then ascending activity
identifier. The recommendation threshold is 30 points. A recommendation also
requires a lead of at least 10 points over the second candidate. The result
exposes no ranked candidates whenever it abstains.

If there are no candidates, abstention is:

1. `incompleteHistory` if at least one non-deferred incomplete item exists;
2. otherwise `noEligibleWork` if deferrals exist and no complete eligible item
   was observed;
3. otherwise `insufficientEvidence`.

If the top score is below 30, abstention is `insufficientEvidence`. If the lead
over the runner-up is less than 10, abstention is `competingSignals`. On a
recommendation, at least one and at most `max(1, limit)` candidates are exposed.

## 2. Lifecycle assessment

A user confirmation, when present, is authoritative and maps directly to the
corresponding lifecycle state. `abandoned` and `obsolete` map to
`abandonedConfirmed` and `obsoleteConfirmed`. No inferred rule may emit either
confirmed state.

Without a confirmation, the first matching rule applies:

1. Explicit input requested: `waitingHuman`.
2. Blocked, usage-limited, or budget-limited observation: `blocked`.
3. Any other direct attention observation: `current`.
4. Non-empty waiting condition: `waitingExternal`.
5. Future snooze: `dormant`; a snooze due within the preceding 30 days:
   `current`.
6. Recently active execution or active goal: `current`.
7. Incomplete history: `uncertain`.
8. Unknown execution or goal state: `uncertain`.
9. Completed execution, or completed goal while execution is neither
   `openSilent` nor `aborted`: `completed`.
10. Paused goal: `dormant`.
11. Any recorded deadline: `current`.
12. A next action on work younger than 30 days: `current`.
13. An opening within the preceding 30 days: `current`.
14. Activity younger than 30 days: `current`.
15. Activity at least 30 days old: `dormant`.

Silence, age, and an aborted turn never infer `obsoleteConfirmed` or
`abandonedConfirmed`. For open-silent or aborted items at least 90 days old,
the evidence records `inactiveNinetyDays`; other work at least 30 days old
records `inactiveThirtyDays`.

## 3. Corpus and exact-output contract

The corpus generator is a Python standard-library program and does not import,
invoke, parse, or copy Swift source. It implements this written specification
as a separate oracle. The Swift benchmark runner must consume the frozen JSON
corpus and compare all of the following:

- recommendation or abstention;
- ranked candidate identifiers, scores, reason-code order, weights, and
  evidence times;
- deferral identifier, reason, and due time;
- lifecycle state, evidence-code order, evidence times and ages;
- the prohibition on inferred confirmed-obsolete and confirmed-abandoned
  states.

The same project produced the specification, oracle, implementation, and
fixtures. The resulting evaluation is therefore implementation-independent at
the language boundary but not externally independent validation.

## 4. Finite pass and fail rules

The frozen-corpus conformance claim passes only if every fixture matches exactly
and no process crashes or times out. Determinism passes only if 100 repetitions
of every fixture produce byte-identical canonical outputs. The content-free
output check passes only if no seeded sentinel from title, path, checkpoint,
next-action, or waiting text appears in serialized policy output.

Performance results are descriptive for the measured machine. They report the
median, p95, interquartile range, and maximum latency after five warm-up runs and
30 measured repetitions at 10, 50, 200, and 1,000 inputs. No human-productivity
or cross-machine inference is permitted.

## 5. Frozen omissions

Version 1.0 deliberately omits the ordinary dashboard reader, the separate
Wingman evidence-tree reader, token proxies, graph construction, remote model
quality, and GUI behavior. Those require separate specifications and evidence
packages. They must not be described as having passed this benchmark.
