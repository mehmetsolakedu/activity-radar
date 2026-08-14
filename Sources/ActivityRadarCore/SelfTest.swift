import Foundation
import SQLite3

public enum ActivityRadarSelfTests {
    public static func run() throws -> [String] {
        var passed: [String] = []

        try checkTurnLifecycle()
        passed.append("turn lifecycle and final answer")

        try checkConcurrentTurns()
        passed.append("concurrent turns")

        try checkPendingInputResolution()
        passed.append("pending input resolution")

        try checkAbortedTurn()
        passed.append("aborted turn")

        try checkGoalStatusSemantics()
        passed.append("goal status signal semantics")

        try checkPersistentNewResultBaseline()
        passed.append("persistent new-result baseline")

        try checkLifecycleSuggestions()
        passed.append("conservative lifecycle suggestions")

        try checkContinuityTriage()
        passed.append("explainable continuity triage")

        try checkContinuityAbstention()
        passed.append("triage abstention and deferral")

        try checkContinuityLifecycleSafety()
        passed.append("confirmation-gated lifecycle")

        try checkMarkdownCleanupPreservesTechnicalText()
        passed.append("Markdown cleanup preserves technical text")

        try checkDeepLink()
        passed.append("Codex deep-link contract")

        try checkReadOnlySQLite()
        passed.append("SQLite read-only enforcement")

        try checkPublicErrorsHideHomeDirectory()
        passed.append("public errors hide local home paths")

        return passed
    }

    private static func checkTurnLifecycle() throws {
        var reducer = RolloutReducer()
        reducer.consume(line: data(#"{"timestamp":"2026-07-27T10:00:00.000Z","type":"event_msg","payload":{"type":"task_started","turn_id":"turn-1"}}"#))
        reducer.consume(line: data(#"{"timestamp":"2026-07-27T10:00:05.000Z","type":"event_msg","payload":{"type":"agent_message","phase":"final_answer","message":"Görev tamamlandı."}}"#))

        try require(reducer.summary.openTurns.count == 1, "open turn was not retained")
        try require(reducer.summary.checkpoint == "Görev tamamlandı.", "checkpoint was not reduced")
        try require(reducer.summary.lastFinalAnswerAt != nil, "final-answer timestamp was not recorded")

        reducer.consume(line: data(#"{"timestamp":"2026-07-27T10:00:06.000Z","type":"event_msg","payload":{"type":"task_complete","turn_id":"turn-1"}}"#))
        try require(reducer.summary.openTurns.isEmpty, "completed turn remained open")
        try require(reducer.summary.lastTerminalState == .completed, "completed state was not recorded")
    }

    private static func checkConcurrentTurns() throws {
        var reducer = RolloutReducer()
        reducer.consume(line: data(#"{"timestamp":"2026-07-27T10:00:00.000Z","type":"event_msg","payload":{"type":"task_started","turn_id":"turn-1"}}"#))
        reducer.consume(line: data(#"{"timestamp":"2026-07-27T10:00:01.000Z","type":"event_msg","payload":{"type":"task_started","turn_id":"turn-2"}}"#))
        reducer.consume(line: data(#"{"timestamp":"2026-07-27T10:00:02.000Z","type":"event_msg","payload":{"type":"task_complete","turn_id":"turn-1"}}"#))
        try require(Set(reducer.summary.openTurns.keys) == Set(["turn-2"]), "concurrent turn accounting failed")
    }

    private static func checkPendingInputResolution() throws {
        var reducer = RolloutReducer()
        reducer.consume(line: data(#"{"timestamp":"2026-07-27T10:00:00.000Z","type":"response_item","payload":{"type":"function_call","name":"request_user_input","call_id":"call-1"}}"#))
        reducer.consume(line: data(#"{"timestamp":"2026-07-27T10:00:01.000Z","type":"response_item","payload":{"type":"function_call_output","call_id":"other"}}"#))
        try require(reducer.summary.pendingInputCallIDs == Set(["call-1"]), "unrelated output cleared pending input")

        reducer.consume(line: data(#"{"timestamp":"2026-07-27T10:00:02.000Z","type":"response_item","payload":{"type":"function_call_output","call_id":"call-1"}}"#))
        try require(reducer.summary.pendingInputCallIDs.isEmpty, "matching output did not clear pending input")
    }

    private static func checkAbortedTurn() throws {
        var reducer = RolloutReducer()
        reducer.consume(line: data(#"{"timestamp":"2026-07-27T10:00:00.000Z","type":"event_msg","payload":{"type":"task_started","turn_id":"turn-1"}}"#))
        reducer.consume(line: data(#"{"timestamp":"2026-07-27T10:00:03.000Z","type":"event_msg","payload":{"type":"turn_aborted","turn_id":"turn-1"}}"#))
        try require(reducer.summary.openTurns.isEmpty, "aborted turn remained open")
        try require(reducer.summary.lastTerminalState == .aborted, "aborted state was not recorded")
    }

    private static func checkGoalStatusSemantics() throws {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        var summary = RolloutSummary()
        summary.lastActivityAt = now.addingTimeInterval(-5)
        let viewedAt = now.addingTimeInterval(-60)

        let parkedPause = ActivityAttentionPolicy.reason(
            summary: summary,
            goalStatus: .paused,
            viewedAt: viewedAt,
            unviewedResultsAfter: nil,
            now: now
        )
        try require(parkedPause == nil, "parked goal was promoted to an attention signal")

        let durableBudgetLimit = ActivityAttentionPolicy.reason(
            summary: summary,
            goalStatus: .budgetLimited,
            viewedAt: viewedAt,
            unviewedResultsAfter: nil,
            now: now
        )
        try require(durableBudgetLimit == .budgetLimited, "budget limit was not surfaced")
    }

    private static func checkPersistentNewResultBaseline() throws {
        let baseline = Date(timeIntervalSince1970: 2_000_000_000)
        let now = baseline.addingTimeInterval(7 * 24 * 60 * 60)
        var summary = RolloutSummary()
        summary.lastFinalAnswerAt = baseline.addingTimeInterval(30)

        let reason = ActivityAttentionPolicy.reason(
            summary: summary,
            goalStatus: nil,
            viewedAt: nil,
            unviewedResultsAfter: baseline,
            now: now
        )
        try require(reason == .newSinceView, "unviewed result expired despite the persisted baseline")
    }

    private static func checkLifecycleSuggestions() throws {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let old = now.addingTimeInterval(-31 * 24 * 60 * 60)
        let veryOld = now.addingTimeInterval(-91 * 24 * 60 * 60)

        let silent = lifecycleFixture(
            executionState: .openSilent,
            goalStatus: nil,
            activityAt: old
        )
        try require(
            ActivityLifecyclePolicy.suggestion(for: silent, now: now) == .stale,
            "old open work was not kept neutral"
        )
        try require(
            ActivityLifecyclePolicy.suggestion(
                for: silent,
                lastOpenedAt: now.addingTimeInterval(-60),
                now: now
            ) == nil,
            "last-opened work was labeled stale"
        )
        try require(
            ActivityLifecyclePolicy.suggestion(
                for: silent,
                lastOpenedAt: now.addingTimeInterval(-31 * 24 * 60 * 60),
                now: now
            ) == .stale,
            "old last-opened timestamp suppressed lifecycle suggestions forever"
        )

        let protected = lifecycleFixture(
            executionState: .openSilent,
            attentionReason: .goalBlocked,
            goalStatus: .blocked,
            activityAt: old
        )
        try require(
            ActivityLifecyclePolicy.suggestion(for: protected, now: now) == nil,
            "attention work was labeled stale"
        )

        let parked = lifecycleFixture(
            executionState: .idle,
            goalStatus: .paused,
            activityAt: veryOld
        )
        try require(
            ActivityLifecyclePolicy.suggestion(for: parked, now: now) == .longParked,
            "long-paused work was not kept distinct from abandonment"
        )

        let incomplete = lifecycleFixture(
            executionState: .aborted,
            goalStatus: nil,
            activityAt: old,
            historyComplete: false
        )
        try require(
            ActivityLifecyclePolicy.suggestion(for: incomplete, now: now) == nil,
            "partial history produced an aggressive lifecycle label"
        )

        let unknownGoal = lifecycleFixture(
            executionState: .openSilent,
            goalStatus: .unknown,
            activityAt: old
        )
        try require(
            ActivityLifecyclePolicy.suggestion(for: unknownGoal, now: now) == nil,
            "unknown goal state produced a lifecycle label"
        )

        let recentHeartbeat = lifecycleFixture(
            executionState: .openSilent,
            goalStatus: nil,
            activityAt: old,
            lastActivityAt: now.addingTimeInterval(-3 * 60)
        )
        try require(
            ActivityLifecyclePolicy.suggestion(for: recentHeartbeat, now: now) == nil,
            "recent generic activity was labeled abandoned"
        )

        let completedGoalWithOpenTurn = lifecycleFixture(
            executionState: .openSilent,
            goalStatus: .complete,
            activityAt: old
        )
        try require(
            ActivityLifecyclePolicy.suggestion(
                for: completedGoalWithOpenTurn,
                now: now
            ) == .stale,
            "completed goal masked a newer open turn"
        )

        let completedGoalWithAbort = lifecycleFixture(
            executionState: .aborted,
            goalStatus: .complete,
            activityAt: old
        )
        try require(
            ActivityLifecyclePolicy.suggestion(
                for: completedGoalWithAbort,
                now: now
            ) == .unfinishedCandidate,
            "completed goal masked a newer aborted turn"
        )
    }

    private static func lifecycleFixture(
        executionState: ActivityExecutionState,
        attentionReason: ActivityAttentionReason? = nil,
        goalStatus: ActivityGoalStatus?,
        activityAt: Date,
        historyComplete: Bool = true,
        lastActivityAt: Date? = nil
    ) -> ActivityItem {
        ActivityItem(
            id: UUID().uuidString,
            title: "Fixture",
            projectName: "Tests",
            cwd: "/tmp/tests",
            rolloutPath: "/tmp/tests/rollout.jsonl",
            executionState: executionState,
            attentionReason: attentionReason,
            goalStatus: goalStatus,
            goalUpdatedAt: goalStatus == nil ? nil : activityAt,
            createdAt: activityAt.addingTimeInterval(-60),
            startedAt: activityAt,
            updatedAt: activityAt,
            lastActivityAt: lastActivityAt ?? activityAt,
            lastUserMessageAt: activityAt,
            lastMeaningfulAgentAt: nil,
            lastFinalAnswerAt: nil,
            lastTerminalAt: nil,
            lastTerminalState: nil,
            lastViewedAt: nil,
            checkpoint: "Fixture",
            historyComplete: historyComplete
        )
    }

    private static func checkContinuityTriage() throws {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let direct = continuityFixture(
            id: "direct",
            attentionReason: .explicitInput,
            activityAt: now
        )
        let planned = continuityFixture(
            id: "planned",
            activityAt: now.addingTimeInterval(-8 * 24 * 60 * 60)
        )

        let result = WorkContinuityRanker.rank(
            [
                WorkTriageInput(item: planned, metadata: WorkContinuityMetadata(importance: .high)),
                WorkTriageInput(item: direct)
            ],
            now: now
        )

        try require(result.recommendedActivityID == "direct", "direct observed need was not recommended")
        try require(
            result.rankedCandidates.first?.reasons.contains(where: { $0.code == .explicitInput }) == true,
            "triage recommendation did not expose its evidence"
        )

        let snoozeUntil = now.addingTimeInterval(-60)
        let acknowledged = WorkContinuityRanker.rank(
            [
                WorkTriageInput(
                    item: planned,
                    metadata: WorkContinuityMetadata(
                        importance: .critical,
                        nextAction: "Resume",
                        snoozeUntil: snoozeUntil
                    ),
                    lastOpenedAt: now
                )
            ],
            now: now
        )
        try require(
            acknowledged.recommendedActivityID == nil
                && acknowledged.abstentionReason == .insufficientEvidence,
            "opening after a snooze deadline did not acknowledge the due signal"
        )
        try require(
            acknowledged.rankedCandidates.isEmpty,
            "acknowledged snooze leaked a ranked candidate during abstention"
        )
    }

    private static func checkContinuityAbstention() throws {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let first = continuityFixture(id: "a", attentionReason: .goalBlocked, activityAt: now)
        let second = continuityFixture(id: "b", attentionReason: .goalBlocked, activityAt: now)
        let snoozeUntil = now.addingTimeInterval(3_600)
        let snoozed = continuityFixture(
            id: "snoozed",
            attentionReason: .explicitInput,
            activityAt: now
        )

        let result = WorkContinuityRanker.rank(
            [
                WorkTriageInput(item: first),
                WorkTriageInput(item: second),
                WorkTriageInput(
                    item: snoozed,
                    metadata: WorkContinuityMetadata(
                        deadline: now.addingTimeInterval(-60),
                        snoozeUntil: snoozeUntil
                    )
                )
            ],
            now: now
        )

        try require(result.recommendedActivityID == nil, "close competing signals produced a forced recommendation")
        try require(result.abstentionReason == .competingSignals, "competing signals did not state abstention")
        try require(result.rankedCandidates.isEmpty, "abstention exposed ranked candidates")
        try require(
            result.deferred.contains {
                $0.activityID == "snoozed" && $0.reason == .snoozed && $0.until == snoozeUntil
            },
            "future snooze was not respected"
        )

        let waiting = continuityFixture(
            id: "waiting",
            attentionReason: .explicitInput,
            activityAt: now
        )
        let waitingResult = WorkContinuityRanker.rank(
            [
                WorkTriageInput(
                    item: waiting,
                    metadata: WorkContinuityMetadata(
                        deadline: now.addingTimeInterval(-60),
                        waitingOn: "External review"
                    )
                )
            ],
            now: now
        )
        try require(
            waitingResult.abstentionReason == .noEligibleWork
                && waitingResult.rankedCandidates.isEmpty
                && waitingResult.deferred.first?.reason == .waitingOnExternal,
            "waiting-on intent was bypassed by attention or deadline"
        )

        let partial = continuityFixture(
            id: "partial-attention",
            attentionReason: .explicitInput,
            activityAt: now,
            historyComplete: false
        )
        let partialResult = WorkContinuityRanker.rank(
            [WorkTriageInput(item: partial)],
            now: now
        )
        try require(
            partialResult.abstentionReason == .incompleteHistory
                && partialResult.rankedCandidates.isEmpty,
            "incomplete history entered the ranked candidate set"
        )
    }

    private static func checkContinuityLifecycleSafety() throws {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let old = now.addingTimeInterval(-120 * 24 * 60 * 60)
        let item = continuityFixture(
            id: "old-open",
            executionState: .openSilent,
            activityAt: old
        )

        let inferred = WorkContinuityLifecycle.assess(item: item, now: now)
        try require(inferred.state == .dormant, "old open task received a non-neutral lifecycle inference")
        try require(!inferred.requiresUserConfirmation, "neutral dormant state requested high-impact confirmation")

        let aborted = continuityFixture(
            id: "old-aborted",
            executionState: .aborted,
            activityAt: old
        )
        let abortedAssessment = WorkContinuityLifecycle.assess(item: aborted, now: now)
        try require(
            abortedAssessment.state == .dormant && !abortedAssessment.requiresUserConfirmation,
            "old aborted task received abandonment inference"
        )

        let confirmed = WorkContinuityLifecycle.assess(
            item: item,
            confirmation: WorkLifecycleConfirmation(state: .obsolete, confirmedAt: now),
            now: now
        )
        try require(confirmed.state == .obsoleteConfirmed, "explicit obsolete confirmation was not preserved")
        try require(!confirmed.requiresUserConfirmation, "confirmed lifecycle state remained provisional")

        let partial = continuityFixture(
            id: "partial",
            executionState: .openSilent,
            activityAt: old,
            historyComplete: false
        )
        try require(
            WorkContinuityLifecycle.assess(item: partial, now: now).state == .uncertain,
            "partial history did not abstain from lifecycle inference"
        )
    }

    private static func continuityFixture(
        id: String,
        executionState: ActivityExecutionState = .idle,
        attentionReason: ActivityAttentionReason? = nil,
        activityAt: Date,
        historyComplete: Bool = true
    ) -> ActivityItem {
        ActivityItem(
            id: id,
            title: "Continuity fixture",
            projectName: "Self Tests",
            cwd: "/tmp/activity-radar-self-tests",
            rolloutPath: "/tmp/activity-radar-self-tests/rollout.jsonl",
            executionState: executionState,
            attentionReason: attentionReason,
            goalStatus: attentionReason == .goalBlocked ? .blocked : nil,
            goalUpdatedAt: attentionReason == .goalBlocked ? activityAt : nil,
            createdAt: activityAt.addingTimeInterval(-60),
            startedAt: activityAt,
            updatedAt: activityAt,
            lastActivityAt: activityAt,
            lastUserMessageAt: activityAt,
            lastMeaningfulAgentAt: nil,
            lastFinalAnswerAt: attentionReason == .newSinceView ? activityAt : nil,
            lastTerminalAt: nil,
            lastTerminalState: nil,
            lastViewedAt: nil,
            checkpoint: "Fixture",
            historyComplete: historyComplete
        )
    }

    private static func checkMarkdownCleanupPreservesTechnicalText() throws {
        var reducer = RolloutReducer()
        reducer.consume(
            line: data(
                #"{"timestamp":"2026-07-27T10:00:05.000Z","type":"event_msg","payload":{"type":"agent_message","phase":"final_answer","message":"**Hedef Tamamlandı** C# #42 5*3 *.pdf"}}"#
            )
        )
        try require(
            reducer.summary.checkpoint == "Hedef Tamamlandı C# #42 5*3 *.pdf",
            "Markdown cleanup damaged technical text"
        )

        reducer.consume(
            line: data(
                #"{"timestamp":"2026-07-27T10:00:06.000Z","type":"response_item","payload":{"type":"function_call","name":"request_user_input","call_id":"call-stale"}}"#
            )
        )
        reducer.consume(
            line: data(
                #"{"timestamp":"2026-07-27T10:00:07.000Z","type":"event_msg","payload":{"type":"task_complete","turn_id":"turn-missing"}}"#
            )
        )
        try require(reducer.summary.pendingInputCallIDs.isEmpty, "terminal event retained stale input")
    }

    private static func checkDeepLink() throws {
        let actual = CodexActivityReader
            .deepLink(for: "123e4567-e89b-42d3-a456-426614174000")?
            .absoluteString
        try require(
            actual == "codex://threads/123e4567-e89b-42d3-a456-426614174000",
            "deep-link contract changed"
        )
    }

    private static func checkReadOnlySQLite() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ActivityRadarSelfTest-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let databaseURL = directory.appendingPathComponent("fixture.sqlite")
        var writable: OpaquePointer?
        guard sqlite3_open(databaseURL.path, &writable) == SQLITE_OK, let writable else {
            throw SelfTestFailure(message: "could not create SQLite fixture")
        }
        defer { sqlite3_close(writable) }
        guard sqlite3_exec(writable, "CREATE TABLE sample(value TEXT);", nil, nil, nil) == SQLITE_OK else {
            throw SelfTestFailure(message: "could not initialize SQLite fixture")
        }

        let readOnly = try SQLiteReadOnly(path: databaseURL.path)
        try readOnly.rows(sql: "SELECT name FROM sqlite_master;") { _ in }

        do {
            try readOnly.rows(sql: "INSERT INTO sample(value) VALUES ('forbidden');") { _ in }
            throw SelfTestFailure(message: "read-only connection accepted a write")
        } catch is ActivityReaderError {
            // Expected: the production connector rejects mutation.
        }
    }

    private static func checkPublicErrorsHideHomeDirectory() throws {
        let sentinel = "/Users/private-person/.codex/state_5.sqlite"
        let missing = ActivityReaderError.missingCodexState(sentinel).localizedDescription
        let open = ActivityReaderError.sqliteOpen(
            path: sentinel,
            message: "permission denied"
        ).localizedDescription

        for description in [missing, open] {
            try require(!description.contains("private-person"), "public error exposed a home-directory component")
            try require(!description.contains("/Users/"), "public error exposed an absolute home path")
            try require(description.contains("~/.codex/state_5.sqlite"), "public error hid the actionable Codex location")
        }
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        guard condition() else {
            throw SelfTestFailure(message: message)
        }
    }

    private static func data(_ value: String) -> Data {
        Data(value.utf8)
    }
}

private struct SelfTestFailure: LocalizedError {
    let message: String

    var errorDescription: String? {
        "Self-test failed: \(message)"
    }
}
