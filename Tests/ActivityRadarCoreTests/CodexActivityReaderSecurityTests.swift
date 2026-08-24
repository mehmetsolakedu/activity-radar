#if canImport(Testing)
import Foundation
import SQLite3
import Darwin
import Testing
@testable import ActivityRadarCore

@Test
func dashboardDoesNotReadRolloutOutsideCodexDirectory() throws {
    let fixture = try makeReaderFixture()
    defer { try? FileManager.default.removeItem(at: fixture.home) }

    let outsideRollout = fixture.home.appendingPathComponent("outside.jsonl")
    try writeRollout(to: outsideRollout, checkpoint: "OUTSIDE-ROLLOUT-SENTINEL")
    try createReaderState(
        in: fixture.codex,
        rows: [ReaderRow(id: "outside", title: "Outside", rolloutPath: outsideRollout.path)]
    )

    let snapshot = try CodexActivityReader(homeDirectory: fixture.home).load()
    let item = try #require(snapshot.items.first)

    #expect(snapshot.items.count == 1)
    #expect(!item.historyComplete)
    #expect(item.lastFinalAnswerAt == nil)
    #expect(!item.checkpoint.contains("OUTSIDE-ROLLOUT-SENTINEL"))
}

@Test
func dashboardRejectsSymlinkEvenWhenTargetIsInsideCodexDirectory() throws {
    let fixture = try makeReaderFixture()
    defer { try? FileManager.default.removeItem(at: fixture.home) }

    let target = fixture.codex.appendingPathComponent("target.jsonl")
    let link = fixture.codex.appendingPathComponent("linked.jsonl")
    try writeRollout(to: target, checkpoint: "SYMLINK-ROLLOUT-SENTINEL")
    try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
    try createReaderState(
        in: fixture.codex,
        rows: [ReaderRow(id: "symlink", title: "Symlink", rolloutPath: link.path)]
    )

    let snapshot = try CodexActivityReader(homeDirectory: fixture.home).load()
    let item = try #require(snapshot.items.first)

    #expect(snapshot.items.count == 1)
    #expect(!item.historyComplete)
    #expect(item.lastFinalAnswerAt == nil)
    #expect(!item.checkpoint.contains("SYMLINK-ROLLOUT-SENTINEL"))
}

@Test
func dashboardRejectsSymlinkedStateDatabase() throws {
    let fixture = try makeReaderFixture()
    defer { try? FileManager.default.removeItem(at: fixture.home) }

    let outsideState = fixture.home.appendingPathComponent("outside-state.sqlite")
    try createReaderState(at: outsideState, rows: [])
    try FileManager.default.createSymbolicLink(
        at: fixture.codex.appendingPathComponent("state_5.sqlite"),
        withDestinationURL: outsideState
    )

    do {
        _ = try CodexActivityReader(homeDirectory: fixture.home).load()
        #expect(Bool(false), "Expected the symlinked state database to be rejected")
    } catch let error as ActivityReaderError {
        guard case .sqliteOpen = error else {
            #expect(Bool(false), "Expected an sqliteOpen error")
            return
        }
    }
}

@Test
func sqliteReadOnlyNoFollowRejectsFinalComponentSwapAfterMetadataCheck() throws {
    let fixture = try makeReaderFixture()
    defer { try? FileManager.default.removeItem(at: fixture.home) }

    let state = fixture.codex.appendingPathComponent("state_5.sqlite")
    let outsideState = fixture.home.appendingPathComponent("outside-state.sqlite")
    try createReaderState(at: state, rows: [])
    try createReaderState(at: outsideState, rows: [])

    do {
        _ = try SQLiteReadOnly(path: state.path) {
            try FileManager.default.removeItem(at: state)
            try FileManager.default.createSymbolicLink(
                at: state,
                withDestinationURL: outsideState
            )
        }
        #expect(Bool(false), "Expected no-follow SQLite open to reject the swapped final component")
    } catch let error as ActivityReaderError {
        guard case .sqliteOpen = error else {
            #expect(Bool(false), "Expected an sqliteOpen error")
            return
        }
    }
}

@Test
func sqliteReadOnlyWALReadLimitsSourceMutationToSQLiteAuxiliaryState() throws {
    let fixture = try makeReaderFixture()
    defer { try? FileManager.default.removeItem(at: fixture.home) }

    let state = fixture.codex.appendingPathComponent("state_5.sqlite")
    let wal = URL(fileURLWithPath: state.path + "-wal")
    let shm = URL(fileURLWithPath: state.path + "-shm")
    try createDetachedWALFixture(at: state)

    let mainBefore = try Data(contentsOf: state)
    let walBefore = try Data(contentsOf: wal)
    let entriesBefore = try directoryEntryNames(at: fixture.codex)
    #expect(!entriesBefore.contains(shm.lastPathComponent))

    var count: Int64 = -1
    do {
        let database = try SQLiteReadOnly(path: state.path)
        try database.rows(sql: "SELECT COUNT(*) FROM probe;") { statement in
            count = SQLiteReadOnly.int64(statement, index: 0)
        }
    }

    let entriesAfter = try directoryEntryNames(at: fixture.codex)
    let addedEntries = entriesAfter.subtracting(entriesBefore)
    #expect(count == 1)
    #expect(try Data(contentsOf: state) == mainBefore)
    #expect(try Data(contentsOf: wal) == walBefore)
    #expect(entriesBefore.isSubset(of: entriesAfter))
    #expect(addedEntries.isSubset(of: [shm.lastPathComponent]))
}

@Test
func dashboardRejectsNonRegularRolloutWithoutFailingTheLoad() throws {
    let fixture = try makeReaderFixture()
    defer { try? FileManager.default.removeItem(at: fixture.home) }

    let directory = fixture.codex.appendingPathComponent("not-a-rollout", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
    try createReaderState(
        in: fixture.codex,
        rows: [ReaderRow(id: "directory", title: "Directory", rolloutPath: directory.path)]
    )

    let snapshot = try CodexActivityReader(homeDirectory: fixture.home).load()
    let item = try #require(snapshot.items.first)

    #expect(snapshot.items.count == 1)
    #expect(!item.historyComplete)
    #expect(item.lastFinalAnswerAt == nil)
}

@Test
func sessionIndexReadsOnlyTheBoundedTailAndStillUsesRecentNames() throws {
    let fixture = try makeReaderFixture()
    defer { try? FileManager.default.removeItem(at: fixture.home) }

    let headRollout = fixture.codex.appendingPathComponent("head.jsonl")
    let tailRollout = fixture.codex.appendingPathComponent("tail.jsonl")
    try writeRollout(to: headRollout, checkpoint: "Head checkpoint")
    try writeRollout(to: tailRollout, checkpoint: "Tail checkpoint")
    try createReaderState(
        in: fixture.codex,
        rows: [
            ReaderRow(id: "head", title: "Database Head", rolloutPath: headRollout.path),
            ReaderRow(id: "tail", title: "Database Tail", rolloutPath: tailRollout.path),
        ]
    )

    var index = Data(#"{"id":"head","thread_name":"Unbounded Head Name"}"#.utf8)
    index.append(0x0A)
    index.append(Data(repeating: 0x78, count: Int(CodexActivityReader.sessionIndexReadLimit) + 512))
    index.append(0x0A)
    index.append(Data(#"{"id":"tail","thread_name":"Bounded Tail Name"}"#.utf8))
    index.append(0x0A)
    try index.write(to: fixture.codex.appendingPathComponent("session_index.jsonl"))

    let snapshot = try CodexActivityReader(homeDirectory: fixture.home).load()
    let titles = Dictionary(uniqueKeysWithValues: snapshot.items.map { ($0.id, $0.title) })
    let items = Dictionary(uniqueKeysWithValues: snapshot.items.map { ($0.id, $0) })

    #expect(titles["head"] == "Database Head")
    #expect(titles["tail"] == "Bounded Tail Name")
    #expect(items["head"]?.historyComplete == true)
    #expect(items["tail"]?.historyComplete == true)
    #expect(items["head"]?.checkpoint == "Head checkpoint")
    #expect(items["tail"]?.checkpoint == "Tail checkpoint")
}

@Test
func dashboardRejectsIntermediateSymlinkAndFIFOWithoutReadingOrBlocking() throws {
    let fixture = try makeReaderFixture()
    defer { try? FileManager.default.removeItem(at: fixture.home) }

    let realDirectory = fixture.codex.appendingPathComponent("real", isDirectory: true)
    let linkedDirectory = fixture.codex.appendingPathComponent("linked-directory", isDirectory: true)
    let linkedRollout = linkedDirectory.appendingPathComponent("rollout.jsonl")
    let fifo = fixture.codex.appendingPathComponent("rollout.fifo")
    try FileManager.default.createDirectory(at: realDirectory, withIntermediateDirectories: false)
    try writeRollout(
        to: realDirectory.appendingPathComponent("rollout.jsonl"),
        checkpoint: "INTERMEDIATE-SYMLINK-SENTINEL"
    )
    try FileManager.default.createSymbolicLink(at: linkedDirectory, withDestinationURL: realDirectory)
    guard mkfifo(fifo.path, mode_t(0o600)) == 0 else {
        throw ReaderSecurityTestFailure(message: "FIFO fixture could not be created")
    }
    try createReaderState(
        in: fixture.codex,
        rows: [
            ReaderRow(id: "linked", title: "Linked", rolloutPath: linkedRollout.path),
            ReaderRow(id: "fifo", title: "FIFO", rolloutPath: fifo.path),
        ]
    )

    let started = DispatchTime.now().uptimeNanoseconds
    let snapshot = try CodexActivityReader(homeDirectory: fixture.home).load()
    let elapsed = Double(DispatchTime.now().uptimeNanoseconds - started) / 1_000_000_000

    #expect(elapsed < 1)
    #expect(snapshot.items.count == 2)
    for item in snapshot.items {
        #expect(!item.historyComplete)
        #expect(item.lastFinalAnswerAt == nil)
        #expect(!item.checkpoint.contains("INTERMEDIATE-SYMLINK-SENTINEL"))
    }
}

@Test
func dashboardInvalidatesCacheAfterEqualLengthRolloutReplacement() throws {
    let fixture = try makeReaderFixture()
    defer { try? FileManager.default.removeItem(at: fixture.home) }

    let rollout = fixture.codex.appendingPathComponent("replaceable.jsonl")
    try writeRollout(to: rollout, checkpoint: "AAAAA")
    try createReaderState(
        in: fixture.codex,
        rows: [ReaderRow(id: "replaceable", title: "Replaceable", rolloutPath: rollout.path)]
    )
    let reader = CodexActivityReader(homeDirectory: fixture.home)
    #expect(try reader.load().items.first?.checkpoint == "AAAAA")

    try writeRollout(to: rollout, checkpoint: "BBBBB")
    let refreshed = try reader.load()

    #expect(refreshed.items.first?.checkpoint == "BBBBB")
    #expect(refreshed.items.first?.historyComplete == true)
}

@Test
func dashboardRebuildsCacheAfterSameInodePrefixRewriteAndGrowth() throws {
    let fixture = try makeReaderFixture()
    defer { try? FileManager.default.removeItem(at: fixture.home) }

    let rollout = fixture.codex.appendingPathComponent("rewrite-and-grow.jsonl")
    try writeRollout(to: rollout, checkpoint: "ORIGINAL")
    try createReaderState(
        in: fixture.codex,
        rows: [ReaderRow(id: "rewrite", title: "Rewrite", rolloutPath: rollout.path)]
    )
    let reader = CodexActivityReader(homeDirectory: fixture.home)
    #expect(try reader.load().items.first?.checkpoint == "ORIGINAL")

    let originalStatus = try #require(fileIdentity(at: rollout))
    let replacement = rolloutData(checkpoint: "REPLACED-WITH-A-LONGER-CHECKPOINT")
    let handle = try FileHandle(forWritingTo: rollout)
    try handle.truncate(atOffset: 0)
    try handle.write(contentsOf: replacement)
    try handle.synchronize()
    try handle.close()
    let replacementStatus = try #require(fileIdentity(at: rollout))

    #expect(originalStatus.device == replacementStatus.device)
    #expect(originalStatus.inode == replacementStatus.inode)
    #expect(replacementStatus.size > originalStatus.size)
    let refreshed = try reader.load()
    #expect(refreshed.items.first?.checkpoint == "REPLACED-WITH-A-LONGER-CHECKPOINT")
}

@Test
func dashboardProcessesValidFinalJSONWithoutTrailingNewline() throws {
    let fixture = try makeReaderFixture()
    defer { try? FileManager.default.removeItem(at: fixture.home) }

    let rollout = fixture.codex.appendingPathComponent("valid-unterminated-final.jsonl")
    var finalLine = rolloutData(checkpoint: "Valid final object")
    #expect(finalLine.last == 0x0A)
    finalLine.removeLast()
    try finalLine.write(to: rollout)
    try createReaderState(
        in: fixture.codex,
        rows: [ReaderRow(id: "valid-final", title: "Valid final", rolloutPath: rollout.path)]
    )

    let item = try CodexActivityReader(homeDirectory: fixture.home).load().items.first

    #expect(item?.checkpoint == "Valid final object")
    #expect(item?.historyComplete == true)
}

@Test
func dashboardProcessesNewlineFreeFinalEventAfterEarlierCompleteLines() throws {
    let fixture = try makeReaderFixture()
    defer { try? FileManager.default.removeItem(at: fixture.home) }

    let rollout = fixture.codex.appendingPathComponent("ordered-unterminated-final.jsonl")
    let started = #"{"timestamp":"2026-08-23T12:00:00Z","type":"event_msg","payload":{"type":"task_started","turn_id":"turn-1"}}"#
    let completed = #"{"timestamp":"2026-08-23T12:00:01Z","type":"event_msg","payload":{"type":"task_complete","turn_id":"turn-1"}}"#
    try Data((started + "\n" + completed).utf8).write(to: rollout)
    try createReaderState(
        in: fixture.codex,
        rows: [ReaderRow(id: "ordered-final", title: "Ordered final", rolloutPath: rollout.path)]
    )

    let item = try CodexActivityReader(homeDirectory: fixture.home).load().items.first

    #expect(item?.executionState == .completed)
    #expect(item?.historyComplete == true)
}

@Test
func dashboardMarksTruncatedFinalJSONIncomplete() throws {
    let fixture = try makeReaderFixture()
    defer { try? FileManager.default.removeItem(at: fixture.home) }

    let rollout = fixture.codex.appendingPathComponent("truncated-final.jsonl")
    var data = rolloutData(checkpoint: "Last complete object")
    data.append(Data(#"{"timestamp":"2026-08-23T12:00:01Z","type":"event_msg","payload":{"type":"agent_message""#.utf8))
    try data.write(to: rollout)
    try createReaderState(
        in: fixture.codex,
        rows: [ReaderRow(id: "truncated-final", title: "Truncated final", rolloutPath: rollout.path)]
    )

    let item = try CodexActivityReader(homeDirectory: fixture.home).load().items.first

    #expect(item?.checkpoint == "Last complete object")
    #expect(item?.historyComplete == false)
}

@Test
func dashboardMarksMalformedNewlineTerminatedJSONIncomplete() throws {
    let fixture = try makeReaderFixture()
    defer { try? FileManager.default.removeItem(at: fixture.home) }

    let rollout = fixture.codex.appendingPathComponent("malformed-complete-line.jsonl")
    var data = rolloutData(checkpoint: "Last valid object")
    data.append(Data("{\"timestamp\":}\n".utf8))
    try data.write(to: rollout)
    try createReaderState(
        in: fixture.codex,
        rows: [ReaderRow(id: "malformed-line", title: "Malformed line", rolloutPath: rollout.path)]
    )

    let item = try CodexActivityReader(homeDirectory: fixture.home).load().items.first

    #expect(item?.checkpoint == "Last valid object")
    #expect(item?.historyComplete == false)
}

@Test
func dashboardBoundsUnterminatedCarryAndRecoversAfterNewline() throws {
    let fixture = try makeReaderFixture()
    defer { try? FileManager.default.removeItem(at: fixture.home) }

    let rollout = fixture.codex.appendingPathComponent("oversized-line.jsonl")
    try writeRollout(to: rollout, checkpoint: "Before oversized line")
    try createReaderState(
        in: fixture.codex,
        rows: [ReaderRow(id: "oversized", title: "Oversized", rolloutPath: rollout.path)]
    )
    let reader = CodexActivityReader(homeDirectory: fixture.home)
    #expect(try reader.load().items.first?.checkpoint == "Before oversized line")

    let handle = try FileHandle(forWritingTo: rollout)
    defer { try? handle.close() }
    try handle.seekToEnd()
    try handle.write(contentsOf: Data(repeating: 0x78, count: 1_048_577))
    try handle.synchronize()
    let incomplete = try reader.load()
    #expect(incomplete.items.first?.historyComplete == false)

    try handle.write(contentsOf: Data("\n".utf8))
    let recoveredLine = #"{"timestamp":"2026-08-23T12:00:01Z","type":"event_msg","payload":{"type":"agent_message","phase":"final_answer","message":"Recovered checkpoint"}}"#
    try handle.write(contentsOf: Data((recoveredLine + "\n").utf8))
    try handle.synchronize()
    let recovered = try reader.load()

    #expect(recovered.items.first?.historyComplete == false)
    #expect(recovered.items.first?.checkpoint == "Recovered checkpoint")
}

@Test
func dashboardCapsGoalDrivenInclusionsAndTotalRows() throws {
    let fixture = try makeReaderFixture()
    defer { try? FileManager.default.removeItem(at: fixture.home) }

    let rows = (0..<250).map { index in
        ReaderRow(
            id: String(format: "00000000-0000-4000-8000-%012d", index),
            title: "Goal fixture \(index)",
            rolloutPath: fixture.codex.appendingPathComponent("missing-\(index).jsonl").path
        )
    }
    try createReaderState(in: fixture.codex, rows: rows)
    try createGoalState(
        in: fixture.codex,
        rows: rows.enumerated().map { index, row in
            GoalRow(threadID: row.id, status: "active", updatedAtMS: Int64(index + 1))
        }
    )

    let reader = CodexActivityReader(homeDirectory: fixture.home)
    let fullPage = try reader.load(limit: 200)
    #expect(fullPage.items.count == CodexActivityReader.maximumThreadLoadCount)
    #expect(fullPage.hasMore)

    let goalOnly = try reader.load(
        limit: 200,
        updatedAfter: Date(timeIntervalSince1970: 2_000_000_000)
    )
    #expect(goalOnly.items.count == CodexActivityReader.maximumIncludedThreadCount)
    #expect(goalOnly.hasMore)
    #expect(goalOnly.items.allSatisfy { $0.goalStatus == .active })
}

@Test
func dashboardSignalsWhenGoalDrivenInclusionsAloneExceedTheirCap() throws {
    let fixture = try makeReaderFixture()
    defer { try? FileManager.default.removeItem(at: fixture.home) }

    let rows = (0..<100).map { index in
        ReaderRow(
            id: String(format: "22222222-2222-4222-8222-%012d", index),
            title: "Bounded goal fixture \(index)",
            rolloutPath: fixture.codex.appendingPathComponent("missing-bounded-\(index).jsonl").path
        )
    }
    try createReaderState(in: fixture.codex, rows: rows)
    try createGoalState(
        in: fixture.codex,
        rows: rows.enumerated().map { index, row in
            GoalRow(threadID: row.id, status: "active", updatedAtMS: Int64(index + 1))
        }
    )

    let snapshot = try CodexActivityReader(homeDirectory: fixture.home).load(
        limit: 200,
        updatedAfter: Date(timeIntervalSince1970: 2_000_000_000)
    )

    #expect(snapshot.items.count == CodexActivityReader.maximumIncludedThreadCount)
    #expect(snapshot.hasMore)
    #expect(snapshot.items.allSatisfy { $0.goalStatus == .active })
}

@Test
func dashboardLoadsGoalMetadataForSelectedRowsOutsideTheInclusionWindow() throws {
    let fixture = try makeReaderFixture()
    defer { try? FileManager.default.removeItem(at: fixture.home) }

    let selectedID = String(format: "11111111-1111-4111-8111-%012d", 1)
    try createReaderState(
        in: fixture.codex,
        rows: [
            ReaderRow(
                id: selectedID,
                title: "Selected old goal",
                rolloutPath: fixture.codex.appendingPathComponent("missing-selected.jsonl").path
            )
        ]
    )
    var goals = (0..<250).map { index in
        GoalRow(
            threadID: String(format: "22222222-2222-4222-8222-%012d", index),
            status: "complete",
            updatedAtMS: Int64(index + 10)
        )
    }
    goals.append(GoalRow(threadID: selectedID, status: "blocked", updatedAtMS: 1))
    try createGoalState(in: fixture.codex, rows: goals)

    let item = try #require(
        CodexActivityReader(homeDirectory: fixture.home).load(limit: 1).items.first
    )
    #expect(item.id == selectedID)
    #expect(item.goalStatus == .blocked)
}

@Test
func dashboardRejectsOversizedOrdinaryThreadText() throws {
    let fixture = try makeReaderFixture()
    defer { try? FileManager.default.removeItem(at: fixture.home) }

    try createReaderState(
        in: fixture.codex,
        rows: [
            ReaderRow(
                id: String(format: "33333333-3333-4333-8333-%012d", 3),
                title: "Oversized preview",
                preview: String(repeating: "x", count: 64 * 1_024 + 1),
                rolloutPath: fixture.codex.appendingPathComponent("missing.jsonl").path
            )
        ]
    )

    do {
        _ = try CodexActivityReader(homeDirectory: fixture.home).load()
        #expect(Bool(false), "Expected oversized ordinary thread text to fail closed")
    } catch let error as ActivityReaderError {
        guard case .incompatibleSchema = error else {
            #expect(Bool(false), "Expected an incompatibleSchema error")
            return
        }
    }
}

@Test
func dashboardRejectsOversizedAggregateOrdinaryThreadText() throws {
    let fixture = try makeReaderFixture()
    defer { try? FileManager.default.removeItem(at: fixture.home) }

    let rows = (0..<150).map { index in
        ReaderRow(
            id: String(format: "44444444-4444-4444-8444-%012d", index),
            title: String(repeating: "t", count: 16 * 1_024),
            preview: String(repeating: "p", count: 64 * 1_024),
            cwd: String(repeating: "c", count: 16 * 1_024),
            rolloutPath: String(repeating: "r", count: 16 * 1_024)
        )
    }
    try createReaderState(in: fixture.codex, rows: rows)

    do {
        _ = try CodexActivityReader(homeDirectory: fixture.home).load(limit: 200)
        #expect(Bool(false), "Expected aggregate ordinary thread text to fail closed")
    } catch let error as ActivityReaderError {
        guard case .incompatibleSchema = error else {
            #expect(Bool(false), "Expected an incompatibleSchema error")
            return
        }
    }
}

@Test
func dashboardRejectsOversizedAggregateGoalText() throws {
    let fixture = try makeReaderFixture()
    defer { try? FileManager.default.removeItem(at: fixture.home) }

    try createReaderState(in: fixture.codex, rows: [])
    let goals = (0..<200).map { index in
        let prefix = String(format: "%04d-", index)
        return GoalRow(
            threadID: prefix + String(repeating: "g", count: 1_024 - prefix.utf8.count),
            status: "active",
            updatedAtMS: Int64(index)
        )
    }
    try createGoalState(in: fixture.codex, rows: goals)

    do {
        _ = try CodexActivityReader(homeDirectory: fixture.home).load()
        #expect(Bool(false), "Expected aggregate goal text to fail closed")
    } catch let error as ActivityReaderError {
        guard case .incompatibleSchema = error else {
            #expect(Bool(false), "Expected an incompatibleSchema error")
            return
        }
    }
}

private struct ReaderRow {
    let id: String
    let title: String
    let preview: String
    let cwd: String
    let rolloutPath: String

    init(
        id: String,
        title: String,
        preview: String = "Preview",
        cwd: String = "/tmp/project",
        rolloutPath: String
    ) {
        self.id = id
        self.title = title
        self.preview = preview
        self.cwd = cwd
        self.rolloutPath = rolloutPath
    }
}

private struct GoalRow {
    let threadID: String
    let status: String
    let updatedAtMS: Int64
}

private func makeReaderFixture() throws -> (home: URL, codex: URL) {
    let home = FileManager.default.temporaryDirectory
        .appendingPathComponent("ActivityRadar-ReaderSecurity-\(UUID().uuidString)", isDirectory: true)
    let codex = home.appendingPathComponent(".codex", isDirectory: true)
    try FileManager.default.createDirectory(at: codex, withIntermediateDirectories: true)
    return (home, codex)
}

private func writeRollout(to url: URL, checkpoint: String) throws {
    try rolloutData(checkpoint: checkpoint).write(to: url)
}

private func rolloutData(checkpoint: String) -> Data {
    let escapedCheckpoint = checkpoint
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
    let line = #"{"timestamp":"2026-08-23T12:00:00Z","type":"event_msg","payload":{"type":"agent_message","phase":"final_answer","message":"\#(escapedCheckpoint)"}}"#
    return Data((line + "\n").utf8)
}

private func fileIdentity(at url: URL) -> (device: UInt64, inode: UInt64, size: UInt64)? {
    var status = stat()
    guard lstat(url.path, &status) == 0, status.st_size >= 0 else { return nil }
    return (UInt64(status.st_dev), UInt64(status.st_ino), UInt64(status.st_size))
}

private func createReaderState(in codex: URL, rows: [ReaderRow]) throws {
    try createReaderState(at: codex.appendingPathComponent("state_5.sqlite"), rows: rows)
}

private func createReaderState(at state: URL, rows: [ReaderRow]) throws {
    var database: OpaquePointer?
    guard sqlite3_open(state.path, &database) == SQLITE_OK, let database else {
        if let database { sqlite3_close(database) }
        throw ReaderSecurityTestFailure(message: "SQLite fixture could not be opened")
    }
    defer { sqlite3_close(database) }

    try executeReaderSQL(database, """
        CREATE TABLE threads (
          id TEXT, title TEXT, preview TEXT, cwd TEXT, rollout_path TEXT,
          created_at INTEGER, updated_at INTEGER,
          created_at_ms INTEGER, updated_at_ms INTEGER,
          archived INTEGER, thread_source TEXT, recency_at_ms INTEGER
        );
        CREATE TABLE thread_spawn_edges (parent_thread_id TEXT, child_thread_id TEXT);
        """)

    for (index, row) in rows.enumerated() {
        let timestamp = 1_787_486_400_000 + index
        try executeReaderSQL(database, """
            INSERT INTO threads VALUES (
              '\(sqlLiteral(row.id))', '\(sqlLiteral(row.title))',
              '\(sqlLiteral(row.preview))', '\(sqlLiteral(row.cwd))',
              '\(sqlLiteral(row.rolloutPath))', 1787486400, 1787486400,
              1787486400000, \(timestamp), 0, 'user', \(timestamp)
            );
            """)
    }
}

private func createGoalState(in codex: URL, rows: [GoalRow]) throws {
    let state = codex.appendingPathComponent("goals_1.sqlite")
    var database: OpaquePointer?
    guard sqlite3_open(state.path, &database) == SQLITE_OK, let database else {
        if let database { sqlite3_close(database) }
        throw ReaderSecurityTestFailure(message: "Goal SQLite fixture could not be opened")
    }
    defer { sqlite3_close(database) }

    try executeReaderSQL(database, """
        CREATE TABLE thread_goals (
          thread_id TEXT, status TEXT, updated_at_ms INTEGER
        );
        """)
    for row in rows {
        try executeReaderSQL(database, """
            INSERT INTO thread_goals VALUES (
              '\(sqlLiteral(row.threadID))', '\(sqlLiteral(row.status))', \(row.updatedAtMS)
            );
            """)
    }
}

private func createDetachedWALFixture(at state: URL) throws {
    var database: OpaquePointer?
    guard sqlite3_open(state.path, &database) == SQLITE_OK, let database else {
        if let database { sqlite3_close(database) }
        throw ReaderSecurityTestFailure(message: "WAL fixture could not be opened")
    }
    var databaseIsOpen = true

    do {
        try executeReaderSQL(database, """
            PRAGMA journal_mode=WAL;
            PRAGMA wal_autocheckpoint=0;
            CREATE TABLE probe(value INTEGER);
            INSERT INTO probe VALUES (1);
            """)
        let mainSnapshot = try Data(contentsOf: state)
        let walURL = URL(fileURLWithPath: state.path + "-wal")
        let walSnapshot = try Data(contentsOf: walURL)
        sqlite3_close(database)
        databaseIsOpen = false

        try mainSnapshot.write(to: state)
        try walSnapshot.write(to: walURL)
        let shmURL = URL(fileURLWithPath: state.path + "-shm")
        if FileManager.default.fileExists(atPath: shmURL.path) {
            try FileManager.default.removeItem(at: shmURL)
        }
    } catch {
        if databaseIsOpen { sqlite3_close(database) }
        throw error
    }
}

private func directoryEntryNames(at directory: URL) throws -> Set<String> {
    Set(try FileManager.default.contentsOfDirectory(atPath: directory.path))
}

private func executeReaderSQL(_ database: OpaquePointer, _ sql: String) throws {
    var error: UnsafeMutablePointer<Int8>?
    let status = sqlite3_exec(database, sql, nil, nil, &error)
    defer { sqlite3_free(error) }
    guard status == SQLITE_OK else {
        let message = error.map { String(cString: $0) } ?? "SQLite error"
        throw ReaderSecurityTestFailure(message: message)
    }
}

private func sqlLiteral(_ value: String) -> String {
    value.replacingOccurrences(of: "'", with: "''")
}

private struct ReaderSecurityTestFailure: Error {
    let message: String
}
#endif
