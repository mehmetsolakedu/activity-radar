import Foundation
import SQLite3

public final class CodexActivityReader: @unchecked Sendable {
    private struct ThreadRow {
        let id: String
        let title: String
        let preview: String
        let cwd: String
        let rolloutPath: String
        let createdAt: Date
        let updatedAt: Date
    }

    private struct ThreadPage {
        let rows: [ThreadRow]
        let hasMore: Bool
    }

    private struct GoalRecord {
        let status: ActivityGoalStatus
        let updatedAt: Date
    }

    private struct RolloutCacheEntry {
        var fileSize: UInt64
        var modifiedAt: Date
        var processedOffset: UInt64
        var carry: Data
        var reducer: RolloutReducer
    }

    private struct SessionNameEntry: Decodable {
        let id: String
        let thread_name: String
    }

    private let codexDirectory: URL
    private let stateDatabaseURL: URL
    private let goalsDatabaseURL: URL
    private let sessionIndexURL: URL
    private let initialRolloutReadLimit: UInt64 = 4 * 1_024 * 1_024
    private let loadLock = NSLock()
    private var rolloutCache: [String: RolloutCacheEntry] = [:]
    private var cachedSessionNames: [String: String] = [:]
    private var cachedSessionIndexSignature: String?

    public init(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) {
        codexDirectory = homeDirectory.appendingPathComponent(".codex", isDirectory: true)
        stateDatabaseURL = codexDirectory.appendingPathComponent("state_5.sqlite")
        goalsDatabaseURL = codexDirectory.appendingPathComponent("goals_1.sqlite")
        sessionIndexURL = codexDirectory.appendingPathComponent("session_index.jsonl")
    }

    public func load(
        limit: Int = 48,
        now: Date = Date(),
        lastViewedAt: [String: Date] = [:],
        priorityThreadIDs: Set<String> = [],
        unviewedResultsAfter: Date? = nil,
        updatedAfter: Date? = nil
    ) throws -> ActivitySnapshot {
        loadLock.lock()
        defer { loadLock.unlock() }

        guard FileManager.default.fileExists(atPath: stateDatabaseURL.path) else {
            throw ActivityReaderError.missingCodexState(stateDatabaseURL.path)
        }

        let goalRecords = try readGoalRecords()
        let includedGoalIDs = Set(
            goalRecords.compactMap { threadID, record in
                switch record.status {
                case .active, .blocked, .usageLimited, .budgetLimited:
                    return threadID
                case .paused, .complete, .unknown:
                    return nil
                }
            }
        )
        let threadPage = try readThreads(
            limit: limit,
            includedThreadIDs: priorityThreadIDs.union(includedGoalIDs),
            updatedAfter: updatedAfter
        )
        let sessionNames = readSessionNames()

        return makeSnapshot(
            threadRows: threadPage.rows,
            goalRecords: goalRecords,
            sessionNames: sessionNames,
            now: now,
            lastViewedAt: lastViewedAt,
            unviewedResultsAfter: unviewedResultsAfter,
            hasMore: threadPage.hasMore
        )
    }

    public func search(
        query: String,
        limit: Int = 48,
        now: Date = Date(),
        lastViewedAt: [String: Date] = [:],
        unviewedResultsAfter: Date? = nil,
        updatedAfter: Date? = nil
    ) throws -> ActivitySnapshot {
        loadLock.lock()
        defer { loadLock.unlock() }

        guard FileManager.default.fileExists(atPath: stateDatabaseURL.path) else {
            throw ActivityReaderError.missingCodexState(stateDatabaseURL.path)
        }

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ActivitySnapshot(generatedAt: now, items: [])
        }

        let goalRecords = try readGoalRecords()
        let sessionNames = readSessionNames()
        let normalized = Self.normalizedSearchText(trimmed)
        let matchingSessionIDs = Set(
            sessionNames.compactMap { threadID, name in
                Self.normalizedSearchText(name).contains(normalized) ? threadID : nil
            }
            .prefix(max(1, min(limit, 200)))
        )
        let threadPage = try readMatchingThreads(
            query: trimmed,
            limit: limit,
            includedThreadIDs: matchingSessionIDs,
            updatedAfter: updatedAfter
        )

        return makeSnapshot(
            threadRows: threadPage.rows,
            goalRecords: goalRecords,
            sessionNames: sessionNames,
            now: now,
            lastViewedAt: lastViewedAt,
            unviewedResultsAfter: unviewedResultsAfter,
            hasMore: threadPage.hasMore
        )
    }

    private func makeSnapshot(
        threadRows: [ThreadRow],
        goalRecords: [String: GoalRecord],
        sessionNames: [String: String],
        now: Date,
        lastViewedAt: [String: Date],
        unviewedResultsAfter: Date?,
        hasMore: Bool
    ) -> ActivitySnapshot {
        let items = threadRows.map { thread -> ActivityItem in
            let summary = readRollout(path: thread.rolloutPath)
            let goal = goalRecords[thread.id]
            let viewedAt = lastViewedAt[thread.id]
            let attention = ActivityAttentionPolicy.reason(
                summary: summary,
                goalStatus: goal?.status,
                viewedAt: viewedAt,
                unviewedResultsAfter: unviewedResultsAfter,
                now: now
            )
            let state = executionState(
                summary: summary,
                attention: attention,
                now: now
            )
            let displayTitle = makeDisplayTitle(
                sessionName: sessionNames[thread.id],
                stateTitle: thread.title,
                preview: thread.preview
            )

            return ActivityItem(
                id: thread.id,
                title: displayTitle,
                projectName: makeProjectName(cwd: thread.cwd),
                cwd: thread.cwd,
                rolloutPath: thread.rolloutPath,
                executionState: state,
                attentionReason: attention,
                goalStatus: goal?.status,
                goalUpdatedAt: goal?.updatedAt,
                createdAt: thread.createdAt,
                startedAt: summary.earliestOpenTurnAt,
                updatedAt: thread.updatedAt,
                lastActivityAt: summary.lastActivityAt,
                lastUserMessageAt: summary.lastUserMessageAt,
                lastMeaningfulAgentAt: summary.lastMeaningfulAgentAt,
                lastFinalAnswerAt: summary.lastFinalAnswerAt,
                lastTerminalAt: summary.lastTerminalAt,
                lastTerminalState: summary.lastTerminalState,
                lastViewedAt: viewedAt,
                checkpoint: summary.checkpoint ?? "Henüz gösterilecek anlamlı bir ajan özeti yok.",
                historyComplete: summary.historyComplete
            )
        }
        .sorted(by: sortItems)

        return ActivitySnapshot(generatedAt: now, items: items, hasMore: hasMore)
    }

    public static func deepLink(for threadID: String) -> URL? {
        URL(string: "codex://threads/\(threadID)")
    }

    private func readThreads(
        limit: Int,
        includedThreadIDs: Set<String>,
        updatedAfter: Date?
    ) throws -> ThreadPage {
        let database = try SQLiteReadOnly(path: stateDatabaseURL.path)
        let required = Set([
            "id", "title", "preview", "cwd", "rollout_path",
            "created_at", "updated_at", "created_at_ms", "updated_at_ms",
            "archived", "thread_source", "recency_at_ms"
        ])
        let actual = try database.tableColumns("threads")
        let missing = required.subtracting(actual)
        guard missing.isEmpty else {
            throw ActivityReaderError.incompatibleSchema(
                "threads tablosunda eksik alanlar: \(missing.sorted().joined(separator: ", "))"
            )
        }

        var rows: [ThreadRow] = []
        var seen = Set<String>()
        func appendRow(_ statement: OpaquePointer) {
            let id = SQLiteReadOnly.text(statement, index: 0)
            guard seen.insert(id).inserted else { return }
            let createdAt = Date(timeIntervalSince1970: Double(SQLiteReadOnly.int64(statement, index: 5)) / 1_000)
            let updatedAt = Date(timeIntervalSince1970: Double(SQLiteReadOnly.int64(statement, index: 6)) / 1_000)
            rows.append(
                ThreadRow(
                    id: id,
                    title: SQLiteReadOnly.text(statement, index: 1),
                    preview: SQLiteReadOnly.text(statement, index: 2),
                    cwd: SQLiteReadOnly.text(statement, index: 3),
                    rolloutPath: SQLiteReadOnly.text(statement, index: 4),
                    createdAt: createdAt,
                    updatedAt: updatedAt
                )
            )
        }

        let cutoffClause = updatedAfter == nil
            ? ""
            : """
            AND MAX(
                COALESCE(NULLIF(t.recency_at_ms, 0), 0),
                COALESCE(NULLIF(t.updated_at_ms, 0), t.updated_at * 1000, 0)
            ) >= ?
            """
        let sql = """
        SELECT
            t.id,
            t.title,
            t.preview,
            t.cwd,
            t.rollout_path,
            COALESCE(t.created_at_ms, t.created_at * 1000),
            COALESCE(t.updated_at_ms, t.updated_at * 1000)
        FROM threads AS t
        WHERE t.archived = 0
          AND t.preview <> ''
          AND (t.thread_source = 'user' OR t.thread_source = '' OR t.thread_source IS NULL)
          AND NOT EXISTS (
              SELECT 1 FROM thread_spawn_edges AS edge
              WHERE edge.child_thread_id = t.id
          )
          \(cutoffClause)
        ORDER BY MAX(
            COALESCE(NULLIF(t.recency_at_ms, 0), 0),
            COALESCE(NULLIF(t.updated_at_ms, 0), t.updated_at * 1000, 0)
        ) DESC
        LIMIT ?;
        """

        let pageLimit = max(1, min(limit, 200))
        try database.rows(
            sql: sql,
            bind: { statement in
                var index: Int32 = 1
                if let updatedAfter {
                    sqlite3_bind_int64(
                        statement,
                        index,
                        Int64(updatedAfter.timeIntervalSince1970 * 1_000)
                    )
                    index += 1
                }
                sqlite3_bind_int(statement, index, Int32(pageLimit + 1))
            }
        ) { statement in
            appendRow(statement)
        }

        let hasMore = rows.count > pageLimit
        if hasMore {
            rows = Array(rows.prefix(pageLimit))
            seen = Set(rows.map(\.id))
        }

        let requiredIDs = includedThreadIDs.subtracting(seen)
        let requiredSQL = """
        SELECT
            t.id,
            t.title,
            t.preview,
            t.cwd,
            t.rollout_path,
            COALESCE(t.created_at_ms, t.created_at * 1000),
            COALESCE(t.updated_at_ms, t.updated_at * 1000)
        FROM threads AS t
        WHERE t.id = ?
          AND t.archived = 0
          AND t.preview <> ''
          AND (t.thread_source = 'user' OR t.thread_source = '' OR t.thread_source IS NULL)
          AND NOT EXISTS (
              SELECT 1 FROM thread_spawn_edges AS edge
              WHERE edge.child_thread_id = t.id
          )
        LIMIT 1;
        """
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        for threadID in requiredIDs.sorted() {
            try database.rows(
                sql: requiredSQL,
                bind: { statement in
                    threadID.withCString { pointer in
                        _ = sqlite3_bind_text(statement, 1, pointer, -1, transient)
                    }
                }
            ) { statement in
                appendRow(statement)
            }
        }
        return ThreadPage(rows: rows, hasMore: hasMore)
    }

    private func readMatchingThreads(
        query: String,
        limit: Int,
        includedThreadIDs: Set<String>,
        updatedAfter: Date?
    ) throws -> ThreadPage {
        let database = try SQLiteReadOnly(path: stateDatabaseURL.path)
        let required = Set([
            "id", "title", "preview", "cwd", "rollout_path",
            "created_at", "updated_at", "created_at_ms", "updated_at_ms",
            "archived", "thread_source", "recency_at_ms"
        ])
        let actual = try database.tableColumns("threads")
        let missing = required.subtracting(actual)
        guard missing.isEmpty else {
            throw ActivityReaderError.incompatibleSchema(
                "threads tablosunda eksik alanlar: \(missing.sorted().joined(separator: ", "))"
            )
        }

        var rows: [ThreadRow] = []
        var seen = Set<String>()
        func appendRow(_ statement: OpaquePointer) {
            let id = SQLiteReadOnly.text(statement, index: 0)
            guard seen.insert(id).inserted else { return }
            rows.append(
                ThreadRow(
                    id: id,
                    title: SQLiteReadOnly.text(statement, index: 1),
                    preview: SQLiteReadOnly.text(statement, index: 2),
                    cwd: SQLiteReadOnly.text(statement, index: 3),
                    rolloutPath: SQLiteReadOnly.text(statement, index: 4),
                    createdAt: Date(
                        timeIntervalSince1970:
                            Double(SQLiteReadOnly.int64(statement, index: 5)) / 1_000
                    ),
                    updatedAt: Date(
                        timeIntervalSince1970:
                            Double(SQLiteReadOnly.int64(statement, index: 6)) / 1_000
                    )
                )
            )
        }

        let cutoffClause = updatedAfter == nil
            ? ""
            : """
            AND MAX(
                COALESCE(NULLIF(t.recency_at_ms, 0), 0),
                COALESCE(NULLIF(t.updated_at_ms, 0), t.updated_at * 1000, 0)
            ) >= ?
            """
        let sql = """
        SELECT
            t.id,
            t.title,
            t.preview,
            t.cwd,
            t.rollout_path,
            COALESCE(t.created_at_ms, t.created_at * 1000),
            COALESCE(t.updated_at_ms, t.updated_at * 1000)
        FROM threads AS t
        WHERE t.archived = 0
          AND t.preview <> ''
          AND (t.thread_source = 'user' OR t.thread_source = '' OR t.thread_source IS NULL)
          AND NOT EXISTS (
              SELECT 1 FROM thread_spawn_edges AS edge
              WHERE edge.child_thread_id = t.id
          )
          AND (
              t.title LIKE ? COLLATE NOCASE
              OR t.preview LIKE ? COLLATE NOCASE
              OR t.cwd LIKE ? COLLATE NOCASE
          )
          \(cutoffClause)
        ORDER BY MAX(
            COALESCE(NULLIF(t.recency_at_ms, 0), 0),
            COALESCE(NULLIF(t.updated_at_ms, 0), t.updated_at * 1000, 0)
        ) DESC
        LIMIT ?;
        """
        let pattern = "%\(query)%"
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        let pageLimit = max(1, min(limit, 200))
        try database.rows(
            sql: sql,
            bind: { statement in
                for index in 1...3 {
                    pattern.withCString { pointer in
                        _ = sqlite3_bind_text(statement, Int32(index), pointer, -1, transient)
                    }
                }
                var index: Int32 = 4
                if let updatedAfter {
                    sqlite3_bind_int64(
                        statement,
                        index,
                        Int64(updatedAfter.timeIntervalSince1970 * 1_000)
                    )
                    index += 1
                }
                sqlite3_bind_int(statement, index, Int32(pageLimit + 1))
            }
        ) { statement in
            appendRow(statement)
        }

        let hasMore = rows.count > pageLimit
        if hasMore {
            rows = Array(rows.prefix(pageLimit))
            seen = Set(rows.map(\.id))
        }

        let requiredSQL = """
        SELECT
            t.id,
            t.title,
            t.preview,
            t.cwd,
            t.rollout_path,
            COALESCE(t.created_at_ms, t.created_at * 1000),
            COALESCE(t.updated_at_ms, t.updated_at * 1000)
        FROM threads AS t
        WHERE t.id = ?
          AND t.archived = 0
          AND t.preview <> ''
          AND (t.thread_source = 'user' OR t.thread_source = '' OR t.thread_source IS NULL)
          AND NOT EXISTS (
              SELECT 1 FROM thread_spawn_edges AS edge
              WHERE edge.child_thread_id = t.id
          )
        LIMIT 1;
        """
        for threadID in includedThreadIDs.subtracting(seen).sorted() {
            try database.rows(
                sql: requiredSQL,
                bind: { statement in
                    threadID.withCString { pointer in
                        _ = sqlite3_bind_text(statement, 1, pointer, -1, transient)
                    }
                }
            ) { statement in
                appendRow(statement)
            }
        }
        return ThreadPage(rows: rows, hasMore: hasMore)
    }

    private func readGoalRecords() throws -> [String: GoalRecord] {
        guard FileManager.default.fileExists(atPath: goalsDatabaseURL.path) else {
            return [:]
        }
        let database = try SQLiteReadOnly(path: goalsDatabaseURL.path)
        let columns = try database.tableColumns("thread_goals")
        guard columns.contains("thread_id"),
              columns.contains("status"),
              columns.contains("updated_at_ms") else {
            throw ActivityReaderError.incompatibleSchema("thread_goals alanları eksik")
        }

        var records: [String: GoalRecord] = [:]
        try database.rows(sql: "SELECT thread_id, status, updated_at_ms FROM thread_goals;") { statement in
            let threadID = SQLiteReadOnly.text(statement, index: 0)
            let rawStatus = SQLiteReadOnly.text(statement, index: 1)
            let status = ActivityGoalStatus(rawValue: rawStatus) ?? .unknown
            let updatedAt = Date(
                timeIntervalSince1970: Double(SQLiteReadOnly.int64(statement, index: 2)) / 1_000
            )
            records[threadID] = GoalRecord(status: status, updatedAt: updatedAt)
        }
        return records
    }

    private func readSessionNames() -> [String: String] {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: sessionIndexURL.path),
              let size = attributes[.size] as? NSNumber,
              let modifiedAt = attributes[.modificationDate] as? Date else {
            return cachedSessionNames
        }

        let signature = "\(size.uint64Value)-\(modifiedAt.timeIntervalSince1970)"
        if signature == cachedSessionIndexSignature {
            return cachedSessionNames
        }

        guard let data = try? Data(contentsOf: sessionIndexURL) else {
            return cachedSessionNames
        }

        var names: [String: String] = [:]
        let decoder = JSONDecoder()
        for line in data.split(separator: 0x0A) where !line.isEmpty {
            guard let entry = try? decoder.decode(SessionNameEntry.self, from: Data(line)) else {
                continue
            }
            let trimmed = entry.thread_name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                names[entry.id] = trimmed
            }
        }

        cachedSessionNames = names
        cachedSessionIndexSignature = signature
        return names
    }

    private func readRollout(path: String) -> RolloutSummary {
        guard !path.isEmpty,
              let attributes = try? FileManager.default.attributesOfItem(atPath: path),
              let sizeNumber = attributes[.size] as? NSNumber,
              let modifiedAt = attributes[.modificationDate] as? Date else {
            var summary = RolloutSummary()
            summary.historyComplete = false
            return summary
        }

        let fileSize = sizeNumber.uint64Value
        if let cached = rolloutCache[path],
           cached.fileSize == fileSize,
           cached.modifiedAt == modifiedAt {
            return cached.reducer.summary
        } else if var cached = rolloutCache[path],
                  fileSize >= cached.processedOffset,
                  fileSize - cached.processedOffset <= 8 * 1_024 * 1_024,
                  let newData = readFile(path: path, offset: cached.processedOffset) {
            consume(data: cached.carry + newData, into: &cached)
            cached.fileSize = fileSize
            cached.modifiedAt = modifiedAt
            cached.processedOffset = fileSize
            rolloutCache[path] = cached
            return cached.reducer.summary
        }

        let startOffset = fileSize > initialRolloutReadLimit ? fileSize - initialRolloutReadLimit : 0
        guard var data = readFile(path: path, offset: startOffset) else {
            var summary = RolloutSummary()
            summary.historyComplete = false
            return summary
        }

        var reducer = RolloutReducer()
        if startOffset > 0 {
            reducer.markHistoryIncomplete()
            if let firstNewline = data.firstIndex(of: 0x0A) {
                data = Data(data[data.index(after: firstNewline)...])
            } else {
                data = Data()
            }
        }

        var entry = RolloutCacheEntry(
            fileSize: fileSize,
            modifiedAt: modifiedAt,
            processedOffset: fileSize,
            carry: Data(),
            reducer: reducer
        )
        consume(data: data, into: &entry)
        rolloutCache[path] = entry
        return entry.reducer.summary
    }

    private func readFile(path: String, offset: UInt64) -> Data? {
        guard let handle = try? FileHandle(forReadingFrom: URL(fileURLWithPath: path)) else {
            return nil
        }
        defer { try? handle.close() }
        do {
            try handle.seek(toOffset: offset)
            return try handle.readToEnd() ?? Data()
        } catch {
            return nil
        }
    }

    private func consume(data: Data, into entry: inout RolloutCacheEntry) {
        guard !data.isEmpty else {
            entry.carry = Data()
            return
        }

        var segments = data.split(separator: 0x0A, omittingEmptySubsequences: false)
        let endsWithNewline = data.last == 0x0A
        if !endsWithNewline, let trailing = segments.popLast() {
            entry.carry = Data(trailing)
        } else {
            entry.carry = Data()
        }

        for segment in segments where !segment.isEmpty {
            entry.reducer.consume(line: Data(segment))
        }
    }

    private func executionState(
        summary: RolloutSummary,
        attention: ActivityAttentionReason?,
        now: Date
    ) -> ActivityExecutionState {
        if !summary.openTurns.isEmpty {
            guard let heartbeat = summary.lastActivityAt else {
                return .openSilent
            }
            let age = now.timeIntervalSince(heartbeat)
            return age >= 0 && age <= 120 ? .recentlyActive : .openSilent
        }
        if summary.lastTerminalState == .completed {
            return .completed
        }
        if summary.lastTerminalState == .aborted {
            return .aborted
        }
        if attention != nil {
            return .idle
        }
        return summary.historyComplete ? .idle : .unknown
    }

    private func makeDisplayTitle(sessionName: String?, stateTitle: String, preview: String) -> String {
        let preferred = sessionName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = stateTitle.hasPrefix("/goal") ? preview : stateTitle
        var text = (preferred?.isEmpty == false ? preferred! : fallback)
            .split(whereSeparator: \.isNewline)
            .first
            .map(String.init) ?? "Adsız görev"
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.count > 78 {
            let end = text.index(text.startIndex, offsetBy: 75)
            text = String(text[..<end]) + "…"
        }
        return text.isEmpty ? "Adsız görev" : text
    }

    private func makeProjectName(cwd: String) -> String {
        let component = URL(fileURLWithPath: cwd).lastPathComponent
        return component.isEmpty ? "Codex" : component
    }

    private static func normalizedSearchText(_ value: String) -> String {
        value.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: Locale(identifier: "tr_TR")
        )
    }

    private func sortItems(_ left: ActivityItem, _ right: ActivityItem) -> Bool {
        let leftRank = sortRank(left)
        let rightRank = sortRank(right)
        if leftRank != rightRank {
            return leftRank < rightRank
        }
        let leftDate = sortDate(left)
        let rightDate = sortDate(right)
        if leftDate != rightDate {
            return leftDate > rightDate
        }
        return left.id < right.id
    }

    private func sortRank(_ item: ActivityItem) -> Int {
        switch item.attentionReason {
        case .explicitInput:
            return 0
        case .goalBlocked:
            return 1
        case .newSinceView:
            return 2
        case .usageLimited, .budgetLimited:
            return 3
        case nil:
            break
        }
        switch item.executionState {
        case .recentlyActive:
            return 4
        case .openSilent:
            return 5
        case .completed:
            return 6
        case .aborted:
            return 7
        case .idle:
            return 8
        case .unknown:
            return 9
        }
    }

    private func sortDate(_ item: ActivityItem) -> Date {
        switch item.attentionReason {
        case .goalBlocked, .usageLimited, .budgetLimited:
            return item.goalUpdatedAt ?? item.lastActivityAt ?? item.updatedAt
        case .newSinceView:
            return item.lastFinalAnswerAt ?? item.lastActivityAt ?? item.updatedAt
        case .explicitInput:
            return item.lastActivityAt ?? item.updatedAt
        case nil:
            return item.lastMeaningfulAgentAt ?? item.lastActivityAt ?? item.updatedAt
        }
    }
}
