import Foundation

public enum ActivityExecutionState: String, Codable, CaseIterable, Sendable {
    case recentlyActive
    case openSilent
    case completed
    case aborted
    case idle
    case unknown
}

public enum ActivityAttentionReason: String, Codable, Sendable {
    case explicitInput
    case goalBlocked
    case usageLimited
    case budgetLimited
    case newSinceView
}

public enum ActivityGoalStatus: String, Codable, Sendable {
    case active
    case paused
    case blocked
    case usageLimited = "usage_limited"
    case budgetLimited = "budget_limited"
    case complete
    case unknown
}

public enum TerminalTurnState: String, Codable, Sendable {
    case completed
    case aborted
}

public enum CodexDeepLink {
    /// Builds the observed Codex Desktop thread route from exactly one UUID path segment.
    ///
    /// Codex currently stores thread identifiers as hyphenated UUID strings. Comparing the
    /// parsed UUID with its normalized representation accepts hexadecimal case variants
    /// but rejects whitespace, path traversal, query/fragment delimiters, encoded
    /// separators, braces, and alternate UUID layouts before any URL is created.
    public static func threadURL(for rawThreadID: String) -> URL? {
        guard let uuid = UUID(uuidString: rawThreadID) else { return nil }
        let canonicalThreadID = uuid.uuidString.lowercased()
        guard rawThreadID.lowercased() == canonicalThreadID else { return nil }

        var components = URLComponents()
        components.scheme = "codex"
        components.host = "threads"
        components.path = "/\(canonicalThreadID)"
        return components.url
    }
}

public struct ActivityItem: Identifiable, Codable, Sendable {
    public let id: String
    public let title: String
    public let projectName: String
    public let cwd: String
    public let rolloutPath: String
    public let executionState: ActivityExecutionState
    public let attentionReason: ActivityAttentionReason?
    public let goalStatus: ActivityGoalStatus?
    public let goalUpdatedAt: Date?
    public let createdAt: Date
    public let startedAt: Date?
    public let updatedAt: Date
    public let lastActivityAt: Date?
    public let lastUserMessageAt: Date?
    public let lastMeaningfulAgentAt: Date?
    public let lastFinalAnswerAt: Date?
    public let lastTerminalAt: Date?
    public let lastTerminalState: TerminalTurnState?
    public let lastViewedAt: Date?
    public let checkpoint: String
    public let historyComplete: Bool

    public init(
        id: String,
        title: String,
        projectName: String,
        cwd: String,
        rolloutPath: String,
        executionState: ActivityExecutionState,
        attentionReason: ActivityAttentionReason?,
        goalStatus: ActivityGoalStatus?,
        goalUpdatedAt: Date?,
        createdAt: Date,
        startedAt: Date?,
        updatedAt: Date,
        lastActivityAt: Date?,
        lastUserMessageAt: Date?,
        lastMeaningfulAgentAt: Date?,
        lastFinalAnswerAt: Date?,
        lastTerminalAt: Date?,
        lastTerminalState: TerminalTurnState?,
        lastViewedAt: Date?,
        checkpoint: String,
        historyComplete: Bool
    ) {
        self.id = id
        self.title = title
        self.projectName = projectName
        self.cwd = cwd
        self.rolloutPath = rolloutPath
        self.executionState = executionState
        self.attentionReason = attentionReason
        self.goalStatus = goalStatus
        self.goalUpdatedAt = goalUpdatedAt
        self.createdAt = createdAt
        self.startedAt = startedAt
        self.updatedAt = updatedAt
        self.lastActivityAt = lastActivityAt
        self.lastUserMessageAt = lastUserMessageAt
        self.lastMeaningfulAgentAt = lastMeaningfulAgentAt
        self.lastFinalAnswerAt = lastFinalAnswerAt
        self.lastTerminalAt = lastTerminalAt
        self.lastTerminalState = lastTerminalState
        self.lastViewedAt = lastViewedAt
        self.checkpoint = checkpoint
        self.historyComplete = historyComplete
    }

    public var needsAttention: Bool {
        attentionReason != nil
    }

    public var isRecentlyActive: Bool {
        executionState == .recentlyActive
    }

    public var timelineActivityAt: Date {
        [
            lastUserMessageAt,
            lastMeaningfulAgentAt,
            lastFinalAnswerAt,
            lastTerminalAt
        ]
        .compactMap { $0 }
        .max() ?? updatedAt
    }

    public var codexDeepLink: URL? {
        CodexDeepLink.threadURL(for: id)
    }
}

public struct ActivitySnapshot: Codable, Sendable {
    public let generatedAt: Date
    public let items: [ActivityItem]
    public let hasMore: Bool

    public init(
        generatedAt: Date,
        items: [ActivityItem],
        hasMore: Bool = false
    ) {
        self.generatedAt = generatedAt
        self.items = items
        self.hasMore = hasMore
    }
}

public enum ActivityReaderError: LocalizedError {
    case missingCodexState(String)
    case sqliteOpen(path: String, message: String)
    case sqliteQuery(message: String)
    case incompatibleSchema(String)

    public var errorDescription: String? {
        switch self {
        case .missingCodexState(let path):
            let filename = URL(fileURLWithPath: path).lastPathComponent
            return "Codex yerel durum dosyası bulunamadı (~/.codex/\(filename)). Önce Codex’i açıp en az bir görev oluştur."
        case .sqliteOpen(let path, let message):
            let filename = URL(fileURLWithPath: path).lastPathComponent
            return "Codex veritabanı salt-okunur açılamadı (~/.codex/\(filename)): \(message)"
        case .sqliteQuery(let message):
            return "Codex verisi okunamadı: \(message)"
        case .incompatibleSchema(let message):
            return "Codex veri şeması beklenenden farklı: \(message)"
        }
    }
}
