import Foundation
#if canImport(Testing)
import Testing
@testable import ActivityRadarCore

@Test
func triagePrefersDirectObservedNeed() throws {
    let now = Date(timeIntervalSince1970: 2_000_000_000)
    let result = WorkContinuityRanker.rank(
        [
            WorkTriageInput(
                item: continuityFixture(id: "unseen", now: now, attention: .newSinceView),
                metadata: WorkContinuityMetadata()
            ),
            WorkTriageInput(
                item: continuityFixture(id: "important", now: now),
                metadata: WorkContinuityMetadata(
                    importance: .high,
                    nextAction: "Run the bounded check"
                )
            )
        ],
        now: now
    )

    #expect(result.recommendedActivityID == "unseen")
    #expect(result.abstentionReason == nil)
    let first = try #require(result.rankedCandidates.first)
    #expect(first.reasons.contains { $0.code == .unseenResult })
}

@Test
func triageTreatsFutureSnoozeAsAbsoluteIntent() {
    let now = Date(timeIntervalSince1970: 2_000_000_000)
    let snoozeUntil = now.addingTimeInterval(3_600)
    let quiet = WorkTriageInput(
        item: continuityFixture(id: "quiet", now: now),
        metadata: WorkContinuityMetadata(snoozeUntil: snoozeUntil)
    )
    let attention = WorkTriageInput(
        item: continuityFixture(id: "attention", now: now, attention: .explicitInput),
        metadata: WorkContinuityMetadata(
            deadline: now.addingTimeInterval(-60),
            snoozeUntil: snoozeUntil
        )
    )

    let result = WorkContinuityRanker.rank([quiet, attention], now: now)

    #expect(result.recommendedActivityID == nil)
    #expect(result.abstentionReason == .noEligibleWork)
    #expect(result.rankedCandidates.isEmpty)
    #expect(
        result.deferred == [
            WorkTriageDeferral(activityID: "attention", reason: .snoozed, until: snoozeUntil),
            WorkTriageDeferral(activityID: "quiet", reason: .snoozed, until: snoozeUntil)
        ]
    )
}

@Test
func triageTreatsWaitingOnAsAbsoluteIntent() {
    let now = Date(timeIntervalSince1970: 2_000_000_000)
    let input = WorkTriageInput(
        item: continuityFixture(id: "waiting", now: now, attention: .explicitInput),
        metadata: WorkContinuityMetadata(
            deadline: now.addingTimeInterval(-60),
            waitingOn: "External review"
        )
    )

    let result = WorkContinuityRanker.rank([input], now: now)

    #expect(result.recommendedActivityID == nil)
    #expect(result.abstentionReason == .noEligibleWork)
    #expect(result.rankedCandidates.isEmpty)
    #expect(result.deferred == [WorkTriageDeferral(activityID: "waiting", reason: .waitingOnExternal)])
}

@Test
func triageAbstainsWhenStrongCandidatesAreTooClose() {
    let now = Date(timeIntervalSince1970: 2_000_000_000)
    let first = WorkTriageInput(
        item: continuityFixture(id: "a", now: now, attention: .explicitInput)
    )
    let second = WorkTriageInput(
        item: continuityFixture(id: "b", now: now, attention: .explicitInput)
    )

    let result = WorkContinuityRanker.rank([second, first], now: now)

    #expect(result.recommendedActivityID == nil)
    #expect(result.abstentionReason == .competingSignals)
    #expect(result.rankedCandidates.isEmpty)
}

@Test
func triageAbstainsOnIncompleteInferredEvidence() {
    let now = Date(timeIntervalSince1970: 2_000_000_000)
    let input = WorkTriageInput(
        item: continuityFixture(
            id: "partial",
            now: now,
            attention: .explicitInput,
            historyComplete: false
        ),
        metadata: WorkContinuityMetadata(
            importance: .high,
            nextAction: "Continue"
        )
    )

    let result = WorkContinuityRanker.rank([input], now: now)

    #expect(result.recommendedActivityID == nil)
    #expect(result.abstentionReason == .incompleteHistory)
    #expect(result.rankedCandidates.isEmpty)
}

@Test
func lowScoreAbstentionDoesNotExposeRankedCandidates() {
    let now = Date(timeIntervalSince1970: 2_000_000_000)
    let input = WorkTriageInput(
        item: continuityFixture(id: "weak", now: now),
        metadata: WorkContinuityMetadata(importance: .high)
    )

    let result = WorkContinuityRanker.rank([input], now: now)

    #expect(result.recommendedActivityID == nil)
    #expect(result.abstentionReason == .insufficientEvidence)
    #expect(result.rankedCandidates.isEmpty)
}

// These post-freeze engineering tests expose rule outputs that are hidden by
// the V1 corpus whenever the complete candidate score remains below the
// recommendation threshold. They are regression evidence, not an amendment to
// the frozen V1 corpus or its archived result.
@Test
func postFreezeObservabilityDeadlineWithinWeek() throws {
    let now = Date(timeIntervalSince1970: 2_000_000_000)
    let deadline = now.addingTimeInterval(6 * 24 * 60 * 60)
    let result = WorkContinuityRanker.rank(
        [
            WorkTriageInput(
                item: continuityFixture(id: "deadline-week", now: now),
                metadata: WorkContinuityMetadata(
                    deadline: deadline,
                    nextAction: "Continue"
                )
            )
        ],
        now: now
    )

    #expect(result.recommendedActivityID == "deadline-week")
    #expect(result.abstentionReason == nil)
    #expect(
        try #require(result.rankedCandidates.first) == WorkTriageCandidate(
            activityID: "deadline-week",
            score: 30,
            reasons: [
                WorkTriageReason(code: .deadlineWithinWeek, weight: 20, evidenceAt: deadline),
                WorkTriageReason(code: .nextActionRecorded, weight: 10)
            ]
        )
    )
}

@Test
func postFreezeObservabilityLowImportance() throws {
    let now = Date(timeIntervalSince1970: 2_000_000_000)
    let result = WorkContinuityRanker.rank(
        [
            WorkTriageInput(
                item: continuityFixture(id: "low", now: now, attention: .explicitInput),
                metadata: WorkContinuityMetadata(importance: .low)
            )
        ],
        now: now
    )

    #expect(result.recommendedActivityID == "low")
    #expect(
        try #require(result.rankedCandidates.first) == WorkTriageCandidate(
            activityID: "low",
            score: 90,
            reasons: [
                WorkTriageReason(code: .explicitInput, weight: 100, evidenceAt: now),
                WorkTriageReason(code: .lowImportance, weight: -10)
            ]
        )
    )
}

@Test
func postFreezeObservabilityAgingWithoutPlanSevenToThirtyDays() throws {
    let now = Date(timeIntervalSince1970: 2_000_000_000)
    let activityAt = now.addingTimeInterval(-8 * 24 * 60 * 60)
    let result = WorkContinuityRanker.rank(
        [
            WorkTriageInput(
                item: continuityFixture(id: "aging-eight", now: activityAt),
                metadata: WorkContinuityMetadata(importance: .high)
            )
        ],
        now: now
    )

    #expect(result.recommendedActivityID == "aging-eight")
    #expect(
        try #require(result.rankedCandidates.first) == WorkTriageCandidate(
            activityID: "aging-eight",
            score: 32,
            reasons: [
                WorkTriageReason(code: .highImportance, weight: 20),
                WorkTriageReason(code: .agingWithoutPlan, weight: 12, evidenceAt: activityAt)
            ]
        )
    )
}

@Test
func postFreezeObservabilityAgingWithoutPlanThirtyDaysOrMore() throws {
    let now = Date(timeIntervalSince1970: 2_000_000_000)
    let activityAt = now.addingTimeInterval(-31 * 24 * 60 * 60)
    let result = WorkContinuityRanker.rank(
        [
            WorkTriageInput(
                item: continuityFixture(id: "aging-thirty-one", now: activityAt),
                metadata: WorkContinuityMetadata(importance: .high)
            )
        ],
        now: now
    )

    #expect(result.recommendedActivityID == "aging-thirty-one")
    #expect(
        try #require(result.rankedCandidates.first) == WorkTriageCandidate(
            activityID: "aging-thirty-one",
            score: 38,
            reasons: [
                WorkTriageReason(code: .highImportance, weight: 20),
                WorkTriageReason(code: .agingWithoutPlan, weight: 18, evidenceAt: activityAt)
            ]
        )
    )
}

@Test
func postFreezeObservabilityRecentlyActive() throws {
    let now = Date(timeIntervalSince1970: 2_000_000_000)
    let result = WorkContinuityRanker.rank(
        [
            WorkTriageInput(
                item: continuityFixture(
                    id: "recently-active",
                    now: now,
                    executionState: .recentlyActive
                ),
                metadata: WorkContinuityMetadata(
                    importance: .high,
                    nextAction: "Continue"
                )
            )
        ],
        now: now
    )

    #expect(result.recommendedActivityID == "recently-active")
    #expect(
        try #require(result.rankedCandidates.first) == WorkTriageCandidate(
            activityID: "recently-active",
            score: 38,
            reasons: [
                WorkTriageReason(code: .highImportance, weight: 20),
                WorkTriageReason(code: .nextActionRecorded, weight: 10),
                WorkTriageReason(code: .recentlyActive, weight: 8, evidenceAt: now)
            ]
        )
    )
}

@Test
func postFreezeObservabilityEmptyPortfolio() {
    let now = Date(timeIntervalSince1970: 2_000_000_000)
    let result = WorkContinuityRanker.rank([], now: now)

    #expect(result.evaluatedAt == now)
    #expect(result.recommendedActivityID == nil)
    #expect(result.abstentionReason == .insufficientEvidence)
    #expect(result.rankedCandidates.isEmpty)
    #expect(result.deferred.isEmpty)
}

@Test
func dueSnoozeIsAcknowledgedByAcceptedOpenRequestAfterDueDate() {
    let now = Date(timeIntervalSince1970: 2_000_000_000)
    let snoozeUntil = now.addingTimeInterval(-60)
    let item = continuityFixture(id: "due", now: now)
    let metadata = WorkContinuityMetadata(
        importance: .critical,
        nextAction: "Resume",
        snoozeUntil: snoozeUntil
    )

    let acknowledged = WorkContinuityRanker.rank(
        [WorkTriageInput(item: item, metadata: metadata, lastOpenedAt: now)],
        now: now
    )
    #expect(acknowledged.recommendedActivityID == nil)
    #expect(acknowledged.abstentionReason == .insufficientEvidence)
    #expect(acknowledged.rankedCandidates.isEmpty)

    let notYetAcknowledged = WorkContinuityRanker.rank(
        [
            WorkTriageInput(
                item: item,
                metadata: metadata,
                lastOpenedAt: snoozeUntil.addingTimeInterval(-60)
            )
        ],
        now: now
    )
    #expect(notYetAcknowledged.recommendedActivityID == "due")
    #expect(notYetAcknowledged.abstentionReason == nil)
    #expect(notYetAcknowledged.rankedCandidates.first?.reasons.contains { $0.code == .plannedReturnDue } == true)
}

@Test
func lifecycleNeverInfersObsoleteOrConfirmedAbandonment() {
    let now = Date(timeIntervalSince1970: 2_000_000_000)
    let old = now.addingTimeInterval(-120 * 24 * 60 * 60)
    let item = continuityFixture(
        id: "old-open",
        now: old,
        executionState: .openSilent
    )

    let assessment = WorkContinuityLifecycle.assess(item: item, now: now)

    #expect(assessment.state == .dormant)
    #expect(!assessment.requiresUserConfirmation)
    #expect(assessment.state != .obsoleteConfirmed)
    #expect(assessment.state != .abandonedConfirmed)
}

@Test
func legacyOpenSilentPolicyIsNeutralStale() {
    let now = Date(timeIntervalSince1970: 2_000_000_000)
    let old = now.addingTimeInterval(-31 * 24 * 60 * 60)
    let item = continuityFixture(id: "old-open", now: old, executionState: .openSilent)

    #expect(ActivityLifecyclePolicy.suggestion(for: item, now: now) == .stale)
}

@Test
func abortedSilenceAlsoRemainsDormant() {
    let now = Date(timeIntervalSince1970: 2_000_000_000)
    let old = now.addingTimeInterval(-120 * 24 * 60 * 60)
    let item = continuityFixture(id: "old-abort", now: old, executionState: .aborted)

    let assessment = WorkContinuityLifecycle.assess(item: item, now: now)

    #expect(assessment.state == .dormant)
    #expect(!assessment.requiresUserConfirmation)
}

@Test
func lifecycleConfirmationIsExplicitAndReversibleData() {
    let now = Date(timeIntervalSince1970: 2_000_000_000)
    let confirmedAt = now.addingTimeInterval(-60)
    let item = continuityFixture(id: "superseded", now: now)

    let assessment = WorkContinuityLifecycle.assess(
        item: item,
        confirmation: WorkLifecycleConfirmation(state: .obsolete, confirmedAt: confirmedAt),
        now: now
    )

    #expect(assessment.state == .obsoleteConfirmed)
    #expect(!assessment.requiresUserConfirmation)
    #expect(assessment.evidence == [WorkLifecycleEvidence(code: .userConfirmed, observedAt: confirmedAt)])

    let abandoned = WorkContinuityLifecycle.assess(
        item: item,
        confirmation: WorkLifecycleConfirmation(state: .abandoned, confirmedAt: confirmedAt),
        now: now
    )
    #expect(abandoned.state == .abandonedConfirmed)
    #expect(!abandoned.requiresUserConfirmation)
}

@Test
func incompleteHistoryProducesUncertainLifecycle() {
    let now = Date(timeIntervalSince1970: 2_000_000_000)
    let item = continuityFixture(id: "partial", now: now, historyComplete: false)

    let assessment = WorkContinuityLifecycle.assess(item: item, now: now)

    #expect(assessment.state == .uncertain)
    #expect(assessment.evidence.map(\.code) == [.historyIncomplete])
}

@Test
func metadataRoundTripsWithoutChangingIntent() throws {
    let metadata = WorkContinuityMetadata(
        importance: .critical,
        deadline: Date(timeIntervalSince1970: 2_000_100_000),
        nextAction: "  Verify the result  ",
        waitingOn: nil,
        snoozeUntil: Date(timeIntervalSince1970: 2_000_050_000)
    )

    let encoded = try JSONEncoder().encode(metadata)
    let decoded = try JSONDecoder().decode(WorkContinuityMetadata.self, from: encoded)

    #expect(decoded == metadata)
    #expect(decoded.hasNextAction)
    #expect(!decoded.isWaiting)
}

private func continuityFixture(
    id: String,
    now: Date,
    executionState: ActivityExecutionState = .idle,
    attention: ActivityAttentionReason? = nil,
    goalStatus: ActivityGoalStatus? = nil,
    historyComplete: Bool = true
) -> ActivityItem {
    ActivityItem(
        id: id,
        title: "Fixture \(id)",
        projectName: "Continuity Tests",
        cwd: "/tmp/continuity-tests",
        rolloutPath: "/tmp/continuity-tests/rollout.jsonl",
        executionState: executionState,
        attentionReason: attention,
        goalStatus: goalStatus,
        goalUpdatedAt: goalStatus == nil ? nil : now,
        createdAt: now.addingTimeInterval(-60),
        startedAt: now,
        updatedAt: now,
        lastActivityAt: now,
        lastUserMessageAt: now,
        lastMeaningfulAgentAt: nil,
        lastFinalAnswerAt: attention == .newSinceView ? now : nil,
        lastTerminalAt: nil,
        lastTerminalState: nil,
        lastViewedAt: nil,
        checkpoint: "Fixture",
        historyComplete: historyComplete
    )
}
#endif
