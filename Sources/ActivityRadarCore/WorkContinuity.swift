import Foundation

/// User-authored continuity data. This value layer performs no I/O: callers
/// must keep it outside `~/.codex` and must not transmit its free-text fields.
public struct WorkContinuityMetadata: Codable, Equatable, Sendable {
    public var importance: WorkImportance?
    public var deadline: Date?
    public var nextAction: String?
    public var waitingOn: String?
    public var snoozeUntil: Date?

    public init(
        importance: WorkImportance? = nil,
        deadline: Date? = nil,
        nextAction: String? = nil,
        waitingOn: String? = nil,
        snoozeUntil: Date? = nil
    ) {
        self.importance = importance
        self.deadline = deadline
        self.nextAction = nextAction
        self.waitingOn = waitingOn
        self.snoozeUntil = snoozeUntil
    }

    public var hasNextAction: Bool {
        hasText(nextAction)
    }

    public var isWaiting: Bool {
        hasText(waitingOn)
    }
}

public enum WorkImportance: String, Codable, CaseIterable, Sendable {
    case low
    case normal
    case high
    case critical
}

public struct WorkTriageInput: Codable, Sendable {
    public let item: ActivityItem
    public let metadata: WorkContinuityMetadata
    public let lastOpenedAt: Date?

    public init(
        item: ActivityItem,
        metadata: WorkContinuityMetadata = WorkContinuityMetadata(),
        lastOpenedAt: Date? = nil
    ) {
        self.item = item
        self.metadata = metadata
        self.lastOpenedAt = lastOpenedAt
    }
}

public enum WorkTriageReasonCode: String, Codable, CaseIterable, Sendable {
    case explicitInput
    case goalBlocked
    case usageLimited
    case budgetLimited
    case unseenResult
    case deadlineOverdue
    case deadlineWithinDay
    case deadlineWithinThreeDays
    case deadlineWithinWeek
    case plannedReturnDue
    case criticalImportance
    case highImportance
    case lowImportance
    case nextActionRecorded
    case agingWithoutPlan
    case recentlyActive
    case recentlyOpened
    case waitingOnRecorded
    case historyIncomplete
}

/// A reason is intentionally small and content-free so it can be displayed or
/// logged without copying titles, prompts, paths, next actions, or checkpoints.
public struct WorkTriageReason: Codable, Equatable, Sendable {
    public let code: WorkTriageReasonCode
    public let weight: Int
    public let evidenceAt: Date?

    public init(code: WorkTriageReasonCode, weight: Int, evidenceAt: Date? = nil) {
        self.code = code
        self.weight = weight
        self.evidenceAt = evidenceAt
    }
}

public struct WorkTriageCandidate: Codable, Equatable, Sendable {
    public let activityID: String
    public let score: Int
    public let reasons: [WorkTriageReason]

    public init(activityID: String, score: Int, reasons: [WorkTriageReason]) {
        self.activityID = activityID
        self.score = score
        self.reasons = reasons
    }
}

public enum WorkTriageDeferralReason: String, Codable, Sendable {
    case snoozed
    case waitingOnExternal
    case terminal
}

public struct WorkTriageDeferral: Codable, Equatable, Sendable {
    public let activityID: String
    public let reason: WorkTriageDeferralReason
    public let until: Date?

    public init(activityID: String, reason: WorkTriageDeferralReason, until: Date? = nil) {
        self.activityID = activityID
        self.reason = reason
        self.until = until
    }
}

public enum WorkTriageAbstentionReason: String, Codable, Sendable {
    case noEligibleWork
    case insufficientEvidence
    case incompleteHistory
    case competingSignals
}

public struct WorkTriageResult: Codable, Equatable, Sendable {
    public let evaluatedAt: Date
    public let rankedCandidates: [WorkTriageCandidate]
    public let recommendedActivityID: String?
    public let abstentionReason: WorkTriageAbstentionReason?
    public let deferred: [WorkTriageDeferral]

    public init(
        evaluatedAt: Date,
        rankedCandidates: [WorkTriageCandidate],
        recommendedActivityID: String?,
        abstentionReason: WorkTriageAbstentionReason?,
        deferred: [WorkTriageDeferral]
    ) {
        self.evaluatedAt = evaluatedAt
        self.rankedCandidates = rankedCandidates
        self.recommendedActivityID = recommendedActivityID
        self.abstentionReason = abstentionReason
        self.deferred = deferred
    }

    public var didAbstain: Bool {
        recommendedActivityID == nil
    }
}

/// A deterministic and deliberately conservative portfolio ranker. It never
/// reads or mutates Codex state. It does not inspect lexical text content, but
/// it does use the trimmed presence of next-action and waiting text.
public enum WorkContinuityRanker {
    private static let day: TimeInterval = 24 * 60 * 60
    private static let minimumRecommendationScore = 30
    private static let minimumLead = 10

    public static func rank(
        _ inputs: [WorkTriageInput],
        now: Date = Date(),
        limit: Int = 3
    ) -> WorkTriageResult {
        var candidates: [WorkTriageCandidate] = []
        var deferred: [WorkTriageDeferral] = []
        var hasEligibleIncompleteHistory = false
        var hasEligibleCompleteHistory = false

        for input in inputs {
            if let deferral = deferral(for: input, now: now) {
                deferred.append(deferral)
                continue
            }

            guard input.item.historyComplete else {
                hasEligibleIncompleteHistory = true
                continue
            }
            hasEligibleCompleteHistory = true

            let reasons = reasons(for: input, now: now)
            guard !reasons.isEmpty else { continue }
            candidates.append(
                WorkTriageCandidate(
                    activityID: input.item.id,
                    score: reasons.reduce(0) { $0 + $1.weight },
                    reasons: reasons
                )
            )
        }

        candidates.sort { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            return lhs.activityID < rhs.activityID
        }
        deferred.sort { $0.activityID < $1.activityID }

        let visible = Array(candidates.prefix(max(1, limit)))
        guard let first = candidates.first else {
            let abstentionReason: WorkTriageAbstentionReason
            if hasEligibleIncompleteHistory {
                abstentionReason = .incompleteHistory
            } else if !deferred.isEmpty && !hasEligibleCompleteHistory {
                abstentionReason = .noEligibleWork
            } else {
                abstentionReason = .insufficientEvidence
            }
            return WorkTriageResult(
                evaluatedAt: now,
                rankedCandidates: [],
                recommendedActivityID: nil,
                abstentionReason: abstentionReason,
                deferred: deferred
            )
        }

        if first.score < minimumRecommendationScore {
            return WorkTriageResult(
                evaluatedAt: now,
                rankedCandidates: [],
                recommendedActivityID: nil,
                abstentionReason: .insufficientEvidence,
                deferred: deferred
            )
        }

        if candidates.count > 1,
           first.score - candidates[1].score < minimumLead {
            return WorkTriageResult(
                evaluatedAt: now,
                rankedCandidates: [],
                recommendedActivityID: nil,
                abstentionReason: .competingSignals,
                deferred: deferred
            )
        }

        return WorkTriageResult(
            evaluatedAt: now,
            rankedCandidates: visible,
            recommendedActivityID: first.activityID,
            abstentionReason: nil,
            deferred: deferred
        )
    }

    private static func deferral(for input: WorkTriageInput, now: Date) -> WorkTriageDeferral? {
        let hasDirectAttention = input.item.attentionReason != nil
        let snoozeIsDue = input.metadata.snoozeUntil.map { $0 <= now } ?? false
        let deadlineIsUrgent = input.metadata.deadline.map { $0 <= now.addingTimeInterval(3 * day) } ?? false

        if let snoozeUntil = input.metadata.snoozeUntil,
           snoozeUntil > now {
            return WorkTriageDeferral(
                activityID: input.item.id,
                reason: .snoozed,
                until: snoozeUntil
            )
        }

        if input.metadata.isWaiting {
            return WorkTriageDeferral(
                activityID: input.item.id,
                reason: .waitingOnExternal
            )
        }

        let goalLooksComplete = input.item.goalStatus == .complete
            && input.item.executionState != .openSilent
            && input.item.executionState != .aborted
            && input.item.executionState != .recentlyActive
        if (input.item.executionState == .completed || goalLooksComplete)
            && !hasDirectAttention
            && !deadlineIsUrgent
            && !snoozeIsDue {
            return WorkTriageDeferral(
                activityID: input.item.id,
                reason: .terminal
            )
        }
        return nil
    }

    private static func reasons(for input: WorkTriageInput, now: Date) -> [WorkTriageReason] {
        var result: [WorkTriageReason] = []

        if let attention = input.item.attentionReason {
            let reason: WorkTriageReason
            switch attention {
            case .explicitInput:
                reason = WorkTriageReason(code: .explicitInput, weight: 100, evidenceAt: input.item.lastActivityAt)
            case .goalBlocked:
                reason = WorkTriageReason(code: .goalBlocked, weight: 90, evidenceAt: input.item.goalUpdatedAt)
            case .newSinceView:
                reason = WorkTriageReason(code: .unseenResult, weight: 80, evidenceAt: input.item.lastFinalAnswerAt)
            case .usageLimited:
                reason = WorkTriageReason(code: .usageLimited, weight: 70, evidenceAt: input.item.goalUpdatedAt)
            case .budgetLimited:
                reason = WorkTriageReason(code: .budgetLimited, weight: 70, evidenceAt: input.item.goalUpdatedAt)
            }
            result.append(reason)
        }

        if let deadline = input.metadata.deadline {
            let remaining = deadline.timeIntervalSince(now)
            if remaining <= 0 {
                result.append(WorkTriageReason(code: .deadlineOverdue, weight: 65, evidenceAt: deadline))
            } else if remaining <= day {
                result.append(WorkTriageReason(code: .deadlineWithinDay, weight: 55, evidenceAt: deadline))
            } else if remaining <= 3 * day {
                result.append(WorkTriageReason(code: .deadlineWithinThreeDays, weight: 40, evidenceAt: deadline))
            } else if remaining <= 7 * day {
                result.append(WorkTriageReason(code: .deadlineWithinWeek, weight: 20, evidenceAt: deadline))
            }
        }

        if let snoozeUntil = input.metadata.snoozeUntil,
           snoozeUntil <= now,
           input.lastOpenedAt.map({ $0 < snoozeUntil }) ?? true {
            result.append(WorkTriageReason(code: .plannedReturnDue, weight: 45, evidenceAt: snoozeUntil))
        }

        switch input.metadata.importance {
        case .critical:
            result.append(WorkTriageReason(code: .criticalImportance, weight: 30))
        case .high:
            result.append(WorkTriageReason(code: .highImportance, weight: 20))
        case .low:
            result.append(WorkTriageReason(code: .lowImportance, weight: -10))
        case .normal, .none:
            break
        }

        if input.metadata.hasNextAction {
            result.append(WorkTriageReason(code: .nextActionRecorded, weight: 10))
        } else {
            let age = now.timeIntervalSince(input.item.timelineActivityAt)
            if age >= 7 * day {
                let weight = age >= 30 * day ? 18 : 12
                result.append(
                    WorkTriageReason(
                        code: .agingWithoutPlan,
                        weight: weight,
                        evidenceAt: input.item.timelineActivityAt
                    )
                )
            }
        }

        if input.item.executionState == .recentlyActive {
            result.append(WorkTriageReason(code: .recentlyActive, weight: 8, evidenceAt: input.item.lastActivityAt))
        }
        if let lastOpenedAt = input.lastOpenedAt {
            let timeSinceOpen = now.timeIntervalSince(lastOpenedAt)
            if timeSinceOpen >= 0, timeSinceOpen <= 15 * 60 {
                result.append(WorkTriageReason(code: .recentlyOpened, weight: -15, evidenceAt: lastOpenedAt))
            }
        }
        if input.metadata.isWaiting {
            result.append(WorkTriageReason(code: .waitingOnRecorded, weight: -40))
        }
        return result
    }
}

public enum WorkLifecycleConfirmedState: String, Codable, CaseIterable, Sendable {
    case current
    case waitingHuman
    case waitingExternal
    case blocked
    case completed
    case completedElsewhere
    case superseded
    case abandoned
    case obsolete
    case duplicate
}

public struct WorkLifecycleConfirmation: Codable, Equatable, Sendable {
    public let state: WorkLifecycleConfirmedState
    public let confirmedAt: Date

    public init(state: WorkLifecycleConfirmedState, confirmedAt: Date) {
        self.state = state
        self.confirmedAt = confirmedAt
    }
}

public enum WorkLifecycleState: String, Codable, CaseIterable, Sendable {
    case current
    case waitingHuman
    case waitingExternal
    case blocked
    case dormant
    case likelyAbandoned
    case completed
    case completedElsewhere
    case superseded
    case abandonedConfirmed
    case obsoleteConfirmed
    case duplicate
    case uncertain
}

public enum WorkLifecycleEvidenceCode: String, Codable, CaseIterable, Sendable {
    case userConfirmed
    case explicitInput
    case attentionRequired
    case activeGoal
    case blockedGoal
    case limitedGoal
    case pausedGoal
    case completedGoal
    case recentlyActive
    case completedExecution
    case abortedExecution
    case recentActivity
    case recentlyOpened
    case nextActionRecorded
    case waitingOnRecorded
    case snoozedUntil
    case deadlineOutstanding
    case inactiveThirtyDays
    case inactiveNinetyDays
    case historyIncomplete
    case unknownState
}

public struct WorkLifecycleEvidence: Codable, Equatable, Sendable {
    public let code: WorkLifecycleEvidenceCode
    public let observedAt: Date?
    public let ageInDays: Int?

    public init(
        code: WorkLifecycleEvidenceCode,
        observedAt: Date? = nil,
        ageInDays: Int? = nil
    ) {
        self.code = code
        self.observedAt = observedAt
        self.ageInDays = ageInDays
    }
}

public struct WorkLifecycleAssessment: Codable, Equatable, Sendable {
    public let activityID: String
    public let state: WorkLifecycleState
    public let evidence: [WorkLifecycleEvidence]
    public let requiresUserConfirmation: Bool
    public let assessedAt: Date

    public init(
        activityID: String,
        state: WorkLifecycleState,
        evidence: [WorkLifecycleEvidence],
        requiresUserConfirmation: Bool,
        assessedAt: Date
    ) {
        self.activityID = activityID
        self.state = state
        self.evidence = evidence
        self.requiresUserConfirmation = requiresUserConfirmation
        self.assessedAt = assessedAt
    }
}

/// Lifecycle inference remains neutral for silence, open turns, and aborted
/// turns. Obsolete and abandoned states require an explicit confirmation.
public enum WorkContinuityLifecycle {
    private static let day: TimeInterval = 24 * 60 * 60

    public static func assess(
        item: ActivityItem,
        metadata: WorkContinuityMetadata = WorkContinuityMetadata(),
        lastOpenedAt: Date? = nil,
        confirmation: WorkLifecycleConfirmation? = nil,
        now: Date = Date()
    ) -> WorkLifecycleAssessment {
        if let confirmation {
            return WorkLifecycleAssessment(
                activityID: item.id,
                state: state(for: confirmation.state),
                evidence: [
                    WorkLifecycleEvidence(
                        code: .userConfirmed,
                        observedAt: confirmation.confirmedAt
                    )
                ],
                requiresUserConfirmation: false,
                assessedAt: now
            )
        }

        let activityAt = item.timelineActivityAt
        let age = max(0, now.timeIntervalSince(activityAt))
        let ageInDays = Int(age / day)
        var evidence: [WorkLifecycleEvidence] = []

        if item.attentionReason == .explicitInput {
            evidence.append(WorkLifecycleEvidence(code: .explicitInput, observedAt: item.lastActivityAt))
            return assessment(item.id, .waitingHuman, evidence, false, now)
        }
        if item.attentionReason != nil {
            evidence.append(WorkLifecycleEvidence(code: .attentionRequired, observedAt: item.lastActivityAt))
        }

        if item.goalStatus == .blocked || item.attentionReason == .goalBlocked {
            evidence.append(WorkLifecycleEvidence(code: .blockedGoal, observedAt: item.goalUpdatedAt))
            return assessment(item.id, .blocked, evidence, false, now)
        }
        if item.goalStatus == .usageLimited
            || item.goalStatus == .budgetLimited
            || item.attentionReason == .usageLimited
            || item.attentionReason == .budgetLimited {
            evidence.append(WorkLifecycleEvidence(code: .limitedGoal, observedAt: item.goalUpdatedAt))
            return assessment(item.id, .blocked, evidence, false, now)
        }
        if item.attentionReason != nil {
            return assessment(item.id, .current, evidence, false, now)
        }

        if metadata.isWaiting {
            evidence.append(WorkLifecycleEvidence(code: .waitingOnRecorded))
            return assessment(item.id, .waitingExternal, evidence, false, now)
        }
        if let snoozeUntil = metadata.snoozeUntil {
            evidence.append(WorkLifecycleEvidence(code: .snoozedUntil, observedAt: snoozeUntil))
            if snoozeUntil > now {
                return assessment(item.id, .dormant, evidence, false, now)
            }
            if now.timeIntervalSince(snoozeUntil) <= 30 * day {
                return assessment(item.id, .current, evidence, false, now)
            }
        }

        if item.executionState == .recentlyActive {
            evidence.append(WorkLifecycleEvidence(code: .recentlyActive, observedAt: item.lastActivityAt))
            return assessment(item.id, .current, evidence, false, now)
        }
        if item.goalStatus == .active {
            evidence.append(WorkLifecycleEvidence(code: .activeGoal, observedAt: item.goalUpdatedAt))
            return assessment(item.id, .current, evidence, false, now)
        }

        if !item.historyComplete {
            evidence.append(WorkLifecycleEvidence(code: .historyIncomplete))
            return assessment(item.id, .uncertain, evidence, false, now)
        }

        if item.executionState == .unknown || item.goalStatus == .unknown {
            evidence.append(WorkLifecycleEvidence(code: .unknownState, observedAt: activityAt))
            return assessment(item.id, .uncertain, evidence, false, now)
        }

        let goalLooksComplete = item.goalStatus == .complete
            && item.executionState != .openSilent
            && item.executionState != .aborted
        if item.executionState == .completed || goalLooksComplete {
            if item.executionState == .completed {
                evidence.append(WorkLifecycleEvidence(code: .completedExecution, observedAt: item.lastTerminalAt))
            } else {
                evidence.append(WorkLifecycleEvidence(code: .completedGoal, observedAt: item.goalUpdatedAt))
            }
            return assessment(item.id, .completed, evidence, false, now)
        }

        if item.goalStatus == .paused {
            evidence.append(WorkLifecycleEvidence(code: .pausedGoal, observedAt: item.goalUpdatedAt))
            return assessment(item.id, .dormant, evidence, false, now)
        }

        if metadata.hasNextAction {
            evidence.append(WorkLifecycleEvidence(code: .nextActionRecorded))
        }
        if let deadline = metadata.deadline {
            evidence.append(WorkLifecycleEvidence(code: .deadlineOutstanding, observedAt: deadline))
        }
        if metadata.deadline != nil {
            return assessment(item.id, .current, evidence, false, now)
        }
        if metadata.hasNextAction, age < 30 * day {
            return assessment(item.id, .current, evidence, false, now)
        }

        if let lastOpenedAt,
           now.timeIntervalSince(lastOpenedAt) >= 0,
           now.timeIntervalSince(lastOpenedAt) < 30 * day {
            evidence.append(WorkLifecycleEvidence(code: .recentlyOpened, observedAt: lastOpenedAt))
            return assessment(item.id, .current, evidence, false, now)
        }

        if age < 30 * day {
            evidence.append(WorkLifecycleEvidence(code: .recentActivity, observedAt: activityAt, ageInDays: ageInDays))
            return assessment(item.id, .current, evidence, false, now)
        }

        if age >= 90 * day,
           item.executionState == .openSilent || item.executionState == .aborted {
            if item.executionState == .aborted {
                evidence.append(WorkLifecycleEvidence(code: .abortedExecution, observedAt: item.lastTerminalAt))
            }
            evidence.append(WorkLifecycleEvidence(code: .inactiveNinetyDays, observedAt: activityAt, ageInDays: ageInDays))
            return assessment(item.id, .dormant, evidence, false, now)
        }

        if age >= 30 * day {
            evidence.append(WorkLifecycleEvidence(code: .inactiveThirtyDays, observedAt: activityAt, ageInDays: ageInDays))
            return assessment(item.id, .dormant, evidence, false, now)
        }

        evidence.append(WorkLifecycleEvidence(code: .unknownState, observedAt: activityAt))
        return assessment(item.id, .uncertain, evidence, false, now)
    }

    private static func assessment(
        _ activityID: String,
        _ state: WorkLifecycleState,
        _ evidence: [WorkLifecycleEvidence],
        _ requiresUserConfirmation: Bool,
        _ now: Date
    ) -> WorkLifecycleAssessment {
        WorkLifecycleAssessment(
            activityID: activityID,
            state: state,
            evidence: evidence,
            requiresUserConfirmation: requiresUserConfirmation,
            assessedAt: now
        )
    }

    private static func state(for confirmed: WorkLifecycleConfirmedState) -> WorkLifecycleState {
        switch confirmed {
        case .current: return .current
        case .waitingHuman: return .waitingHuman
        case .waitingExternal: return .waitingExternal
        case .blocked: return .blocked
        case .completed: return .completed
        case .completedElsewhere: return .completedElsewhere
        case .superseded: return .superseded
        case .abandoned: return .abandonedConfirmed
        case .obsolete: return .obsoleteConfirmed
        case .duplicate: return .duplicate
        }
    }
}

private func hasText(_ value: String?) -> Bool {
    guard let value else { return false }
    return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
}
