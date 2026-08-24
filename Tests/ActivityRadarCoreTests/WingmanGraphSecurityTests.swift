import Foundation
import SQLite3
import Darwin
#if canImport(Testing)
import Testing
@testable import ActivityRadarCore

@Test
func wingmanGraphDeduplicatesIdenticalSpawnEdgesBeforeTraversal() throws {
    let fixture = try makeWingmanGraphFixture(name: "DuplicateEdge")
    defer { try? FileManager.default.removeItem(at: fixture.home) }

    let rootRollout = fixture.codex.appendingPathComponent("root.jsonl")
    let childRollout = fixture.codex.appendingPathComponent("child.jsonl")
    let rootData = Data(
        (#"{"timestamp":"2026-08-23T10:00:00Z","type":"event_msg","payload":{"type":"agent_message","phase":"final_answer","message":"Root"}}"# + "\n").utf8
    )
    let childData = Data(
        (#"{"timestamp":"2026-08-23T10:00:01Z","type":"event_msg","payload":{"type":"agent_message","phase":"final_answer","message":"Child"}}"# + "\n").utf8
    )
    try rootData.write(to: rootRollout)
    try childData.write(to: childRollout)

    try withWingmanGraphDatabase(at: fixture.state) { database in
        try createWingmanGraphSchema(database)
        let threadStatement = try prepareWingmanGraphStatement(
            database,
            sql: "INSERT INTO threads VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);"
        )
        let edgeStatement = try prepareWingmanGraphStatement(
            database,
            sql: "INSERT INTO thread_spawn_edges VALUES (?, ?);"
        )
        defer {
            sqlite3_finalize(threadStatement)
            sqlite3_finalize(edgeStatement)
        }

        try insertWingmanGraphThread(
            threadStatement,
            id: "root",
            source: "user",
            rolloutPath: rootRollout.path,
            tokens: 100
        )
        try insertWingmanGraphThread(
            threadStatement,
            id: "child",
            source: "subagent",
            rolloutPath: childRollout.path,
            tokens: 200
        )
        try insertWingmanGraphEdge(edgeStatement, parent: "root", child: "child")
        try insertWingmanGraphEdge(edgeStatement, parent: "root", child: "child")
    }

    let snapshot = try CodexWingmanEvidenceReader(
        homeDirectory: fixture.home,
        perRolloutTailLimit: 64 * 1_024
    ).load()
    let task = try #require(snapshot.tasks.first)

    #expect(snapshot.candidateTaskCount == 1)
    #expect(task.childCount == 1)
    #expect(task.maximumBranchDepth == 1)
    #expect(task.meaningfulAgentMessageCountLowerBound == 2)
    #expect(task.scannedRolloutBytes == Int64(rootData.count + childData.count))
    #expect(task.totalRolloutBytes == Int64(rootData.count + childData.count))
    #expect(task.branchEvidence.count == 1)
}

@Test
func wingmanGraphHandlesVeryDeepChainIterativelyAndRejectsDeepCycle() throws {
    let fixture = try makeWingmanGraphFixture(name: "DeepChain")
    defer { try? FileManager.default.removeItem(at: fixture.home) }
    let nodeCount = 25_000

    try withWingmanGraphDatabase(at: fixture.state) { database in
        try createWingmanGraphSchema(database)
        try executeWingmanGraphSQL(database, "BEGIN IMMEDIATE;")
        do {
            let threadStatement = try prepareWingmanGraphStatement(
                database,
                sql: "INSERT INTO threads VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);"
            )
            let edgeStatement = try prepareWingmanGraphStatement(
                database,
                sql: "INSERT INTO thread_spawn_edges VALUES (?, ?);"
            )
            defer {
                sqlite3_finalize(threadStatement)
                sqlite3_finalize(edgeStatement)
            }

            for index in 0..<nodeCount {
                try insertWingmanGraphThread(
                    threadStatement,
                    id: "node-\(index)",
                    source: "subagent",
                    rolloutPath: "",
                    tokens: Int64(index)
                )
                if index > 0 {
                    try insertWingmanGraphEdge(
                        edgeStatement,
                        parent: "node-\(index - 1)",
                        child: "node-\(index)"
                    )
                }
            }
            try executeWingmanGraphSQL(database, "COMMIT;")
        } catch {
            try? executeWingmanGraphSQL(database, "ROLLBACK;")
            throw error
        }
    }

    let acyclic = try CodexWingmanEvidenceReader(homeDirectory: fixture.home).load()
    #expect(acyclic.candidateTaskCount == 0)
    #expect(acyclic.tasks.isEmpty)

    try withWingmanGraphDatabase(at: fixture.state) { database in
        let edgeStatement = try prepareWingmanGraphStatement(
            database,
            sql: "INSERT INTO thread_spawn_edges VALUES (?, ?);"
        )
        defer { sqlite3_finalize(edgeStatement) }
        try insertWingmanGraphEdge(
            edgeStatement,
            parent: "node-\(nodeCount - 1)",
            child: "node-0"
        )
    }

    #expect(try wingmanGraphErrorDetail(home: fixture.home) == "döngü algılandı")
}

@Test
func wingmanGraphStillFailsClosedForMissingNodesAndMultipleParents() throws {
    let fixture = try makeWingmanGraphFixture(name: "InvalidGraph")
    defer { try? FileManager.default.removeItem(at: fixture.home) }

    try withWingmanGraphDatabase(at: fixture.state) { database in
        try createWingmanGraphSchema(database)
        let threadStatement = try prepareWingmanGraphStatement(
            database,
            sql: "INSERT INTO threads VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);"
        )
        let edgeStatement = try prepareWingmanGraphStatement(
            database,
            sql: "INSERT INTO thread_spawn_edges VALUES (?, ?);"
        )
        defer {
            sqlite3_finalize(threadStatement)
            sqlite3_finalize(edgeStatement)
        }
        try insertWingmanGraphThread(
            threadStatement,
            id: "root-a",
            source: "user",
            rolloutPath: "",
            tokens: 0
        )
        try insertWingmanGraphEdge(edgeStatement, parent: "root-a", child: "child")
    }

    #expect(try wingmanGraphErrorDetail(home: fixture.home) == "eksik görev düğümü")

    try withWingmanGraphDatabase(at: fixture.state) { database in
        let threadStatement = try prepareWingmanGraphStatement(
            database,
            sql: "INSERT INTO threads VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);"
        )
        let edgeStatement = try prepareWingmanGraphStatement(
            database,
            sql: "INSERT INTO thread_spawn_edges VALUES (?, ?);"
        )
        defer {
            sqlite3_finalize(threadStatement)
            sqlite3_finalize(edgeStatement)
        }
        try insertWingmanGraphThread(
            threadStatement,
            id: "root-b",
            source: "user",
            rolloutPath: "",
            tokens: 0
        )
        try insertWingmanGraphThread(
            threadStatement,
            id: "child",
            source: "subagent",
            rolloutPath: "",
            tokens: 0
        )
        try insertWingmanGraphEdge(edgeStatement, parent: "root-b", child: "child")
    }

    #expect(
        try wingmanGraphErrorDetail(home: fixture.home)
            == "bir alt görevin birden çok üst görevi var"
    )
}

@Test
func wingmanGraphRejectsBlankSpawnEdgeEndpoints() throws {
    let cases = [
        (name: "BlankParent", parent: "", child: "child"),
        (name: "BlankChild", parent: "parent", child: "")
    ]

    for testCase in cases {
        let fixture = try makeWingmanGraphFixture(name: testCase.name)
        defer { try? FileManager.default.removeItem(at: fixture.home) }

        try withWingmanGraphDatabase(at: fixture.state) { database in
            try createWingmanGraphSchema(database)
            let edgeStatement = try prepareWingmanGraphStatement(
                database,
                sql: "INSERT INTO thread_spawn_edges VALUES (?, ?);"
            )
            defer { sqlite3_finalize(edgeStatement) }
            try insertWingmanGraphEdge(
                edgeStatement,
                parent: testCase.parent,
                child: testCase.child
            )
        }

        #expect(try wingmanGraphErrorDetail(home: fixture.home) == "boş görev bağlantısı ucu")
    }
}

@Test
func wingmanRolloutReaderRejectsSymlinkAndFIFOWithoutReadingOrBlocking() throws {
    let fixture = try makeWingmanGraphFixture(name: "UnsafeRolloutKinds")
    defer { try? FileManager.default.removeItem(at: fixture.home) }

    let target = fixture.codex.appendingPathComponent("target.jsonl")
    let symlink = fixture.codex.appendingPathComponent("linked.jsonl")
    let fifo = fixture.codex.appendingPathComponent("rollout.fifo")
    let sentinel = "UNSAFE-WINGMAN-ROLLOUT-SENTINEL"
    try Data(
        (#"{"timestamp":"2026-08-23T10:00:00Z","type":"event_msg","payload":{"type":"agent_message","phase":"final_answer","message":"\#(sentinel)"}}"# + "\n").utf8
    ).write(to: target)
    try FileManager.default.createSymbolicLink(at: symlink, withDestinationURL: target)
    guard mkfifo(fifo.path, mode_t(0o600)) == 0 else {
        throw WingmanGraphTestFailure(message: "FIFO fixture could not be created")
    }

    try withWingmanGraphDatabase(at: fixture.state) { database in
        try createWingmanGraphSchema(database)
        let statement = try prepareWingmanGraphStatement(
            database,
            sql: "INSERT INTO threads VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);"
        )
        defer { sqlite3_finalize(statement) }
        try insertWingmanGraphThread(
            statement,
            id: "symlink-root",
            source: "user",
            rolloutPath: symlink.path,
            tokens: 20
        )
        try insertWingmanGraphThread(
            statement,
            id: "fifo-root",
            source: "user",
            rolloutPath: fifo.path,
            tokens: 10
        )
    }

    let started = DispatchTime.now().uptimeNanoseconds
    let snapshot = try CodexWingmanEvidenceReader(homeDirectory: fixture.home).load()
    let elapsed = Double(DispatchTime.now().uptimeNanoseconds - started) / 1_000_000_000

    #expect(elapsed < 1)
    #expect(snapshot.tasks.count == 2)
    for task in snapshot.tasks {
        #expect(task.rolloutCoverage == .unavailable)
        #expect(task.scannedRolloutBytes == 0)
        #expect(task.meaningfulAgentMessageCountLowerBound == 0)
        #expect(!task.branchEvidence.contains(where: { $0.contains(sentinel) }))
    }
}

@Test
func wingmanGraphRejectsDuplicateThreadIdentifiers() throws {
    let fixture = try makeWingmanGraphFixture(name: "DuplicateThreadID")
    defer { try? FileManager.default.removeItem(at: fixture.home) }

    try withWingmanGraphDatabase(at: fixture.state) { database in
        try createWingmanGraphSchema(database)
        let statement = try prepareWingmanGraphStatement(
            database,
            sql: "INSERT INTO threads VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);"
        )
        defer { sqlite3_finalize(statement) }
        try insertWingmanGraphThread(statement, id: "duplicate", source: "user", rolloutPath: "", tokens: 0)
        try insertWingmanGraphThread(statement, id: "duplicate", source: "user", rolloutPath: "", tokens: 1)
    }

    #expect(try wingmanGraphErrorDetail(home: fixture.home) == "yinelenen görev kimliği")
}

@Test
func wingmanGraphRejectsThreadRowsBeyondTheFrozenResourceCeiling() throws {
    let fixture = try makeWingmanGraphFixture(name: "ThreadCeiling")
    defer { try? FileManager.default.removeItem(at: fixture.home) }

    try withWingmanGraphDatabase(at: fixture.state) { database in
        try createWingmanGraphSchema(database)
        try executeWingmanGraphSQL(database, """
            WITH RECURSIVE sequence(value) AS (
              VALUES(0)
              UNION ALL
              SELECT value + 1 FROM sequence WHERE value < 50000
            )
            INSERT INTO threads
            SELECT
              'bounded-' || value, 'subagent', 'Node', 'Prompt', '/tmp/fixture', '',
              1787486400, 1787486400, 1787486400000, 1787486400000, value, 0
            FROM sequence;
            """)
    }

    #expect(try wingmanGraphErrorDetail(home: fixture.home) == "görev düğümü sınırı aşıldı")
}

private func makeWingmanGraphFixture(
    name: String
) throws -> (home: URL, codex: URL, state: URL) {
    let home = FileManager.default.temporaryDirectory
        .appendingPathComponent("ActivityRadar-WingmanGraph-\(name)-\(UUID().uuidString)", isDirectory: true)
    let codex = home.appendingPathComponent(".codex", isDirectory: true)
    try FileManager.default.createDirectory(at: codex, withIntermediateDirectories: true)
    return (home, codex, codex.appendingPathComponent("state_5.sqlite"))
}

private func withWingmanGraphDatabase<T>(
    at url: URL,
    _ body: (OpaquePointer) throws -> T
) throws -> T {
    var database: OpaquePointer?
    guard sqlite3_open(url.path, &database) == SQLITE_OK, let database else {
        if let database { sqlite3_close(database) }
        throw WingmanGraphTestFailure(message: "SQLite fixture could not be opened")
    }
    defer { sqlite3_close(database) }
    return try body(database)
}

private func createWingmanGraphSchema(_ database: OpaquePointer) throws {
    try executeWingmanGraphSQL(database, """
        CREATE TABLE threads (
          id TEXT, thread_source TEXT, title TEXT, first_user_message TEXT,
          cwd TEXT, rollout_path TEXT, created_at INTEGER, updated_at INTEGER,
          created_at_ms INTEGER, updated_at_ms INTEGER, tokens_used INTEGER, archived INTEGER
        );
        CREATE TABLE thread_spawn_edges (parent_thread_id TEXT, child_thread_id TEXT);
        """)
}

private func prepareWingmanGraphStatement(
    _ database: OpaquePointer,
    sql: String
) throws -> OpaquePointer {
    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
          let statement else {
        throw WingmanGraphTestFailure(message: String(cString: sqlite3_errmsg(database)))
    }
    return statement
}

private func insertWingmanGraphThread(
    _ statement: OpaquePointer,
    id: String,
    source: String,
    rolloutPath: String,
    tokens: Int64
) throws {
    try resetWingmanGraphStatement(statement)
    try bindWingmanGraphText(statement, index: 1, value: id)
    try bindWingmanGraphText(statement, index: 2, value: source)
    try bindWingmanGraphText(statement, index: 3, value: "Node")
    try bindWingmanGraphText(statement, index: 4, value: "Prompt")
    try bindWingmanGraphText(statement, index: 5, value: "/tmp/fixture")
    try bindWingmanGraphText(statement, index: 6, value: rolloutPath)
    sqlite3_bind_int64(statement, 7, 1_787_486_400)
    sqlite3_bind_int64(statement, 8, 1_787_486_400)
    sqlite3_bind_int64(statement, 9, 1_787_486_400_000)
    sqlite3_bind_int64(statement, 10, 1_787_486_400_000)
    sqlite3_bind_int64(statement, 11, tokens)
    sqlite3_bind_int64(statement, 12, 0)
    guard sqlite3_step(statement) == SQLITE_DONE else {
        throw WingmanGraphTestFailure(message: "Thread fixture insertion failed")
    }
}

private func insertWingmanGraphEdge(
    _ statement: OpaquePointer,
    parent: String,
    child: String
) throws {
    try resetWingmanGraphStatement(statement)
    try bindWingmanGraphText(statement, index: 1, value: parent)
    try bindWingmanGraphText(statement, index: 2, value: child)
    guard sqlite3_step(statement) == SQLITE_DONE else {
        throw WingmanGraphTestFailure(message: "Spawn-edge fixture insertion failed")
    }
}

private func resetWingmanGraphStatement(_ statement: OpaquePointer) throws {
    guard sqlite3_reset(statement) == SQLITE_OK,
          sqlite3_clear_bindings(statement) == SQLITE_OK else {
        throw WingmanGraphTestFailure(message: "SQLite fixture statement could not be reset")
    }
}

private func bindWingmanGraphText(
    _ statement: OpaquePointer,
    index: Int32,
    value: String
) throws {
    let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    let status = value.withCString { pointer in
        sqlite3_bind_text(statement, index, pointer, -1, transient)
    }
    guard status == SQLITE_OK else {
        throw WingmanGraphTestFailure(message: "SQLite fixture text binding failed")
    }
}

private func executeWingmanGraphSQL(_ database: OpaquePointer, _ sql: String) throws {
    var error: UnsafeMutablePointer<Int8>?
    let status = sqlite3_exec(database, sql, nil, nil, &error)
    defer { sqlite3_free(error) }
    guard status == SQLITE_OK else {
        let message = error.map { String(cString: $0) } ?? "SQLite error"
        throw WingmanGraphTestFailure(message: message)
    }
}

private func wingmanGraphErrorDetail(home: URL) throws -> String? {
    do {
        _ = try CodexWingmanEvidenceReader(homeDirectory: home).load()
        return nil
    } catch WingmanEvidenceReaderError.incompatibleTaskGraph(let detail) {
        return detail
    }
}

private struct WingmanGraphTestFailure: Error {
    let message: String
}
#endif
