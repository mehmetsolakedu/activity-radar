import Foundation
import SQLite3

final class SQLiteReadOnly {
    private var database: OpaquePointer?
    private let path: String

    init(path: String, testingBeforeOpen: (() throws -> Void)? = nil) throws {
        self.path = path
        let originalURL = URL(fileURLWithPath: path).standardizedFileURL
        var status = stat()
        guard lstat(originalURL.path, &status) == 0,
              status.st_mode & S_IFMT == S_IFREG,
              status.st_uid == geteuid() else {
            throw ActivityReaderError.sqliteOpen(path: path, message: "Güvenli düzenli dosya doğrulanamadı")
        }
        let parentPath = originalURL.deletingLastPathComponent().path
        guard let canonicalParentPointer = parentPath.withCString({ realpath($0, nil) }) else {
            throw ActivityReaderError.sqliteOpen(path: path, message: "Üst dizin doğrulanamadı")
        }
        defer { free(canonicalParentPointer) }
        let openURL = URL(
            fileURLWithPath: String(cString: canonicalParentPointer),
            isDirectory: true
        ).appendingPathComponent(originalURL.lastPathComponent)
        try testingBeforeOpen?()
        var handle: OpaquePointer?
        let result = sqlite3_open_v2(
            openURL.path,
            &handle,
            SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX | SQLITE_OPEN_NOFOLLOW,
            nil
        )

        guard result == SQLITE_OK, let handle else {
            let message = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "Bilinmeyen SQLite hatası"
            if let handle {
                sqlite3_close(handle)
            }
            throw ActivityReaderError.sqliteOpen(path: path, message: message)
        }

        database = handle
        sqlite3_busy_timeout(handle, 300)

        guard sqlite3_exec(handle, "PRAGMA query_only=ON;", nil, nil, nil) == SQLITE_OK else {
            let message = String(cString: sqlite3_errmsg(handle))
            sqlite3_close(handle)
            database = nil
            throw ActivityReaderError.sqliteOpen(path: path, message: message)
        }
    }

    deinit {
        if let database {
            sqlite3_close(database)
        }
    }

    func withReadTransaction<T>(_ body: () throws -> T) throws -> T {
        try execute("BEGIN DEFERRED TRANSACTION;")
        do {
            let value = try body()
            try execute("COMMIT;")
            return value
        } catch {
            try? execute("ROLLBACK;")
            throw error
        }
    }

    func rows(
        sql: String,
        bind: ((OpaquePointer) -> Void)? = nil,
        map: (OpaquePointer) throws -> Void
    ) throws {
        guard let database else {
            throw ActivityReaderError.sqliteOpen(path: path, message: "Bağlantı kapalı")
        }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            throw ActivityReaderError.sqliteQuery(message: String(cString: sqlite3_errmsg(database)))
        }
        defer { sqlite3_finalize(statement) }

        bind?(statement)

        while true {
            let result = sqlite3_step(statement)
            if result == SQLITE_ROW {
                try map(statement)
            } else if result == SQLITE_DONE {
                return
            } else {
                throw ActivityReaderError.sqliteQuery(message: String(cString: sqlite3_errmsg(database)))
            }
        }
    }

    func tableColumns(_ table: String) throws -> Set<String> {
        var result = Set<String>()
        try rows(sql: "PRAGMA table_info(\(table));") { statement in
            result.insert(Self.text(statement, index: 1))
        }
        return result
    }

    private func execute(_ sql: String) throws {
        guard let database else {
            throw ActivityReaderError.sqliteOpen(path: path, message: "Bağlantı kapalı")
        }
        guard sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK else {
            throw ActivityReaderError.sqliteQuery(message: String(cString: sqlite3_errmsg(database)))
        }
    }

    static func text(_ statement: OpaquePointer, index: Int32) -> String {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL,
              let value = sqlite3_column_text(statement, index) else {
            return ""
        }
        return String(cString: value)
    }

    static func optionalText(_ statement: OpaquePointer, index: Int32) -> String? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else {
            return nil
        }
        return text(statement, index: index)
    }

    static func int64(_ statement: OpaquePointer, index: Int32) -> Int64 {
        sqlite3_column_int64(statement, index)
    }

    static func byteCount(_ statement: OpaquePointer, index: Int32) -> Int {
        max(0, Int(sqlite3_column_bytes(statement, index)))
    }
}
