import Foundation
import SQLite3

public enum WingmanEvidenceReaderError: LocalizedError {
    case incompatibleTaskGraph(String)

    public var errorDescription: String? {
        switch self {
        case .incompatibleTaskGraph(let detail):
            return "Codex görev ağacı güvenle çözümlenemedi: \(detail)"
        }
    }
}

public final class CodexWingmanEvidenceReader: @unchecked Sendable {
    private static let maximumThreadRecords = 50_000
    private static let maximumSpawnEdges = 100_000
    private static let maximumThreadTextBytes = 64 * 1_024 * 1_024
    private static let maximumEdgeTextBytes = 32 * 1_024 * 1_024

    private struct SpawnEdge: Hashable {
        let parent: String
        let child: String
    }

    private struct GraphVisitFrame {
        let id: String
        var nextChildIndex: Int
    }

    private struct ThreadRecord {
        let id: String
        let source: String
        let title: String
        let firstUserMessage: String
        let cwd: String
        let rolloutPath: String
        let createdAt: Date
        let updatedAt: Date
        let tokensUsed: Int64
        let archived: Bool
    }

    private struct MutablePrompt {
        let text: String
        let occurredAt: Date?
        let isExplicitQuestion: Bool
        let isInvestigationRequest: Bool
        var responseRecorded = false
        var continuedAfterResponse = false
    }

    private struct OpenTurn {
        var lastMeasuredUsage: Int64?
    }

    private struct TailSummary {
        var fileAvailable = false
        var coverage: WingmanEvidenceCoverage = .unavailable
        var scannedBytes: Int64 = 0
        var totalBytes: Int64 = 0
        var activeBuckets = Set<Int64>()
        var activeDays = Set<Int64>()
        var prompts: [MutablePrompt] = []
        var userMessageCount = 0
        var meaningfulAgentMessageCount = 0
        var toolCallCount = 0
        var completedTurnCount = 0
        var abortedTurnCount = 0
        var measuredAbortedTurnTokens: Int64 = 0
        var openTurns: [String: OpenTurn] = [:]
        var latestTokenBreakdown: WingmanTokenUsage?
        var lastPromptFingerprint: String?
        var lastPromptAt: Date?

        var promptEvidence: [WingmanPromptEvidence] {
            prompts.map { prompt in
                let state: WingmanPromptResponseState
                if prompt.continuedAfterResponse {
                    state = .continuedAfterResponse
                } else if prompt.responseRecorded {
                    state = .responseRecorded
                } else {
                    state = .noRecordedResponse
                }
                return WingmanPromptEvidence(
                    text: prompt.text,
                    occurredAt: prompt.occurredAt,
                    isExplicitQuestion: prompt.isExplicitQuestion,
                    isInvestigationRequest: prompt.isInvestigationRequest,
                    responseState: state
                )
            }
        }
    }

    private struct TreeTailSummary {
        let root: TailSummary
        let aggregate: TailSummary
    }

    private let codexDirectory: URL
    private let stateDatabaseURL: URL
    private let safeFiles: CodexSafeFileAccess
    private let perRolloutTailLimit: Int64

    public init(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        perRolloutTailLimit: Int64 = 4 * 1_024 * 1_024
    ) {
        let codexDirectory = homeDirectory.appendingPathComponent(".codex", isDirectory: true)
        self.codexDirectory = codexDirectory
        stateDatabaseURL = codexDirectory.appendingPathComponent("state_5.sqlite")
        safeFiles = CodexSafeFileAccess(root: codexDirectory)
        self.perRolloutTailLimit = max(64 * 1_024, min(perRolloutTailLimit, 16 * 1_024 * 1_024))
    }

    public func load(
        limit: Int = 20,
        updatedAfter: Date? = nil,
        now: Date = Date()
    ) throws -> WingmanEvidenceSnapshot {
        guard FileManager.default.fileExists(atPath: stateDatabaseURL.path) else {
            throw ActivityReaderError.missingCodexState(stateDatabaseURL.path)
        }

        let database = try SQLiteReadOnly(path: stateDatabaseURL.path)
        let (records, edges) = try database.withReadTransaction {
            (try readThreads(database: database), try readEdges(database: database))
        }
        let graph = try makeGraph(records: records, edges: edges)
        let roots = records.values.filter { record in
            guard graph.parentByChild[record.id] == nil else { return false }
            guard record.source == "user" || record.source.isEmpty else { return false }
            return true
        }

        let candidates = roots.map { root -> (root: ThreadRecord, descendants: [(ThreadRecord, Int)], observedTokenProxy: Int64, latestActivity: Date) in
            let descendants = descendants(of: root.id, records: records, childrenByParent: graph.childrenByParent)
            // Spawned Codex rollouts inherit the same cumulative token-count lineage.
            // Adding every node therefore counts the shared prefix repeatedly. The
            // largest counter is a conservative, non-additive proxy for this tree;
            // it is not an exact billed or wasted-token total.
            let observedTokenProxy = descendants.reduce(root.tokensUsed) { largest, entry in
                max(largest, entry.0.tokensUsed)
            }
            let latestActivity = descendants.reduce(root.updatedAt) { latest, entry in
                max(latest, entry.0.updatedAt)
            }
            return (root, descendants, observedTokenProxy, latestActivity)
        }
        .filter { candidate in
            guard let updatedAfter else { return true }
            return candidate.latestActivity >= updatedAfter
        }
        .sorted { left, right in
            if left.observedTokenProxy != right.observedTokenProxy {
                return left.observedTokenProxy > right.observedTokenProxy
            }
            if left.descendants.count != right.descendants.count {
                return left.descendants.count > right.descendants.count
            }
            if left.latestActivity != right.latestActivity {
                return left.latestActivity > right.latestActivity
            }
            return left.root.id < right.root.id
        }

        let safeLimit = max(1, min(limit, 36))
        let selected = Array(candidates.prefix(safeLimit))
        let scopeTotal = candidates.reduce(Int64(0)) {
            Self.clampedAdd($0, $1.observedTokenProxy)
        }

        let tasks = selected.enumerated().map { index, candidate in
            let root = candidate.root
            let treeTail = scanRolloutTree(root: root, descendants: candidate.descendants)
            let rootTail = treeTail.root
            let tail = treeTail.aggregate
            let directUsage: WingmanTokenUsage
            if let breakdown = rootTail.latestTokenBreakdown,
               breakdown.total == root.tokensUsed {
                directUsage = breakdown
            } else {
                directUsage = WingmanTokenUsage(
                    source: .sqliteMeasuredTotal,
                    total: root.tokensUsed
                )
            }

            let sanitizedInitial = Self.sanitizedInitialPrompt(root.firstUserMessage, limit: 1_000)
            var promptSamples = rootTail.promptEvidence
            if let sanitizedInitial,
               !promptSamples.contains(where: { Self.promptFingerprint($0.text) == Self.promptFingerprint(sanitizedInitial) }) {
                let initialState: WingmanPromptResponseState
                if rootTail.coverage != .complete {
                    initialState = .unknown
                } else if rootTail.meaningfulAgentMessageCount == 0 {
                    initialState = .noRecordedResponse
                } else if rootTail.userMessageCount > 1 {
                    initialState = .continuedAfterResponse
                } else {
                    initialState = .responseRecorded
                }
                promptSamples.insert(
                    WingmanPromptEvidence(
                        text: sanitizedInitial,
                        occurredAt: root.createdAt,
                        isExplicitQuestion: Self.isExplicitQuestion(sanitizedInitial),
                        isInvestigationRequest: Self.isInvestigationRequest(sanitizedInitial),
                        responseState: initialState
                    ),
                    at: 0
                )
            }
            promptSamples = Self.boundedPromptSamples(promptSamples, limit: 12)

            let branchEvidence = candidate.descendants
                .sorted { left, right in
                    if left.0.tokensUsed != right.0.tokensUsed {
                        return left.0.tokensUsed > right.0.tokensUsed
                    }
                    return left.0.id < right.0.id
                }
                .compactMap { entry -> String? in
                    let combined = [entry.0.title, entry.0.firstUserMessage]
                        .filter { !$0.isEmpty }
                        .joined(separator: " — ")
                    return Self.sanitizeHumanText(combined, limit: 420)
                }
                .prefix(16)

            return WingmanTaskEvidence(
                id: String(format: "W%03d", index + 1),
                title: Self.taskDisplayTitle(root.title),
                projectLabel: Self.projectLabel(for: root.cwd),
                createdAt: root.createdAt,
                updatedAt: root.updatedAt,
                archived: root.archived,
                directTokenUsage: directUsage,
                recursiveTokenTotal: candidate.observedTokenProxy,
                childCount: candidate.descendants.count,
                maximumBranchDepth: candidate.descendants.map(\.1).max() ?? 0,
                branchEvidence: Array(branchEvidence),
                initialPrompt: sanitizedInitial,
                promptSamples: promptSamples,
                rolloutCoverage: tail.coverage,
                scannedRolloutBytes: tail.scannedBytes,
                totalRolloutBytes: tail.totalBytes,
                activeBucketCountLowerBound: tail.activeBuckets.count,
                activeDayCountLowerBound: tail.activeDays.count,
                userMessageCountLowerBound: tail.userMessageCount,
                meaningfulAgentMessageCountLowerBound: tail.meaningfulAgentMessageCount,
                toolCallCountLowerBound: tail.toolCallCount,
                completedTurnCountLowerBound: tail.completedTurnCount,
                abortedTurnCountLowerBound: tail.abortedTurnCount,
                measuredAbortedTurnTokensLowerBound: tail.measuredAbortedTurnTokens,
                hasObservedOpenTurn: !tail.openTurns.isEmpty
            )
        }

        return WingmanEvidenceSnapshot(
            generatedAt: now,
            taskActivityCutoff: updatedAfter,
            candidateTaskCount: candidates.count,
            lifetimeTokenTotalForScopedTasks: scopeTotal,
            tasks: tasks,
            omittedTaskCount: max(0, candidates.count - tasks.count)
        )
    }

    private func readThreads(database: SQLiteReadOnly) throws -> [String: ThreadRecord] {
        let required = Set([
            "id", "thread_source", "title", "first_user_message", "cwd", "rollout_path",
            "created_at", "updated_at", "created_at_ms", "updated_at_ms", "tokens_used", "archived"
        ])
        let actual = try database.tableColumns("threads")
        let missing = required.subtracting(actual)
        guard missing.isEmpty else {
            throw ActivityReaderError.incompatibleSchema(
                "Wingman analizi için eksik threads alanları: \(missing.sorted().joined(separator: ", "))"
            )
        }

        var records: [String: ThreadRecord] = [:]
        var rowCount = 0
        var totalTextBytes = 0
        try database.rows(
            sql: """
            SELECT
              id,
              COALESCE(thread_source, ''),
              COALESCE(title, ''),
              COALESCE(first_user_message, ''),
              COALESCE(cwd, ''),
              COALESCE(rollout_path, ''),
              COALESCE(created_at_ms, created_at * 1000),
              COALESCE(updated_at_ms, updated_at * 1000),
              COALESCE(tokens_used, 0),
              COALESCE(archived, 0)
            FROM threads;
            """
        ) { statement in
            rowCount += 1
            guard rowCount <= Self.maximumThreadRecords else {
                throw WingmanEvidenceReaderError.incompatibleTaskGraph("görev düğümü sınırı aşıldı")
            }

            let limits = [1_024, 128, 16 * 1_024, 64 * 1_024, 16 * 1_024, 16 * 1_024]
            var rowBytes = 0
            for (index, maximum) in limits.enumerated() {
                let count = SQLiteReadOnly.byteCount(statement, index: Int32(index))
                guard count <= maximum else {
                    throw WingmanEvidenceReaderError.incompatibleTaskGraph("görev metni sınırı aşıldı")
                }
                rowBytes += count
            }
            guard totalTextBytes <= Self.maximumThreadTextBytes - rowBytes else {
                throw WingmanEvidenceReaderError.incompatibleTaskGraph("toplam görev metni sınırı aşıldı")
            }
            totalTextBytes += rowBytes

            let id = SQLiteReadOnly.text(statement, index: 0)
            guard !id.isEmpty else { return }
            guard records[id] == nil else {
                throw WingmanEvidenceReaderError.incompatibleTaskGraph("yinelenen görev kimliği")
            }
            records[id] = ThreadRecord(
                id: id,
                source: SQLiteReadOnly.text(statement, index: 1),
                title: SQLiteReadOnly.text(statement, index: 2),
                firstUserMessage: SQLiteReadOnly.text(statement, index: 3),
                cwd: SQLiteReadOnly.text(statement, index: 4),
                rolloutPath: SQLiteReadOnly.text(statement, index: 5),
                createdAt: Date(
                    timeIntervalSince1970: Double(SQLiteReadOnly.int64(statement, index: 6)) / 1_000
                ),
                updatedAt: Date(
                    timeIntervalSince1970: Double(SQLiteReadOnly.int64(statement, index: 7)) / 1_000
                ),
                tokensUsed: max(0, SQLiteReadOnly.int64(statement, index: 8)),
                archived: SQLiteReadOnly.int64(statement, index: 9) != 0
            )
        }
        return records
    }

    private func readEdges(database: SQLiteReadOnly) throws -> [(parent: String, child: String)] {
        let required = Set(["parent_thread_id", "child_thread_id"])
        let actual = try database.tableColumns("thread_spawn_edges")
        let missing = required.subtracting(actual)
        guard missing.isEmpty else {
            throw ActivityReaderError.incompatibleSchema(
                "Wingman analizi için eksik thread_spawn_edges alanları: \(missing.sorted().joined(separator: ", "))"
            )
        }
        var edges: [(String, String)] = []
        var rowCount = 0
        var totalTextBytes = 0
        try database.rows(
            sql: "SELECT parent_thread_id, child_thread_id FROM thread_spawn_edges;"
        ) { statement in
            rowCount += 1
            guard rowCount <= Self.maximumSpawnEdges else {
                throw WingmanEvidenceReaderError.incompatibleTaskGraph("görev bağlantısı sınırı aşıldı")
            }
            let parentBytes = SQLiteReadOnly.byteCount(statement, index: 0)
            let childBytes = SQLiteReadOnly.byteCount(statement, index: 1)
            guard parentBytes <= 1_024, childBytes <= 1_024 else {
                throw WingmanEvidenceReaderError.incompatibleTaskGraph("görev bağlantısı metni sınırı aşıldı")
            }
            let rowBytes = parentBytes + childBytes
            guard totalTextBytes <= Self.maximumEdgeTextBytes - rowBytes else {
                throw WingmanEvidenceReaderError.incompatibleTaskGraph("toplam görev bağlantısı metni sınırı aşıldı")
            }
            totalTextBytes += rowBytes

            let parent = SQLiteReadOnly.text(statement, index: 0)
            let child = SQLiteReadOnly.text(statement, index: 1)
            guard !parent.isEmpty, !child.isEmpty else {
                throw WingmanEvidenceReaderError.incompatibleTaskGraph("boş görev bağlantısı ucu")
            }
            edges.append((parent, child))
        }
        return edges
    }

    private func makeGraph(
        records: [String: ThreadRecord],
        edges: [(parent: String, child: String)]
    ) throws -> (parentByChild: [String: String], childrenByParent: [String: [String]]) {
        var parentByChild: [String: String] = [:]
        var childrenByParent: [String: [String]] = [:]
        var seenEdges = Set<SpawnEdge>()
        for edge in edges {
            guard records[edge.parent] != nil, records[edge.child] != nil else {
                throw WingmanEvidenceReaderError.incompatibleTaskGraph("eksik görev düğümü")
            }
            guard seenEdges.insert(SpawnEdge(parent: edge.parent, child: edge.child)).inserted else {
                continue
            }
            if let existing = parentByChild[edge.child], existing != edge.parent {
                throw WingmanEvidenceReaderError.incompatibleTaskGraph("bir alt görevin birden çok üst görevi var")
            }
            parentByChild[edge.child] = edge.parent
            childrenByParent[edge.parent, default: []].append(edge.child)
        }
        for parent in childrenByParent.keys {
            childrenByParent[parent]?.sort()
        }

        var marks: [String: Int] = [:]
        for startID in records.keys.sorted() {
            guard marks[startID] == nil else { continue }

            marks[startID] = 1
            var stack = [GraphVisitFrame(id: startID, nextChildIndex: 0)]
            while let frame = stack.last {
                let children = childrenByParent[frame.id] ?? []
                guard frame.nextChildIndex < children.count else {
                    marks[frame.id] = 2
                    stack.removeLast()
                    continue
                }

                let child = children[frame.nextChildIndex]
                stack[stack.count - 1].nextChildIndex += 1
                if marks[child] == 1 {
                    throw WingmanEvidenceReaderError.incompatibleTaskGraph("döngü algılandı")
                }
                if marks[child] == 2 {
                    continue
                }
                marks[child] = 1
                stack.append(GraphVisitFrame(id: child, nextChildIndex: 0))
            }
        }
        return (parentByChild, childrenByParent)
    }

    private func descendants(
        of rootID: String,
        records: [String: ThreadRecord],
        childrenByParent: [String: [String]]
    ) -> [(ThreadRecord, Int)] {
        var result: [(ThreadRecord, Int)] = []
        var queue = (childrenByParent[rootID] ?? []).map { ($0, 1) }
        var visited = Set<String>()
        var cursor = 0
        while cursor < queue.count {
            let (id, depth) = queue[cursor]
            cursor += 1
            guard visited.insert(id).inserted else { continue }
            guard let record = records[id] else { continue }
            result.append((record, depth))
            for child in childrenByParent[id] ?? [] {
                queue.append((child, depth + 1))
            }
        }
        return result
    }

    private func scanRolloutTree(
        root: ThreadRecord,
        descendants: [(ThreadRecord, Int)]
    ) -> TreeTailSummary {
        let orderedDescendants = descendants
            .map(\.0)
            .sorted { left, right in
                if left.tokensUsed != right.tokensUsed { return left.tokensUsed > right.tokensUsed }
                return left.id < right.id
            }
        let records = [root] + orderedDescendants
        let minimumSlice: Int64 = 16 * 1_024
        let maximumRollouts = 64
        let budgetCapacity = max(1, Int(perRolloutTailLimit / minimumSlice))
        let selectedCount = min(records.count, min(maximumRollouts, budgetCapacity))
        let perFileByteLimit = max(1, perRolloutTailLimit / Int64(max(1, selectedCount)))
        var knownSizes = records.map { rolloutFileSize(path: $0.rolloutPath) }

        var rootSummary = TailSummary()
        var aggregate = TailSummary()
        var everyRolloutComplete = selectedCount == records.count
        for (index, record) in records.enumerated() {
            guard index < selectedCount else {
                everyRolloutComplete = false
                continue
            }
            let summary = scanRolloutTail(
                path: record.rolloutPath,
                byteLimit: perFileByteLimit,
                includeHumanPrompts: index == 0
            )
            if index == 0 {
                rootSummary = summary
            }
            if summary.coverage != .complete {
                everyRolloutComplete = false
            }
            if summary.fileAvailable {
                knownSizes[index] = summary.totalBytes
            }
            mergeTail(summary, recordID: record.id, into: &aggregate)
        }

        aggregate.totalBytes = knownSizes.compactMap { $0 }.reduce(Int64(0)) {
            Self.clampedAdd($0, $1)
        }
        aggregate.latestTokenBreakdown = rootSummary.latestTokenBreakdown
        let everyRolloutKnown = knownSizes.allSatisfy { $0 != nil }
        if aggregate.fileAvailable {
            aggregate.coverage = everyRolloutComplete && everyRolloutKnown ? .complete : .partial
        } else if knownSizes.contains(where: { $0 != nil }) {
            aggregate.coverage = .partial
        } else {
            aggregate.coverage = .unavailable
        }
        return TreeTailSummary(root: rootSummary, aggregate: aggregate)
    }

    private func mergeTail(
        _ source: TailSummary,
        recordID: String,
        into target: inout TailSummary
    ) {
        target.fileAvailable = target.fileAvailable || source.fileAvailable
        target.scannedBytes = Self.clampedAdd(target.scannedBytes, source.scannedBytes)
        target.activeBuckets.formUnion(source.activeBuckets)
        target.activeDays.formUnion(source.activeDays)
        target.prompts.append(contentsOf: source.prompts)
        target.userMessageCount = Self.clampedAdd(target.userMessageCount, source.userMessageCount)
        target.meaningfulAgentMessageCount = Self.clampedAdd(
            target.meaningfulAgentMessageCount,
            source.meaningfulAgentMessageCount
        )
        target.toolCallCount = Self.clampedAdd(target.toolCallCount, source.toolCallCount)
        target.completedTurnCount = Self.clampedAdd(target.completedTurnCount, source.completedTurnCount)
        target.abortedTurnCount = Self.clampedAdd(target.abortedTurnCount, source.abortedTurnCount)
        target.measuredAbortedTurnTokens = Self.clampedAdd(
            target.measuredAbortedTurnTokens,
            source.measuredAbortedTurnTokens
        )
        for (turnID, turn) in source.openTurns {
            target.openTurns["\(recordID):\(turnID)"] = turn
        }
    }

    private func scanRolloutTail(
        path: String,
        byteLimit: Int64,
        includeHumanPrompts: Bool
    ) -> TailSummary {
        var summary = TailSummary()
        guard let identity = safeFiles.metadata(path: path),
              identity.size <= UInt64(Int64.max) else {
            return summary
        }
        let size = Int64(identity.size)
        summary.totalBytes = size

        if size == 0 {
            guard safeFiles.read(
                path: path,
                offset: 0,
                maximumLength: 0,
                expectedIdentity: identity
            ) != nil else { return summary }
            summary.fileAvailable = true
            summary.coverage = .complete
            return summary
        }

        let bytesToRead = min(size, max(1, byteLimit))
        let startOffset = max(0, size - bytesToRead)
        guard var data = safeFiles.read(
            path: path,
            offset: UInt64(startOffset),
            maximumLength: UInt64(bytesToRead),
            expectedIdentity: identity
        )?.data,
        Int64(data.count) == bytesToRead else {
            return summary
        }
        summary.fileAvailable = true
        summary.scannedBytes = Int64(data.count)
        summary.coverage = startOffset == 0 ? .complete : .partial
        if startOffset > 0, let newline = data.firstIndex(of: 0x0A) {
            data = Data(data[data.index(after: newline)...])
        } else if startOffset > 0 {
            return summary
        }
        for line in data.split(separator: 0x0A, omittingEmptySubsequences: false) {
            let hasContent = line.contains { byte in
                byte != 0x09 && byte != 0x0D && byte != 0x20
            }
            guard hasContent else { continue }
            if !consumeRolloutLine(
                Data(line),
                includeHumanPrompts: includeHumanPrompts,
                into: &summary
            ) {
                summary.coverage = .partial
            }
        }
        guard let finalIdentity = safeFiles.metadata(path: path) else {
            summary.coverage = .partial
            return summary
        }
        if finalIdentity != identity {
            summary.totalBytes = Int64(min(UInt64(Int64.max), max(identity.size, finalIdentity.size)))
            summary.coverage = .partial
        }
        return summary
    }

    private func rolloutFileSize(path: String) -> Int64? {
        guard let identity = safeFiles.metadata(path: path),
              identity.size <= UInt64(Int64.max) else {
            return nil
        }
        return Int64(identity.size)
    }

    private func consumeRolloutLine(
        _ line: Data,
        includeHumanPrompts: Bool,
        into summary: inout TailSummary
    ) -> Bool {
        guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
              let envelopeType = object["type"] as? String else {
            return false
        }
        let timestamp = (object["timestamp"] as? String).flatMap(RolloutReducer.parseDate)
        if let timestamp {
            let seconds = Int64(timestamp.timeIntervalSince1970)
            summary.activeBuckets.insert(seconds / (30 * 60))
            summary.activeDays.insert(seconds / (24 * 60 * 60))
        }

        if envelopeType == "event_msg" {
            guard let payload = object["payload"] as? [String: Any],
                  payload["type"] is String else {
                return false
            }
            consumeEvent(
                payload,
                timestamp: timestamp,
                includeHumanPrompts: includeHumanPrompts,
                into: &summary
            )
        } else if envelopeType == "response_item" {
            guard let payload = object["payload"] as? [String: Any],
                  payload["type"] is String else {
                return false
            }
            if payload["type"] as? String == "function_call" {
                summary.toolCallCount = Self.clampedAdd(summary.toolCallCount, 1)
            }
        }
        return true
    }

    private func consumeEvent(
        _ payload: [String: Any],
        timestamp: Date?,
        includeHumanPrompts: Bool,
        into summary: inout TailSummary
    ) {
        guard let type = payload["type"] as? String else { return }
        switch type {
        case "user_message":
            guard includeHumanPrompts else { return }
            guard let raw = payload["message"] as? String,
                  let text = Self.sanitizeHumanText(raw, limit: 1_000) else { return }
            let fingerprint = Self.promptFingerprint(text)
            if fingerprint == summary.lastPromptFingerprint,
               let timestamp,
               let last = summary.lastPromptAt,
               abs(timestamp.timeIntervalSince(last)) <= 5 {
                return
            }
            if let lastIndex = summary.prompts.indices.last,
               summary.prompts[lastIndex].responseRecorded {
                summary.prompts[lastIndex].continuedAfterResponse = true
            }
            summary.prompts.append(
                MutablePrompt(
                    text: text,
                    occurredAt: timestamp,
                    isExplicitQuestion: Self.isExplicitQuestion(text),
                    isInvestigationRequest: Self.isInvestigationRequest(text)
                )
            )
            if summary.prompts.count > 24 {
                summary.prompts.remove(at: 8)
            }
            summary.userMessageCount += 1
            summary.lastPromptFingerprint = fingerprint
            summary.lastPromptAt = timestamp

        case "agent_message":
            let phase = payload["phase"] as? String
            guard phase == "commentary" || phase == "final_answer" else { return }
            summary.meaningfulAgentMessageCount += 1
            if let lastIndex = summary.prompts.indices.last {
                summary.prompts[lastIndex].responseRecorded = true
            }

        case "task_started":
            if let turnID = payload["turn_id"] as? String, !turnID.isEmpty {
                summary.openTurns[turnID] = OpenTurn()
            }

        case "task_complete":
            if let turnID = payload["turn_id"] as? String {
                summary.openTurns.removeValue(forKey: turnID)
            }
            summary.completedTurnCount += 1

        case "turn_aborted":
            if let turnID = payload["turn_id"] as? String,
               let turn = summary.openTurns.removeValue(forKey: turnID),
               let measured = turn.lastMeasuredUsage {
                summary.measuredAbortedTurnTokens = Self.clampedAdd(
                    summary.measuredAbortedTurnTokens,
                    measured
                )
            }
            summary.abortedTurnCount += 1

        case "token_count":
            guard let info = payload["info"] as? [String: Any] else { return }
            if let usage = Self.tokenUsage(info["total_token_usage"]) {
                summary.latestTokenBreakdown = usage
            }
            if summary.openTurns.count == 1,
               let lastUsage = Self.tokenUsage(info["last_token_usage"])?.total,
               let turnID = summary.openTurns.keys.first {
                summary.openTurns[turnID]?.lastMeasuredUsage = lastUsage
            }

        default:
            break
        }
    }

    private static func tokenUsage(_ value: Any?) -> WingmanTokenUsage? {
        guard let object = value as? [String: Any],
              let total = int64(object["total_tokens"]) else {
            return nil
        }
        return WingmanTokenUsage(
            source: .rolloutMeasuredBreakdown,
            total: total,
            input: int64(object["input_tokens"]),
            cachedInput: int64(object["cached_input_tokens"]),
            cacheWriteInput: int64(object["cache_write_input_tokens"]),
            output: int64(object["output_tokens"]),
            reasoningOutput: int64(object["reasoning_output_tokens"])
        )
    }

    private static func int64(_ value: Any?) -> Int64? {
        if let number = value as? NSNumber {
            return max(0, number.int64Value)
        }
        return nil
    }

    static func sanitizeHumanText(_ raw: String, limit: Int) -> String? {
        var text = raw
        let blockNames = [
            "app-context", "environment_context", "permissions", "recommended_plugins",
            "skills_instructions", "plugins_instructions", "apps_instructions"
        ]
        for name in blockNames {
            text = text.replacingOccurrences(
                of: "(?is)<\(name)(?:\\s[^>]*)?>.*?</\(name)>",
                with: " ",
                options: .regularExpression
            )
        }
        let redactions: [(String, String)] = [
            (#"(?i)https?://[^\s<>]+"#, "[bağlantı]"),
            (#"(?i)-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----[\s\S]*?-----END (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"#, "[gizli değer]"),
            (#"(?is)(?:"(?:~|/|[A-Z]:\\|\\\\)[^"\r\n]*"|'(?:~|/|[A-Z]:\\|\\\\)[^'\r\n]*')"#, "[yerel yol]"),
            (#"(?i)\\\\[^<>"'\r\n]+"#, "[yerel yol]"),
            (#"(?i)\b[A-Z]:\\[^<>"'\r\n]+"#, "[yerel yol]"),
            (#"(?i)(?<![A-Za-z0-9])/(?:Users|home|Volumes|private|tmp|var|etc)/[^<>"'\r\n]+"#, "[yerel yol]"),
            (#"~/.codex(?:/[^\s<>]*)?"#, "[Codex verisi]"),
            (#"~/[^<>"'\r\n]+"#, "[yerel yol]"),
            (#"(?<![A-Za-z0-9])/(?:[^/\s<>]+/)*[^/\s<>]+"#, "[yerel yol]"),
            (#"(?i)\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b"#, "[e-posta]"),
            (#"\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\b"#, "[kimlik]"),
            (#"(?i)\b(?:gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,}|sk-[A-Za-z0-9_-]{20,}|AKIA[0-9A-Z]{16})\b"#, "[gizli değer]"),
            (#"\b[0-9a-fA-F]{40,}\b"#, "[uzun kimlik]")
        ]
        for (pattern, replacement) in redactions {
            text = text.replacingOccurrences(
                of: pattern,
                with: replacement,
                options: .regularExpression
            )
        }
        text = String(
            text.unicodeScalars.filter { scalar in
                scalar.value == 0x0A || scalar.value == 0x09 || !CharacterSet.controlCharacters.contains(scalar)
            }
        )
        text = text
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        return String(text.prefix(max(1, limit)))
    }

    static func taskDisplayTitle(_ raw: String) -> String {
        if isCodexGoalControlPrompt(raw) {
            return "Codex hedef çalışması"
        }
        return sanitizeHumanText(raw, limit: 180) ?? "Adsız çalışma penceresi"
    }

    static func sanitizedInitialPrompt(_ raw: String, limit: Int) -> String? {
        guard !isCodexGoalControlPrompt(raw) else { return nil }
        return sanitizeHumanText(raw, limit: limit)
    }

    private static func isCodexGoalControlPrompt(_ raw: String) -> Bool {
        let firstLine = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: \.isNewline)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
        return firstLine == "/goal" || firstLine.hasPrefix("/goal ")
    }

    static func promptFingerprint(_ text: String) -> String {
        text.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: Locale(identifier: "tr_TR")
        )
        .split(whereSeparator: { $0.isWhitespace })
        .joined(separator: " ")
    }

    static func isExplicitQuestion(_ text: String) -> Bool {
        if text.contains("?") { return true }
        let normalized = promptFingerprint(text)
        let markers = ["neden ", "nasil ", "ne kadar ", "hangi ", "nedir ", "mümkün mü", "olur mu", "why ", "how ", "what ", "which "]
        return markers.contains { normalized.hasPrefix($0) || normalized.contains(" \($0)") }
    }

    static func isInvestigationRequest(_ text: String) -> Bool {
        let normalized = promptFingerprint(text)
        let markers = [
            "araştır", "incele", "karşılaştır", "bul", "test et", "doğrula", "kanıtla",
            "research", "inspect", "compare", "find", "verify", "evaluate", "audit"
        ]
        return markers.contains { normalized.contains($0) }
    }

    private static func boundedPromptSamples(
        _ prompts: [WingmanPromptEvidence],
        limit: Int
    ) -> [WingmanPromptEvidence] {
        guard prompts.count > limit else { return prompts }
        let firstCount = min(4, limit)
        let lastCount = limit - firstCount
        return Array(prompts.prefix(firstCount)) + Array(prompts.suffix(lastCount))
    }

    private static func projectLabel(for cwd: String) -> String {
        let component = URL(fileURLWithPath: cwd).lastPathComponent
        return sanitizeHumanText(component, limit: 80) ?? "Codex"
    }

    private static func clampedAdd(_ left: Int64, _ right: Int64) -> Int64 {
        let safeLeft = max(0, left)
        let safeRight = max(0, right)
        if safeLeft > Int64.max - safeRight { return Int64.max }
        return safeLeft + safeRight
    }

    private static func clampedAdd(_ left: Int, _ right: Int) -> Int {
        let safeLeft = max(0, left)
        let safeRight = max(0, right)
        if safeLeft > Int.max - safeRight { return Int.max }
        return safeLeft + safeRight
    }
}
