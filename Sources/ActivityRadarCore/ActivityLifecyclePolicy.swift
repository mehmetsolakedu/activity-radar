import Foundation

public enum ActivityLifecycleSuggestion: String, Codable, Sendable {
    case historical
    case stale
    case longParked
    case unfinishedCandidate
    case abandonedCandidate
}

public enum ActivityLifecyclePolicy {
    public static func suggestion(
        for item: ActivityItem,
        lastOpenedAt: Date? = nil,
        now: Date = Date()
    ) -> ActivityLifecycleSuggestion? {
        let day = 24.0 * 60 * 60
        let thirtyDays = 30.0 * day
        let ninetyDays = 90.0 * day

        if item.attentionReason != nil
            || item.executionState == .recentlyActive {
            return nil
        }

        if let lastOpenedAt,
           now.timeIntervalSince(lastOpenedAt) <= thirtyDays {
            return nil
        }

        if let lastActivityAt = item.lastActivityAt,
           now.timeIntervalSince(lastActivityAt) <= day {
            return nil
        }

        switch item.goalStatus {
        case .active, .blocked, .usageLimited, .budgetLimited, .unknown:
            return nil
        default:
            break
        }

        guard item.historyComplete else { return nil }
        let age = now.timeIntervalSince(item.timelineActivityAt)
        guard age >= 0 else { return nil }

        if item.goalStatus == .paused {
            return age >= ninetyDays ? .longParked : nil
        }
        if item.executionState == .aborted {
            return age >= thirtyDays ? .unfinishedCandidate : nil
        }
        if item.executionState == .openSilent {
            return age >= thirtyDays ? .stale : nil
        }
        if item.goalStatus == .complete || item.executionState == .completed {
            return age >= thirtyDays ? .historical : nil
        }
        if item.executionState == .idle {
            return age >= thirtyDays ? .stale : nil
        }
        return nil
    }
}
