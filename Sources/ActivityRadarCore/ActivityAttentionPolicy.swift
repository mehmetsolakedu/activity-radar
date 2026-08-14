import Foundation

enum ActivityAttentionPolicy {
    static func reason(
        summary: RolloutSummary,
        goalStatus: ActivityGoalStatus?,
        viewedAt: Date?,
        unviewedResultsAfter: Date?,
        now: Date
    ) -> ActivityAttentionReason? {
        if !summary.pendingInputCallIDs.isEmpty {
            return .explicitInput
        }
        if goalStatus == .blocked {
            return .goalBlocked
        }

        switch goalStatus {
        case .usageLimited:
            return .usageLimited
        case .budgetLimited:
            return .budgetLimited
        case .paused:
            // A pause is a parked state, not an action request. Keep its goal
            // badge visible without turning routine goal-row updates into noise.
            return nil
        default:
            break
        }

        if let finalAt = summary.lastFinalAnswerAt {
            if let viewedAt {
                if finalAt > viewedAt {
                    return .newSinceView
                }
            } else if let unviewedResultsAfter {
                if finalAt > unviewedResultsAfter {
                    return .newSinceView
                }
            } else {
                let age = now.timeIntervalSince(finalAt)
                if age >= 0 && age <= 3_600 {
                    return .newSinceView
                }
            }
        }
        return nil
    }
}
