import Foundation
import SQLite3
#if canImport(Testing)
import Testing
@testable import ActivityRadarCore

@Test
func wingmanReaderAggregatesSpawnTreeAndUsesOnlyHumanEvents() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("ActivityRadar-WingmanTests-\(UUID().uuidString)", isDirectory: true)
    let codex = root.appendingPathComponent(".codex", isDirectory: true)
    try FileManager.default.createDirectory(at: codex, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let rollout = codex.appendingPathComponent("root-rollout.jsonl")
    let lines = [
        #"{"timestamp":"2026-08-20T10:00:00Z","type":"event_msg","payload":{"type":"task_started","turn_id":"turn-1"}}"#,
        #"{"timestamp":"2026-08-20T10:00:01Z","type":"event_msg","payload":{"type":"user_message","message":"Sulama sensörlerini araştır?"}}"#,
        #"{"timestamp":"2026-08-20T10:00:01Z","type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"DUPLICATE-PRIVATE"}]}}"#,
        #"{"timestamp":"2026-08-20T10:00:02Z","type":"response_item","payload":{"type":"message","role":"developer","content":[{"type":"input_text","text":"DEVELOPER-PRIVATE"}]}}"#,
        #"{"timestamp":"2026-08-20T10:00:03Z","type":"response_item","payload":{"type":"function_call","name":"bounded_tool","call_id":"call-1"}}"#,
        #"{"timestamp":"2026-08-20T10:00:04Z","type":"event_msg","payload":{"type":"token_count","info":{"last_token_usage":{"input_tokens":400,"cached_input_tokens":100,"cache_write_input_tokens":0,"output_tokens":100,"reasoning_output_tokens":20,"total_tokens":500},"total_token_usage":{"input_tokens":1700000000,"cached_input_tokens":100,"cache_write_input_tokens":0,"output_tokens":500000000,"reasoning_output_tokens":20,"total_tokens":2200000000}}}}"#,
        #"{"timestamp":"2026-08-20T10:00:05Z","type":"event_msg","payload":{"type":"agent_message","phase":"final_answer","message":"Özet hazır."}}"#,
        #"{"timestamp":"2026-08-20T10:00:06Z","type":"event_msg","payload":{"type":"turn_aborted","turn_id":"turn-1"}}"#
    ]
    try Data((lines.joined(separator: "\n") + "\n").utf8).write(to: rollout)

    let childRollout = codex.appendingPathComponent("child-rollout.jsonl")
    let childLines = [
        #"{"timestamp":"2026-08-20T10:01:00Z","type":"event_msg","payload":{"type":"task_started","turn_id":"child-turn"}}"#,
        #"{"timestamp":"2026-08-20T10:01:01Z","type":"event_msg","payload":{"type":"user_message","message":"CHILD-AGENT-DIRECTIVE"}}"#,
        #"{"timestamp":"2026-08-20T10:01:02Z","type":"response_item","payload":{"type":"function_call","name":"child_tool","call_id":"child-call"}}"#,
        #"{"timestamp":"2026-08-20T10:01:03Z","type":"event_msg","payload":{"type":"token_count","info":{"last_token_usage":{"input_tokens":600,"output_tokens":100,"total_tokens":700},"total_token_usage":{"input_tokens":2400000000,"output_tokens":600000000,"total_tokens":3000000000}}}}"#,
        #"{"timestamp":"2026-08-20T10:01:04Z","type":"event_msg","payload":{"type":"agent_message","phase":"final_answer","message":"Alt görev özeti."}}"#,
        #"{"timestamp":"2026-08-20T10:01:05Z","type":"event_msg","payload":{"type":"turn_aborted","turn_id":"child-turn"}}"#
    ]
    try Data((childLines.joined(separator: "\n") + "\n").utf8).write(to: childRollout)

    let state = codex.appendingPathComponent("state_5.sqlite")
    let syntheticHomePath = "/" + "Users/private-person/private-project"
    var database: OpaquePointer?
    #expect(sqlite3_open(state.path, &database) == SQLITE_OK)
    let db = try #require(database)
    defer { sqlite3_close(db) }
    try execute(db, """
        CREATE TABLE threads (
          id TEXT, thread_source TEXT, title TEXT, first_user_message TEXT,
          cwd TEXT, rollout_path TEXT, created_at INTEGER, updated_at INTEGER,
          created_at_ms INTEGER, updated_at_ms INTEGER, tokens_used INTEGER, archived INTEGER
        );
        CREATE TABLE thread_spawn_edges (parent_thread_id TEXT, child_thread_id TEXT);
        INSERT INTO threads VALUES (
          'root', 'user', 'Sulama çalışma penceresi', 'Sulama sensörlerini araştır?',
          '\(syntheticHomePath)', '\(sql(rollout.path))',
          1787220000, 1787220006, 1787220000000, 1787220006000, 2200000000, 0
        );
        INSERT INTO threads VALUES (
          'child', 'subagent', 'Sensör karşılaştırması', 'Sensörleri karşılaştır',
          '\(syntheticHomePath)', '\(sql(childRollout.path))',
          1787220001, 1787220005, 1787220001000, 1787220005000, 3000000000, 0
        );
        INSERT INTO thread_spawn_edges VALUES ('root', 'child');
        """)

    let snapshot = try CodexWingmanEvidenceReader(
        homeDirectory: root,
        perRolloutTailLimit: 64 * 1_024
    ).load(limit: 20, now: Date(timeIntervalSince1970: 1_787_220_100))

    #expect(snapshot.candidateTaskCount == 1)
    let task = try #require(snapshot.tasks.first)
    // Root and child counters share inherited cumulative history. The tree
    // proxy must use one largest observation instead of adding both counters.
    #expect(task.observedCumulativeTokenProxy == 3_000_000_000)
    #expect(snapshot.scopeObservedCumulativeTokenProxyTotal == 3_000_000_000)
    #expect(task.childCount == 1)
    #expect(task.directTokenUsage.hasBreakdown)
    #expect(task.userMessageCountLowerBound == 1)
    #expect(task.meaningfulAgentMessageCountLowerBound == 2)
    #expect(task.toolCallCountLowerBound == 2)
    #expect(task.abortedTurnCountLowerBound == 2)
    #expect(task.measuredAbortedTurnTokensLowerBound == 1_200)
    #expect(task.rolloutCoverage == .complete)
    #expect(task.scannedRolloutBytes == task.totalRolloutBytes)
    #expect(task.promptSamples.count == 1)
    #expect(!task.promptSamples.map(\.text).joined().contains("CHILD-AGENT-DIRECTIVE"))
    #expect(!task.promptSamples.map(\.text).joined().contains("DUPLICATE-PRIVATE"))
    #expect(!task.promptSamples.map(\.text).joined().contains("DEVELOPER-PRIVATE"))
    #expect(!task.projectLabel.contains("/" + "Users/"))
}

@Test
func sqliteReadOnlyTransactionKeepsOneWALSnapshot() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("ActivityRadar-SQLiteSnapshot-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let state = root.appendingPathComponent("snapshot.sqlite")

    try withWritableSQLite(at: state) { database in
        try execute(database, """
            PRAGMA journal_mode=WAL;
            CREATE TABLE evidence (id INTEGER PRIMARY KEY);
            INSERT INTO evidence VALUES (1);
            """)
    }

    let reader = try SQLiteReadOnly(path: state.path)
    try reader.withReadTransaction {
        #expect(try sqliteCount(reader, table: "evidence") == 1)
        try withWritableSQLite(at: state) { writer in
            try execute(writer, "INSERT INTO evidence VALUES (2);")
        }
        #expect(try sqliteCount(reader, table: "evidence") == 1)
    }
    #expect(try sqliteCount(reader, table: "evidence") == 2)
}

@Test
func wingmanReaderMarksMalformedFinalJSONLPartial() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("ActivityRadar-MalformedTail-\(UUID().uuidString)", isDirectory: true)
    let codex = root.appendingPathComponent(".codex", isDirectory: true)
    try FileManager.default.createDirectory(at: codex, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let rollout = codex.appendingPathComponent("malformed.jsonl")
    let valid = #"{"timestamp":"2026-08-20T10:00:00Z","type":"event_msg","payload":{"type":"user_message","message":"Kanıtı incele?"}}"#
    let truncated = #"{"timestamp":"2026-08-20T10:00:01Z","type":"event_msg","payload":{"type":"agent_message""#
    try Data((valid + "\n" + truncated).utf8).write(to: rollout)

    let state = codex.appendingPathComponent("state_5.sqlite")
    try withWritableSQLite(at: state) { database in
        try createWingmanSchema(database)
        try execute(database, """
            INSERT INTO threads VALUES (
              'root', 'user', 'Bozuk tail', 'Kanıtı incele?',
              '/tmp/fixture', '\(sql(rollout.path))',
              1787220000, 1787220001, 1787220000000, 1787220001000, 100, 0
            );
            """)
    }

    let task = try #require(
        try CodexWingmanEvidenceReader(homeDirectory: root).load().tasks.first
    )
    #expect(task.rolloutCoverage == .partial)
    #expect(task.scannedRolloutBytes == task.totalRolloutBytes)
}

@Test
func wingmanReaderMarksMissingDescendantRolloutPartial() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("ActivityRadar-MissingDescendant-\(UUID().uuidString)", isDirectory: true)
    let codex = root.appendingPathComponent(".codex", isDirectory: true)
    try FileManager.default.createDirectory(at: codex, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let rollout = codex.appendingPathComponent("root.jsonl")
    let line = #"{"timestamp":"2026-08-20T10:00:00Z","type":"session_meta","payload":{"id":"root"}}"#
    try Data((line + "\n").utf8).write(to: rollout)

    let state = codex.appendingPathComponent("state_5.sqlite")
    try withWritableSQLite(at: state) { database in
        try createWingmanSchema(database)
        try execute(database, """
            INSERT INTO threads VALUES (
              'root', 'user', 'Kök', 'İşi incele', '/tmp/fixture', '\(sql(rollout.path))',
              1787220000, 1787220001, 1787220000000, 1787220001000, 100, 0
            );
            INSERT INTO threads VALUES (
              'child', 'subagent', 'Alt görev', 'Alt işi incele', '/tmp/fixture', '',
              1787220000, 1787220001, 1787220000000, 1787220001000, 200, 0
            );
            INSERT INTO thread_spawn_edges VALUES ('root', 'child');
            """)
    }

    let task = try #require(
        try CodexWingmanEvidenceReader(homeDirectory: root).load().tasks.first
    )
    #expect(task.observedCumulativeTokenProxy == 200)
    #expect(task.rolloutCoverage == .partial)
    #expect(task.scannedRolloutBytes == task.totalRolloutBytes)
}

@Test
func wingmanReaderBoundsAggregateTreeTailBudget() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("ActivityRadar-TreeBudget-\(UUID().uuidString)", isDirectory: true)
    let codex = root.appendingPathComponent(".codex", isDirectory: true)
    try FileManager.default.createDirectory(at: codex, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let repeatedLine = #"{"timestamp":"2026-08-20T10:00:00Z","type":"event_msg","payload":{"type":"agent_message","phase":"commentary","message":"Özet"}}"#
    let largeRollout = Array(repeating: repeatedLine, count: 220).joined(separator: "\n") + "\n"
    var paths: [URL] = []
    for index in 0..<5 {
        let path = codex.appendingPathComponent("rollout-\(index).jsonl")
        try Data(largeRollout.utf8).write(to: path)
        paths.append(path)
    }

    let state = codex.appendingPathComponent("state_5.sqlite")
    try withWritableSQLite(at: state) { database in
        try createWingmanSchema(database)
        try execute(database, """
            INSERT INTO threads VALUES (
              'root', 'user', 'Kök', 'İşi incele', '/tmp/fixture', '\(sql(paths[0].path))',
              1787220000, 1787220001, 1787220000000, 1787220001000, 100, 0
            );
            """)
        for index in 1..<5 {
            try execute(database, """
                INSERT INTO threads VALUES (
                  'child-\(index)', 'subagent', 'Alt \(index)', 'Alt işi incele',
                  '/tmp/fixture', '\(sql(paths[index].path))',
                  1787220000, 1787220001, 1787220000000, 1787220001000, \(index * 100), 0
                );
                INSERT INTO thread_spawn_edges VALUES ('root', 'child-\(index)');
                """)
        }
    }

    let byteBudget: Int64 = 64 * 1_024
    let task = try #require(
        try CodexWingmanEvidenceReader(
            homeDirectory: root,
            perRolloutTailLimit: byteBudget
        ).load().tasks.first
    )
    #expect(task.rolloutCoverage == .partial)
    #expect(task.scannedRolloutBytes <= byteBudget)
    #expect(task.totalRolloutBytes > task.scannedRolloutBytes)
}

@Test
func wingmanGraphIsDeterministicAndConnectsRelatedTasks() throws {
    let now = Date(timeIntervalSince1970: 2_000_000_000)
    let snapshot = WingmanEvidenceSnapshot(
        generatedAt: now,
        scopeStart: nil,
        candidateTaskCount: 3,
        scopeMeasuredTokenTotal: 6_000,
        tasks: [
            wingmanTask(id: "W001", title: "Sulama sensör ağı", prompt: "sulama sulama sensör karşılaştır", tokens: 3_000),
            wingmanTask(id: "W002", title: "Sulama sensör enerjisi", prompt: "sulama sensör enerji verimini araştır", tokens: 2_000),
            wingmanTask(id: "W003", title: "Makale düzeni", prompt: "makale yazım biçimini incele", tokens: 1_000)
        ],
        omittedTaskCount: 0
    )

    let first = WingmanPortfolioAnalyzer.analyze(snapshot)
    let second = WingmanPortfolioAnalyzer.analyze(snapshot)

    #expect(first == second)
    #expect(first.themes.contains { $0.label == "sulama" })
    #expect(first.taskSimilarityEdges.contains {
        Set([$0.sourceID, $0.targetID]) == Set(["W001", "W002"])
    })
    let sulama = try #require(first.themes.first { $0.label == "sulama" })
    #expect(sulama.taskCount == 2)
    #expect(sulama.pageRank > 0)
}

@Test
func wingmanModelsNameActivityCutoffAndLifetimeTokensExplicitly() {
    let cutoff = Date(timeIntervalSince1970: 1_900_000_000)
    let task = wingmanTask(id: "W001", title: "Kanıt", prompt: "kanıtı incele", tokens: 1_000)
    let snapshot = WingmanEvidenceSnapshot(
        generatedAt: Date(timeIntervalSince1970: 2_000_000_000),
        taskActivityCutoff: cutoff,
        candidateTaskCount: 1,
        lifetimeTokenTotalForScopedTasks: 9_000,
        tasks: [task],
        omittedTaskCount: 0
    )
    let analysis = WingmanPortfolioAnalyzer.analyze(snapshot)

    #expect(snapshot.taskActivityCutoff == cutoff)
    #expect(snapshot.lifetimeTokenTotalForScopedTasks == 9_000)
    #expect(analysis.taskActivityCutoff == cutoff)
    #expect(analysis.lifetimeTokenTotalForScopedTasks == 9_000)
    #expect(analysis.selectedTaskLifetimeTokenTotal == 1_000)
    #expect(analysis.scopeStart == analysis.taskActivityCutoff)
    #expect(analysis.scopeMeasuredTokenTotal == analysis.lifetimeTokenTotalForScopedTasks)
    #expect(analysis.selectedMeasuredTokenTotal == analysis.selectedTaskLifetimeTokenTotal)
}

@Test
func wingmanActivityIndexIsRelativeToObservedPortfolio() throws {
    let focus = wingmanTask(
        id: "W001",
        title: "Odak",
        prompt: "odak işini incele",
        tokens: 1_000,
        observedActivityCount: 10
    )
    let busier = wingmanTask(
        id: "W002",
        title: "Yoğun",
        prompt: "yoğun işi incele",
        tokens: 900,
        observedActivityCount: 1_000
    )
    let generatedAt = Date(timeIntervalSince1970: 2_000_000_000)
    let isolated = WingmanPortfolioAnalyzer.analyze(
        WingmanEvidenceSnapshot(
            generatedAt: generatedAt,
            taskActivityCutoff: nil,
            candidateTaskCount: 1,
            lifetimeTokenTotalForScopedTasks: 1_000,
            tasks: [focus],
            omittedTaskCount: 0
        )
    )
    let portfolio = WingmanPortfolioAnalyzer.analyze(
        WingmanEvidenceSnapshot(
            generatedAt: generatedAt,
            taskActivityCutoff: nil,
            candidateTaskCount: 2,
            lifetimeTokenTotalForScopedTasks: 1_900,
            tasks: [focus, busier],
            omittedTaskCount: 0
        )
    )

    let isolatedFocus = try #require(isolated.tasks.first { $0.id == "W001" })
    let portfolioFocus = try #require(portfolio.tasks.first { $0.id == "W001" })
    #expect(abs(isolatedFocus.relativeObservedActivityIndex - 100) < 0.000_001)
    #expect(portfolioFocus.relativeObservedActivityIndex < isolatedFocus.relativeObservedActivityIndex)
    #expect(portfolioFocus.activityIndex == portfolioFocus.relativeObservedActivityIndex)
}

@Test
func wingmanAgentPacketRedactsPathsIdentifiersAndContextBlocks() throws {
    let rawUUID = "123e4567-e89b-42d3-a456-426614174000"
    let credential = "github" + "_pat_" + "ABCDEFGHIJKLMNOPQRSTUVWXYZ123456"
    let spacedPOSIXPath = "/" + "Users/private-person/My Project/secret notes.txt"
    let uncPath = "\\\\" + "lab-server\\Shared Folder\\secret notes.txt"
    let task = wingmanTask(
        id: "W001",
        title: "'\(spacedPOSIXPath)' \(uncPath) /Volumes/Lab/private C:\\Users\\private-person\\private \(rawUUID)",
        prompt: "<recommended_plugins>SECRET</recommended_plugins> /tmp/private? alice@example.org \(credential)",
        tokens: 1_000
    )
    let analysis = WingmanPortfolioAnalyzer.analyze(
        WingmanEvidenceSnapshot(
            generatedAt: Date(timeIntervalSince1970: 2_000_000_000),
            scopeStart: nil,
            candidateTaskCount: 1,
            scopeMeasuredTokenTotal: 1_000,
            tasks: [task],
            omittedTaskCount: 0
        )
    )
    let data = try WingmanAgentPacketBuilder.encode(
        WingmanAgentPacketBuilder.make(analysis: analysis, includePromptExcerpts: true)
    )
    let text = try #require(String(data: data, encoding: .utf8))

    #expect(!text.contains("/" + "Users/" + "private-person"))
    #expect(!text.contains("/Volumes/" + "Lab"))
    #expect(!text.contains("/tmp/private"))
    #expect(!text.contains("C:\\Users"))
    #expect(!text.contains("My Project"))
    #expect(!text.contains("secret notes.txt"))
    #expect(!text.contains("lab-server"))
    #expect(!text.contains("Shared Folder"))
    #expect(!text.contains("alice@example.org"))
    #expect(!text.contains(credential))
    #expect(!text.contains(rawUUID))
    #expect(!text.contains("SECRET"))
    #expect(!text.contains("rolloutPath"))
    #expect(!text.contains("cwd"))
}

@Test
func wingmanSanitizerRedactsSpacedAndUNCPathSuffixes() throws {
    let spacedPOSIXPath = "/" + "Users/private-person/My Project/secret suffix.txt"
    let uncPath = "\\\\" + "lab-server\\Shared Folder\\private suffix.txt"
    let sanitized = try #require(
        CodexWingmanEvidenceReader.sanitizeHumanText(
            "Önce '\(spacedPOSIXPath)', sonra \(uncPath)",
            limit: 1_000
        )
    )

    #expect(sanitized.contains("[yerel yol]"))
    #expect(!sanitized.contains("My Project"))
    #expect(!sanitized.contains("secret suffix.txt"))
    #expect(!sanitized.contains("lab-server"))
    #expect(!sanitized.contains("Shared Folder"))
    #expect(!sanitized.contains("private suffix.txt"))
}

@Test
func wingmanNormalizesCodexGoalControlPrompts() throws {
    let privatePath = "/" + "Users/private-person/.codex/attachments/fixture/goal-objective.md"
    let command = "/goal Read the Codex goal objective file at \(privatePath) before continuing."

    #expect(CodexWingmanEvidenceReader.taskDisplayTitle(command) == "Codex hedef çalışması")
    #expect(CodexWingmanEvidenceReader.sanitizedInitialPrompt(command, limit: 1_000) == nil)
    #expect(CodexWingmanEvidenceReader.taskDisplayTitle("Sulama pompası seçimi") == "Sulama pompası seçimi")
}

@Test
func wingmanCodexContractUsesNoShellAndStripsSecrets() {
    let args = WingmanCodexContract.arguments(
        workingDirectory: URL(fileURLWithPath: "/tmp/wingman-work"),
        schemaURL: URL(fileURLWithPath: "/tmp/wingman-work/schema.json")
    )
    let joined = args.joined(separator: " ")
    #expect(args.prefix(3) == ["-a", "never", "exec"])
    #expect(joined.contains("--sandbox read-only"))
    #expect(joined.contains("--ephemeral"))
    #expect(joined.contains("--ignore-user-config"))
    #expect(joined.contains("--json"))
    #expect(!joined.contains("danger-full-access"))
    #expect(!joined.contains("workspace-write"))
    #expect(!joined.contains("full-auto"))
    #expect(!joined.contains("bypass"))

    let environment = WingmanCodexContract.sanitizedEnvironment(from: [
        "HOME": "/tmp/home",
        "PATH": "/usr/bin",
        "OPENAI_API_KEY": "SECRET",
        "CODEX_API_KEY": "SECRET",
        "UNRELATED_SECRET": "SECRET"
    ])
    #expect(environment["HOME"] == "/tmp/home")
    #expect(environment["PATH"] == "/usr/bin")
    #expect(environment["OPENAI_API_KEY"] == nil)
    #expect(environment["CODEX_API_KEY"] == nil)
    #expect(environment["UNRELATED_SECRET"] == nil)
}

@Test
func wingmanJSONLParserAcceptsReviewAndRejectsToolEvents() throws {
    let review = WingmanAgentReview(
        portfolioSummary: "Özet",
        promptFindings: ["Prompt bulgusu"],
        harnessFindings: ["Harness bulgusu"],
        unfinishedWork: ["Yarım iş"],
        tokenFindings: ["Kesin israf bilinmiyor"],
        recommendations: ["Sınırı yaz"],
        limitations: ["Kapsam kısmi"]
    )
    let reviewData = try JSONEncoder().encode(review)
    let reviewText = try #require(String(data: reviewData, encoding: .utf8))
    var parser = WingmanCodexJSONLParser()
    parser.consume(line: try jsonData([
        "type": "item.completed",
        "item": ["type": "agent_message", "text": reviewText]
    ]))
    parser.consume(line: try jsonData([
        "type": "turn.completed",
        "usage": [
            "input_tokens": 100,
            "cached_input_tokens": 20,
            "output_tokens": 30,
            "reasoning_output_tokens": 4
        ]
    ]))
    let result = try parser.result()
    #expect(result.review == review)
    #expect(result.usage?.inputTokens == 100)

    var forbidden = WingmanCodexJSONLParser()
    forbidden.consume(line: try jsonData([
        "type": "item.started",
        "item": ["type": "command_execution", "command": "cat private"]
    ]))
    #expect(forbidden.failure == .forbiddenToolEvent("command_execution"))
}

private func wingmanTask(
    id: String,
    title: String,
    prompt: String,
    tokens: Int64,
    observedActivityCount: Int? = nil
) -> WingmanTaskEvidence {
    let now = Date(timeIntervalSince1970: 2_000_000_000)
    return WingmanTaskEvidence(
        id: id,
        title: title,
        projectLabel: "Fixture",
        createdAt: now.addingTimeInterval(-3_600),
        updatedAt: now,
        archived: false,
        directTokenUsage: WingmanTokenUsage(source: .sqliteMeasuredTotal, total: tokens),
        recursiveTokenTotal: tokens,
        childCount: 0,
        maximumBranchDepth: 0,
        branchEvidence: [],
        initialPrompt: prompt,
        promptSamples: [
            WingmanPromptEvidence(
                text: prompt,
                occurredAt: now,
                isExplicitQuestion: prompt.contains("?"),
                isInvestigationRequest: true,
                responseState: .responseRecorded
            )
        ],
        rolloutCoverage: .complete,
        scannedRolloutBytes: 1_000,
        totalRolloutBytes: 1_000,
        activeBucketCountLowerBound: observedActivityCount ?? 2,
        activeDayCountLowerBound: observedActivityCount ?? 1,
        userMessageCountLowerBound: observedActivityCount ?? 1,
        meaningfulAgentMessageCountLowerBound: 1,
        toolCallCountLowerBound: observedActivityCount ?? 1,
        completedTurnCountLowerBound: 1,
        abortedTurnCountLowerBound: 0,
        measuredAbortedTurnTokensLowerBound: 0,
        hasObservedOpenTurn: false
    )
}

private func createWingmanSchema(_ database: OpaquePointer) throws {
    try execute(database, """
        CREATE TABLE threads (
          id TEXT, thread_source TEXT, title TEXT, first_user_message TEXT,
          cwd TEXT, rollout_path TEXT, created_at INTEGER, updated_at INTEGER,
          created_at_ms INTEGER, updated_at_ms INTEGER, tokens_used INTEGER, archived INTEGER
        );
        CREATE TABLE thread_spawn_edges (parent_thread_id TEXT, child_thread_id TEXT);
        """)
}

private func withWritableSQLite<T>(
    at url: URL,
    _ body: (OpaquePointer) throws -> T
) throws -> T {
    var database: OpaquePointer?
    guard sqlite3_open(url.path, &database) == SQLITE_OK, let database else {
        if let database { sqlite3_close(database) }
        throw TestFailure(message: "SQLite açılamadı")
    }
    defer { sqlite3_close(database) }
    return try body(database)
}

private func sqliteCount(_ database: SQLiteReadOnly, table: String) throws -> Int64 {
    var count: Int64 = -1
    try database.rows(sql: "SELECT COUNT(*) FROM \(table);") { statement in
        count = SQLiteReadOnly.int64(statement, index: 0)
    }
    return count
}

private func execute(_ database: OpaquePointer, _ sql: String) throws {
    var error: UnsafeMutablePointer<Int8>?
    let status = sqlite3_exec(database, sql, nil, nil, &error)
    defer { sqlite3_free(error) }
    guard status == SQLITE_OK else {
        let message = error.map { String(cString: $0) } ?? "SQLite error"
        throw TestFailure(message: message)
    }
}

private func sql(_ value: String) -> String {
    value.replacingOccurrences(of: "'", with: "''")
}

private func jsonData(_ object: [String: Any]) throws -> Data {
    try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
}

private struct TestFailure: Error {
    let message: String
}
#endif
