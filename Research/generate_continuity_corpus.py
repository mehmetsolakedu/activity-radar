#!/usr/bin/env python3
"""Generate an implementation-independent AiWingman continuity corpus.

This standard-library oracle follows Research/protocol/SPECIFICATION_V1.md. It
does not read or invoke the Swift implementation. The generated expected values
are intended to be frozen before the Swift benchmark is executed.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from copy import deepcopy
from pathlib import Path
from typing import Any


DAY = 86_400
NOW = 2_000_000_000
MINIMUM_SCORE = 30
MINIMUM_LEAD = 10
SENTINELS = [
    "PRIVATE_TITLE_SENTINEL_7GQ3",
    "PRIVATE_PATH_SENTINEL_9MK2",
    "PRIVATE_CHECKPOINT_SENTINEL_4VV8",
    "PRIVATE_NEXT_ACTION_SENTINEL_2RX6",
    "PRIVATE_WAITING_SENTINEL_8JP1",
]


def has_text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def item(
    identifier: str,
    *,
    activity_age_days: float = 0,
    execution: str = "idle",
    attention: str | None = None,
    goal: str | None = None,
    history_complete: bool = True,
    title: str | None = None,
    cwd: str = "/synthetic/work",
    checkpoint: str = "Synthetic checkpoint",
) -> dict[str, Any]:
    activity_at = NOW - int(activity_age_days * DAY)
    return {
        "id": identifier,
        "title": title or f"Synthetic {identifier}",
        "projectName": "Synthetic corpus",
        "cwd": cwd,
        "rolloutPath": f"/synthetic/{identifier}.jsonl",
        "executionState": execution,
        "attentionReason": attention,
        "goalStatus": goal,
        "goalUpdatedAt": activity_at if goal is not None else None,
        "createdAt": activity_at - 60,
        "startedAt": activity_at,
        "updatedAt": activity_at,
        "lastActivityAt": activity_at,
        "lastUserMessageAt": activity_at,
        "lastMeaningfulAgentAt": None,
        "lastFinalAnswerAt": activity_at if attention == "newSinceView" else None,
        "lastTerminalAt": activity_at if execution in {"completed", "aborted"} else None,
        "lastTerminalState": execution if execution in {"completed", "aborted"} else None,
        "lastViewedAt": None,
        "checkpoint": checkpoint,
        "historyComplete": history_complete,
    }


def metadata(**overrides: Any) -> dict[str, Any]:
    base = {
        "importance": None,
        "deadline": None,
        "nextAction": None,
        "waitingOn": None,
        "snoozeUntil": None,
    }
    base.update(overrides)
    return base


def triage_input(
    task: dict[str, Any],
    *,
    meta: dict[str, Any] | None = None,
    last_opened_at: int | None = None,
) -> dict[str, Any]:
    return {
        "item": task,
        "metadata": meta or metadata(),
        "lastOpenedAt": last_opened_at,
    }


def timeline_activity_at(task: dict[str, Any]) -> int:
    values = [
        task.get("lastUserMessageAt"),
        task.get("lastMeaningfulAgentAt"),
        task.get("lastFinalAnswerAt"),
        task.get("lastTerminalAt"),
    ]
    present = [value for value in values if value is not None]
    return max(present) if present else task["updatedAt"]


def deferral(entry: dict[str, Any], now: int) -> dict[str, Any] | None:
    task = entry["item"]
    meta = entry["metadata"]
    snooze = meta.get("snoozeUntil")
    deadline = meta.get("deadline")
    has_direct_attention = task.get("attentionReason") is not None
    snooze_is_due = snooze is not None and snooze <= now
    deadline_is_urgent = deadline is not None and deadline <= now + 3 * DAY

    if snooze is not None and snooze > now:
        return {"activityID": task["id"], "reason": "snoozed", "until": snooze}
    if has_text(meta.get("waitingOn")):
        return {"activityID": task["id"], "reason": "waitingOnExternal", "until": None}

    goal_looks_complete = (
        task.get("goalStatus") == "complete"
        and task["executionState"] not in {"openSilent", "aborted", "recentlyActive"}
    )
    if (
        task["executionState"] == "completed" or goal_looks_complete
    ) and not has_direct_attention and not deadline_is_urgent and not snooze_is_due:
        return {"activityID": task["id"], "reason": "terminal", "until": None}
    return None


def triage_reasons(entry: dict[str, Any], now: int) -> list[dict[str, Any]]:
    task = entry["item"]
    meta = entry["metadata"]
    result: list[dict[str, Any]] = []

    attention_map = {
        "explicitInput": ("explicitInput", 100, task.get("lastActivityAt")),
        "goalBlocked": ("goalBlocked", 90, task.get("goalUpdatedAt")),
        "newSinceView": ("unseenResult", 80, task.get("lastFinalAnswerAt")),
        "usageLimited": ("usageLimited", 70, task.get("goalUpdatedAt")),
        "budgetLimited": ("budgetLimited", 70, task.get("goalUpdatedAt")),
    }
    attention = task.get("attentionReason")
    if attention in attention_map:
        code, weight, observed = attention_map[attention]
        result.append({"code": code, "weight": weight, "evidenceAt": observed})

    deadline = meta.get("deadline")
    if deadline is not None:
        remaining = deadline - now
        if remaining <= 0:
            result.append({"code": "deadlineOverdue", "weight": 65, "evidenceAt": deadline})
        elif remaining <= DAY:
            result.append({"code": "deadlineWithinDay", "weight": 55, "evidenceAt": deadline})
        elif remaining <= 3 * DAY:
            result.append({"code": "deadlineWithinThreeDays", "weight": 40, "evidenceAt": deadline})
        elif remaining <= 7 * DAY:
            result.append({"code": "deadlineWithinWeek", "weight": 20, "evidenceAt": deadline})

    snooze = meta.get("snoozeUntil")
    opened = entry.get("lastOpenedAt")
    if snooze is not None and snooze <= now and (opened is None or opened < snooze):
        result.append({"code": "plannedReturnDue", "weight": 45, "evidenceAt": snooze})

    importance = meta.get("importance")
    if importance == "critical":
        result.append({"code": "criticalImportance", "weight": 30, "evidenceAt": None})
    elif importance == "high":
        result.append({"code": "highImportance", "weight": 20, "evidenceAt": None})
    elif importance == "low":
        result.append({"code": "lowImportance", "weight": -10, "evidenceAt": None})

    if has_text(meta.get("nextAction")):
        result.append({"code": "nextActionRecorded", "weight": 10, "evidenceAt": None})
    else:
        age = now - timeline_activity_at(task)
        if age >= 7 * DAY:
            result.append(
                {
                    "code": "agingWithoutPlan",
                    "weight": 18 if age >= 30 * DAY else 12,
                    "evidenceAt": timeline_activity_at(task),
                }
            )

    if task["executionState"] == "recentlyActive":
        result.append({"code": "recentlyActive", "weight": 8, "evidenceAt": task.get("lastActivityAt")})
    if opened is not None and 0 <= now - opened <= 15 * 60:
        result.append({"code": "recentlyOpened", "weight": -15, "evidenceAt": opened})
    return result


def triage_oracle(inputs: list[dict[str, Any]], now: int, limit: int) -> dict[str, Any]:
    candidates: list[dict[str, Any]] = []
    deferred: list[dict[str, Any]] = []
    incomplete = False
    complete = False

    for entry in inputs:
        held = deferral(entry, now)
        if held is not None:
            deferred.append(held)
            continue
        if not entry["item"]["historyComplete"]:
            incomplete = True
            continue
        complete = True
        reasons = triage_reasons(entry, now)
        if not reasons:
            continue
        candidates.append(
            {
                "activityID": entry["item"]["id"],
                "score": sum(reason["weight"] for reason in reasons),
                "reasons": reasons,
            }
        )

    candidates.sort(key=lambda candidate: (-candidate["score"], candidate["activityID"]))
    deferred.sort(key=lambda held: held["activityID"])
    if not candidates:
        if incomplete:
            reason = "incompleteHistory"
        elif deferred and not complete:
            reason = "noEligibleWork"
        else:
            reason = "insufficientEvidence"
        return {
            "rankedCandidates": [],
            "recommendedActivityID": None,
            "abstentionReason": reason,
            "deferred": deferred,
        }
    if candidates[0]["score"] < MINIMUM_SCORE:
        return {
            "rankedCandidates": [],
            "recommendedActivityID": None,
            "abstentionReason": "insufficientEvidence",
            "deferred": deferred,
        }
    if len(candidates) > 1 and candidates[0]["score"] - candidates[1]["score"] < MINIMUM_LEAD:
        return {
            "rankedCandidates": [],
            "recommendedActivityID": None,
            "abstentionReason": "competingSignals",
            "deferred": deferred,
        }
    return {
        "rankedCandidates": candidates[: max(1, limit)],
        "recommendedActivityID": candidates[0]["activityID"],
        "abstentionReason": None,
        "deferred": deferred,
    }


CONFIRMED_STATE_MAP = {
    "current": "current",
    "waitingHuman": "waitingHuman",
    "waitingExternal": "waitingExternal",
    "blocked": "blocked",
    "completed": "completed",
    "completedElsewhere": "completedElsewhere",
    "superseded": "superseded",
    "abandoned": "abandonedConfirmed",
    "obsolete": "obsoleteConfirmed",
    "duplicate": "duplicate",
}


def evidence(code: str, observed: int | None = None, age: int | None = None) -> dict[str, Any]:
    return {"code": code, "observedAt": observed, "ageInDays": age}


def lifecycle_oracle(case: dict[str, Any]) -> dict[str, Any]:
    task = case["item"]
    meta = case["metadata"]
    opened = case.get("lastOpenedAt")
    confirmation = case.get("confirmation")
    now = case["now"]

    if confirmation is not None:
        return {
            "activityID": task["id"],
            "state": CONFIRMED_STATE_MAP[confirmation["state"]],
            "evidence": [evidence("userConfirmed", confirmation["confirmedAt"])],
            "requiresUserConfirmation": False,
        }

    activity_at = timeline_activity_at(task)
    age_seconds = max(0, now - activity_at)
    age_days = int(age_seconds / DAY)
    found: list[dict[str, Any]] = []
    attention = task.get("attentionReason")
    goal = task.get("goalStatus")
    execution = task["executionState"]

    if attention == "explicitInput":
        return lifecycle_result(task, "waitingHuman", [evidence("explicitInput", task.get("lastActivityAt"))])
    if attention is not None:
        found.append(evidence("attentionRequired", task.get("lastActivityAt")))
    if goal == "blocked" or attention == "goalBlocked":
        found.append(evidence("blockedGoal", task.get("goalUpdatedAt")))
        return lifecycle_result(task, "blocked", found)
    if goal in {"usageLimited", "budgetLimited"} or attention in {"usageLimited", "budgetLimited"}:
        found.append(evidence("limitedGoal", task.get("goalUpdatedAt")))
        return lifecycle_result(task, "blocked", found)
    if attention is not None:
        return lifecycle_result(task, "current", found)

    if has_text(meta.get("waitingOn")):
        return lifecycle_result(task, "waitingExternal", [evidence("waitingOnRecorded")])
    snooze = meta.get("snoozeUntil")
    if snooze is not None:
        found.append(evidence("snoozedUntil", snooze))
        if snooze > now:
            return lifecycle_result(task, "dormant", found)
        if now - snooze <= 30 * DAY:
            return lifecycle_result(task, "current", found)

    if execution == "recentlyActive":
        found.append(evidence("recentlyActive", task.get("lastActivityAt")))
        return lifecycle_result(task, "current", found)
    if goal == "active":
        found.append(evidence("activeGoal", task.get("goalUpdatedAt")))
        return lifecycle_result(task, "current", found)
    if not task["historyComplete"]:
        found.append(evidence("historyIncomplete"))
        return lifecycle_result(task, "uncertain", found)
    if execution == "unknown" or goal == "unknown":
        found.append(evidence("unknownState", activity_at))
        return lifecycle_result(task, "uncertain", found)

    goal_looks_complete = goal == "complete" and execution not in {"openSilent", "aborted"}
    if execution == "completed" or goal_looks_complete:
        if execution == "completed":
            found.append(evidence("completedExecution", task.get("lastTerminalAt")))
        else:
            found.append(evidence("completedGoal", task.get("goalUpdatedAt")))
        return lifecycle_result(task, "completed", found)
    if goal == "paused":
        found.append(evidence("pausedGoal", task.get("goalUpdatedAt")))
        return lifecycle_result(task, "dormant", found)

    if has_text(meta.get("nextAction")):
        found.append(evidence("nextActionRecorded"))
    if meta.get("deadline") is not None:
        found.append(evidence("deadlineOutstanding", meta["deadline"]))
        return lifecycle_result(task, "current", found)
    if has_text(meta.get("nextAction")) and age_seconds < 30 * DAY:
        return lifecycle_result(task, "current", found)
    if opened is not None and 0 <= now - opened < 30 * DAY:
        found.append(evidence("recentlyOpened", opened))
        return lifecycle_result(task, "current", found)
    if age_seconds < 30 * DAY:
        found.append(evidence("recentActivity", activity_at, age_days))
        return lifecycle_result(task, "current", found)
    if age_seconds >= 90 * DAY and execution in {"openSilent", "aborted"}:
        if execution == "aborted":
            found.append(evidence("abortedExecution", task.get("lastTerminalAt")))
        found.append(evidence("inactiveNinetyDays", activity_at, age_days))
        return lifecycle_result(task, "dormant", found)
    if age_seconds >= 30 * DAY:
        found.append(evidence("inactiveThirtyDays", activity_at, age_days))
        return lifecycle_result(task, "dormant", found)
    found.append(evidence("unknownState", activity_at))
    return lifecycle_result(task, "uncertain", found)


def lifecycle_result(task: dict[str, Any], state: str, found: list[dict[str, Any]]) -> dict[str, Any]:
    return {
        "activityID": task["id"],
        "state": state,
        "evidence": found,
        "requiresUserConfirmation": False,
    }


def add_triage(
    fixtures: list[dict[str, Any]],
    name: str,
    category: str,
    inputs: list[dict[str, Any]],
    *,
    limit: int = 3,
) -> None:
    case = {
        "id": f"T{len([f for f in fixtures if f['kind'] == 'triage']) + 1:03d}-{name}",
        "kind": "triage",
        "category": category,
        "now": NOW,
        "limit": limit,
        "inputs": inputs,
    }
    case["expected"] = triage_oracle(inputs, NOW, limit)
    fixtures.append(case)


def add_lifecycle(
    fixtures: list[dict[str, Any]],
    name: str,
    category: str,
    task: dict[str, Any],
    *,
    meta: dict[str, Any] | None = None,
    last_opened_at: int | None = None,
    confirmation: dict[str, Any] | None = None,
) -> None:
    case = {
        "id": f"L{len([f for f in fixtures if f['kind'] == 'lifecycle']) + 1:03d}-{name}",
        "kind": "lifecycle",
        "category": category,
        "now": NOW,
        "item": task,
        "metadata": meta or metadata(),
        "lastOpenedAt": last_opened_at,
        "confirmation": confirmation,
    }
    case["expected"] = lifecycle_oracle(case)
    fixtures.append(case)


def build_fixtures() -> list[dict[str, Any]]:
    fixtures: list[dict[str, Any]] = []

    for attention in ["explicitInput", "goalBlocked", "newSinceView", "usageLimited", "budgetLimited"]:
        add_triage(fixtures, f"attention-{attention}", "direct-attention", [triage_input(item(attention, attention=attention))])

    deadline_offsets = [(-DAY, "overdue"), (0, "due-now"), (DAY, "within-day"), (3 * DAY, "within-three"), (7 * DAY, "within-week"), (7 * DAY + 1, "outside-week")]
    for offset, label in deadline_offsets:
        add_triage(fixtures, f"deadline-{label}", "deadline", [triage_input(item(label), meta=metadata(deadline=NOW + offset))])

    importance_cases = [
        ("critical", None), ("high", None), ("low", None), ("normal", None),
        ("critical", "Resume"), ("high", "Resume"), ("low", "Resume"), (None, "Resume"),
    ]
    for index, (importance, next_action) in enumerate(importance_cases, 1):
        add_triage(fixtures, f"importance-{index}", "metadata-score", [triage_input(item(f"importance-{index}"), meta=metadata(importance=importance, nextAction=next_action))])

    for age in [6.99, 7, 29.99, 30, 120]:
        add_triage(fixtures, f"aging-{str(age).replace('.', '-')}", "aging", [triage_input(item(f"aging-{age}", activity_age_days=age))])

    snooze_cases = [
        (NOW + 60, None, "future"),
        (NOW, None, "due-now"),
        (NOW - 60, None, "overdue-unopened"),
        (NOW - 60, NOW - 61, "opened-before"),
        (NOW - 60, NOW - 60, "opened-at"),
        (NOW - 60, NOW, "opened-after"),
    ]
    for due, opened, label in snooze_cases:
        add_triage(fixtures, f"snooze-{label}", "snooze", [triage_input(item(f"snooze-{label}"), meta=metadata(importance="critical", nextAction="Resume", snoozeUntil=due), last_opened_at=opened)])

    for index, attention in enumerate([None, "explicitInput", "newSinceView"]):
        add_triage(fixtures, f"future-snooze-precedence-{index}", "deferral-precedence", [triage_input(item(f"future-{index}", attention=attention), meta=metadata(deadline=NOW - DAY, snoozeUntil=NOW + DAY))])
    for index, attention in enumerate([None, "explicitInput", "goalBlocked"]):
        add_triage(fixtures, f"waiting-precedence-{index}", "deferral-precedence", [triage_input(item(f"waiting-{index}", attention=attention), meta=metadata(deadline=NOW - DAY, waitingOn="External"))])

    terminal_cases = [
        ("completed", None, metadata(), "plain-completed"),
        ("idle", "complete", metadata(), "goal-complete"),
        ("openSilent", "complete", metadata(), "open-complete"),
        ("aborted", "complete", metadata(), "aborted-complete"),
        ("recentlyActive", "complete", metadata(), "active-complete"),
        ("completed", None, metadata(deadline=NOW + 3 * DAY), "urgent-completed"),
        ("completed", None, metadata(snoozeUntil=NOW), "due-snooze-completed"),
        ("completed", None, metadata(deadline=NOW + 3 * DAY + 1), "nonurgent-completed"),
    ]
    for execution, goal, meta, label in terminal_cases:
        add_triage(fixtures, f"terminal-{label}", "terminal", [triage_input(item(label, execution=execution, goal=goal), meta=meta)])

    add_triage(fixtures, "incomplete-only", "partial-history", [triage_input(item("partial", attention="explicitInput", history_complete=False))])
    add_triage(fixtures, "incomplete-deferred", "partial-history", [triage_input(item("partial", history_complete=False), meta=metadata(snoozeUntil=NOW + DAY))])
    add_triage(fixtures, "mixed-complete-wins", "partial-history", [triage_input(item("partial", attention="explicitInput", history_complete=False)), triage_input(item("complete", attention="newSinceView"))])
    add_triage(fixtures, "mixed-weak-complete", "partial-history", [triage_input(item("partial", history_complete=False)), triage_input(item("weak"), meta=metadata(importance="high"))])
    add_triage(fixtures, "mixed-terminal-and-partial", "partial-history", [triage_input(item("terminal", execution="completed")), triage_input(item("partial", history_complete=False))])

    competition_cases = [
        (100, 100, "tie"), (100, 92, "lead-eight"), (100, 90, "lead-ten"),
        (80, 70, "different-ten"), (70, 65, "different-five"), (40, 30, "low-ten"),
    ]
    score_to_input = {
        100: lambda identifier: triage_input(item(identifier, attention="explicitInput")),
        92: lambda identifier: triage_input(item(identifier, activity_age_days=7, attention="newSinceView")),
        90: lambda identifier: triage_input(item(identifier, attention="goalBlocked")),
        80: lambda identifier: triage_input(item(identifier, attention="newSinceView")),
        70: lambda identifier: triage_input(item(identifier, attention="usageLimited")),
        65: lambda identifier: triage_input(item(identifier), meta=metadata(deadline=NOW)),
        40: lambda identifier: triage_input(item(identifier), meta=metadata(deadline=NOW + 3 * DAY)),
        30: lambda identifier: triage_input(item(identifier), meta=metadata(importance="critical")),
    }
    for first_score, second_score, label in competition_cases:
        add_triage(fixtures, f"competition-{label}", "competition", [score_to_input[second_score]("b"), score_to_input[first_score]("a")])

    ranked_inputs = [
        triage_input(item("a", attention="explicitInput")),
        triage_input(item("b", attention="newSinceView")),
        triage_input(item("c", attention="usageLimited")),
        triage_input(item("d"), meta=metadata(deadline=NOW)),
    ]
    for limit in [-3, 0, 1, 2, 3, 10]:
        add_triage(fixtures, f"limit-{str(limit).replace('-', 'neg')}", "visibility", deepcopy(ranked_inputs), limit=limit)

    for index in range(8):
        inputs = deepcopy(ranked_inputs)
        inputs = inputs[index % 4 :] + inputs[: index % 4]
        add_triage(fixtures, f"permutation-{index}", "permutation", inputs)

    text_variants = [
        (SENTINELS[0], "/synthetic/work", "Synthetic checkpoint", "  Resume  ", None),
        ("Unicode ıİşŞğĞé中🚀", f"/x/{SENTINELS[1]}", "Synthetic checkpoint", "Resume", None),
        ("Synthetic", "/synthetic/work", SENTINELS[2], f"{SENTINELS[3]}", None),
        ("Synthetic", "/synthetic/work", "Synthetic checkpoint", "\n\t", None),
        ("Synthetic", "/synthetic/work", "Synthetic checkpoint", "Resume", f"{SENTINELS[4]}"),
        ("x" * 4096, "/" + "y" * 4096, "z" * 4096, "n" * 4096, None),
    ]
    for index, (title, cwd, checkpoint, next_action, waiting) in enumerate(text_variants, 1):
        add_triage(fixtures, f"text-{index}", "content-neutrality", [triage_input(item(f"text-{index}", title=title, cwd=cwd, checkpoint=checkpoint), meta=metadata(importance="critical", nextAction=next_action, waitingOn=waiting))])

    for confirmed in CONFIRMED_STATE_MAP:
        add_lifecycle(fixtures, f"confirmed-{confirmed}", "confirmation", item(f"confirmed-{confirmed}"), confirmation={"state": confirmed, "confirmedAt": NOW - 60})

    attention_goal_cases = [
        ("explicitInput", None, "explicit"),
        ("goalBlocked", None, "attention-blocked"),
        (None, "blocked", "goal-blocked"),
        ("usageLimited", None, "attention-usage"),
        ("budgetLimited", None, "attention-budget"),
        (None, "usageLimited", "goal-usage"),
        (None, "budgetLimited", "goal-budget"),
        ("newSinceView", None, "unseen"),
    ]
    for attention, goal, label in attention_goal_cases:
        add_lifecycle(fixtures, label, "attention", item(label, attention=attention, goal=goal))

    lifecycle_metadata_cases = [
        (metadata(waitingOn="External"), None, "waiting"),
        (metadata(snoozeUntil=NOW + DAY), None, "future-snooze"),
        (metadata(snoozeUntil=NOW), None, "due-snooze"),
        (metadata(snoozeUntil=NOW - 30 * DAY), None, "thirty-day-snooze"),
        (metadata(snoozeUntil=NOW - 30 * DAY - 1), None, "expired-snooze"),
        (metadata(deadline=NOW + 365 * DAY), None, "far-deadline"),
        (metadata(deadline=NOW - 365 * DAY), None, "overdue-deadline"),
        (metadata(nextAction="Resume"), None, "next-action"),
    ]
    for meta, opened, label in lifecycle_metadata_cases:
        add_lifecycle(fixtures, label, "metadata", item(label, activity_age_days=40), meta=meta, last_opened_at=opened)

    history_cases = [
        (False, "idle", None, "partial-idle"),
        (False, "unknown", None, "partial-unknown"),
        (True, "unknown", None, "unknown-execution"),
        (True, "idle", "unknown", "unknown-goal"),
        (False, "recentlyActive", None, "partial-active"),
        (False, "idle", "active", "partial-active-goal"),
    ]
    for complete, execution, goal, label in history_cases:
        add_lifecycle(fixtures, label, "history-precedence", item(label, execution=execution, goal=goal, history_complete=complete))

    execution_goal_cases = [
        ("recentlyActive", None, "recently-active"),
        ("idle", "active", "active-goal"),
        ("completed", None, "completed-execution"),
        ("idle", "complete", "completed-goal"),
        ("openSilent", "complete", "open-complete"),
        ("aborted", "complete", "aborted-complete"),
        ("idle", "paused", "paused"),
        ("completed", "paused", "completed-before-paused"),
    ]
    for execution, goal, label in execution_goal_cases:
        add_lifecycle(fixtures, label, "execution-goal", item(label, activity_age_days=40, execution=execution, goal=goal))

    age_cases = [0, 29.99, 30, 31, 89.99, 90, 120]
    for execution in ["idle", "openSilent", "aborted"]:
        for age in age_cases:
            add_lifecycle(fixtures, f"age-{execution}-{str(age).replace('.', '-')}", "age", item(f"age-{execution}-{age}", activity_age_days=age, execution=execution))

    opened_cases = [NOW + 1, NOW, NOW - 1, NOW - 30 * DAY + 1, NOW - 30 * DAY, NOW - 30 * DAY - 1]
    for index, opened in enumerate(opened_cases, 1):
        add_lifecycle(fixtures, f"opened-{index}", "opening-boundary", item(f"opened-{index}", activity_age_days=40), last_opened_at=opened)

    precedence_cases = [
        (item("p1", attention="explicitInput", history_complete=False), metadata(waitingOn="External"), "explicit-before-waiting"),
        (item("p2", attention="goalBlocked", execution="completed"), metadata(), "blocked-before-complete"),
        (item("p3", execution="recentlyActive", history_complete=False), metadata(), "active-before-partial"),
        (item("p4", goal="active", history_complete=False), metadata(), "goal-active-before-partial"),
        (item("p5", execution="unknown", history_complete=False), metadata(), "partial-before-unknown"),
        (item("p6", execution="completed"), metadata(waitingOn="External"), "waiting-before-complete"),
        (item("p7", execution="completed"), metadata(snoozeUntil=NOW + DAY), "snooze-before-complete"),
        (item("p8", goal="paused"), metadata(deadline=NOW + DAY), "paused-before-deadline"),
    ]
    for task, meta, label in precedence_cases:
        add_lifecycle(fixtures, label, "precedence", task, meta=meta)

    for index, sentinel in enumerate(SENTINELS, 1):
        add_lifecycle(
            fixtures,
            f"sentinel-{index}",
            "content-neutrality",
            item(f"sentinel-{index}", title=sentinel if index == 1 else "Synthetic", cwd=f"/x/{sentinel}" if index == 2 else "/synthetic", checkpoint=sentinel if index == 3 else "Synthetic", activity_age_days=40),
            meta=metadata(nextAction=sentinel if index == 4 else None, waitingOn=sentinel if index == 5 else None),
        )

    return fixtures


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--spec", type=Path, required=True)
    args = parser.parse_args()

    specification_hash = hashlib.sha256(args.spec.read_bytes()).hexdigest()
    fixtures = build_fixtures()
    triage_count = sum(fixture["kind"] == "triage" for fixture in fixtures)
    lifecycle_count = sum(fixture["kind"] == "lifecycle" for fixture in fixtures)
    if triage_count < 72 or lifecycle_count < 72:
        raise SystemExit(f"corpus is too small: triage={triage_count}, lifecycle={lifecycle_count}")
    identifiers = [fixture["id"] for fixture in fixtures]
    if len(identifiers) != len(set(identifiers)):
        raise SystemExit("fixture identifiers are not unique")

    document = {
        "schemaVersion": "1.0",
        "specificationSha256": specification_hash,
        "generatedAt": "2026-08-23T00:00:00Z",
        "oracleImplementation": "Research/generate_continuity_corpus.py",
        "independenceBoundary": "Separate Python oracle; same project authors; not external validation.",
        "sentinels": SENTINELS,
        "fixtureCounts": {"triage": triage_count, "lifecycle": lifecycle_count, "total": len(fixtures)},
        "fixtures": fixtures,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(document, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    digest = hashlib.sha256(args.output.read_bytes()).hexdigest()
    print(json.dumps({"output": str(args.output), "sha256": digest, "counts": document["fixtureCounts"]}, sort_keys=True))


if __name__ == "__main__":
    main()
