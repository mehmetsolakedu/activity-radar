import CryptoKit
import Darwin
import Foundation

// This file deliberately has no dependency on ActivityRadarCore. The app can
// evolve its continuity model without coupling local persistence to Codex's
// read-only activity schema.

enum RadarContinuityImportance: Int, Codable, CaseIterable, Sendable {
    case low = 0
    case normal = 1
    case high = 2
    case critical = 3
}

struct RadarContinuityCapsule: Codable, Equatable, Sendable {
    var checkpoint: String?
    var nextAction: String?
    var waitingOn: String?

    init(
        checkpoint: String? = nil,
        nextAction: String? = nil,
        waitingOn: String? = nil
    ) {
        self.checkpoint = checkpoint
        self.nextAction = nextAction
        self.waitingOn = waitingOn
    }
}

struct RadarContinuityMetadata: Codable, Equatable, Sendable {
    var importance: RadarContinuityImportance
    var deadline: Date?
    var snoozeUntil: Date?
    var reviewAt: Date?

    init(
        importance: RadarContinuityImportance = .normal,
        deadline: Date? = nil,
        snoozeUntil: Date? = nil,
        reviewAt: Date? = nil
    ) {
        self.importance = importance
        self.deadline = deadline
        self.snoozeUntil = snoozeUntil
        self.reviewAt = reviewAt
    }
}

enum RadarContinuityLifecycleState: String, Codable, CaseIterable, Sendable {
    case current
    case waitingHuman
    case waitingExternal
    case blocked
    case dormant
    case likelyAbandoned
    case obsoleteConfirmed
    case completed
    case completedElsewhere
    case superseded
    case abandoned
    case duplicate
    case uncertain
}

enum RadarLifecycleDecisionReason: String, Codable, CaseIterable, Sendable {
    case userConfirmed
    case taskCompleted
    case completedElsewhere
    case supersededByOtherWork
    case noLongerRelevant
    case duplicateWork
    case waitingForPerson
    case waitingForExternalEvent
    case blockedByDependency
    case insufficientEvidence
    case other
}

enum RadarLifecycleDecisionSource: String, Codable, CaseIterable, Sendable {
    case user
    case policySuggestion
}

struct RadarLifecycleDecision: Codable, Equatable, Sendable {
    let state: RadarContinuityLifecycleState
    let reason: RadarLifecycleDecisionReason
    let source: RadarLifecycleDecisionSource
    let recordedAt: Date
    let revisitAt: Date?

    init(
        state: RadarContinuityLifecycleState,
        reason: RadarLifecycleDecisionReason,
        source: RadarLifecycleDecisionSource = .user,
        recordedAt: Date = Date(),
        revisitAt: Date? = nil
    ) {
        self.state = state
        self.reason = reason
        self.source = source
        self.recordedAt = recordedAt
        self.revisitAt = revisitAt
    }
}

struct RadarStoredContinuityRecord: Codable, Equatable, Identifiable, Sendable {
    let taskPseudonym: String
    var capsule: RadarContinuityCapsule
    var metadata: RadarContinuityMetadata
    var lifecycleHistory: [RadarLifecycleDecision]
    let createdAt: Date
    var updatedAt: Date

    var id: String { taskPseudonym }
    var currentLifecycle: RadarLifecycleDecision? { lifecycleHistory.last }
}

enum RadarResearchEventKind: String, Codable, CaseIterable, Sendable {
    case triageShown
    case insufficientEvidenceShown
    case taskOpened
    case taskResumed
    case firstMeaningfulAction
    case capsuleSaved
    case snoozeSet
    case lifecycleSuggested
    case lifecycleConfirmed
    case lifecycleCorrected
}

// Fixed values prevent a caller from accidentally placing a task title,
// prompt, path, checkpoint, or next-action text in the condition field.
enum RadarResearchCondition: String, Codable, CaseIterable, Sendable {
    case unspecified
    case baseline
    case continuitySupport
    case triageSupport
    case continuityAndTriage
}

// Privacy invariant: these are the only per-event fields written to disk or
// included in research exports. Raw task IDs and all human-authored text are
// accepted by neither this type nor the export type.
struct RadarResearchEvent: Codable, Equatable, Sendable {
    let taskPseudonym: String
    let kind: RadarResearchEventKind
    let occurredAt: Date
    let condition: RadarResearchCondition
}

struct RadarResearchExportPreview: Codable, Equatable, Sendable {
    let eventCount: Int
    let oldestEventAt: Date?
    let newestEventAt: Date?
    let eventKindCounts: [String: Int]
    let conditionCounts: [String: Int]
    let estimatedJSONBytes: Int
    let containsHumanAuthoredText: Bool
}

struct RadarResearchExportSnapshot: Equatable, Sendable {
    let preview: RadarResearchExportPreview
    let data: Data
}

enum RadarResearchAppendResult: Equatable, Sendable {
    case stored
    case loggingDisabled
}

struct RadarContinuityStorePolicy: Equatable, Sendable {
    var maximumContinuityRecords: Int
    var maximumLifecycleHistoryPerTask: Int
    var maximumLedgerEvents: Int
    var ledgerRetentionInterval: TimeInterval
    var maximumCheckpointLength: Int
    var maximumNextActionLength: Int
    var maximumWaitingOnLength: Int

    init(
        maximumContinuityRecords: Int = 2_000,
        maximumLifecycleHistoryPerTask: Int = 20,
        maximumLedgerEvents: Int = 10_000,
        ledgerRetentionInterval: TimeInterval = 90 * 24 * 60 * 60,
        maximumCheckpointLength: Int = 4_000,
        maximumNextActionLength: Int = 1_000,
        maximumWaitingOnLength: Int = 1_000
    ) {
        self.maximumContinuityRecords = max(1, maximumContinuityRecords)
        self.maximumLifecycleHistoryPerTask = max(1, maximumLifecycleHistoryPerTask)
        self.maximumLedgerEvents = max(1, maximumLedgerEvents)
        self.ledgerRetentionInterval = max(60, ledgerRetentionInterval)
        self.maximumCheckpointLength = max(1, maximumCheckpointLength)
        self.maximumNextActionLength = max(1, maximumNextActionLength)
        self.maximumWaitingOnLength = max(1, maximumWaitingOnLength)
    }
}

enum RadarContinuityStoreError: LocalizedError {
    case emptyTaskID
    case unsafeStorageLocation(String)
    case unsupportedSchema(file: String, version: Int)
    case corruptStore(file: String, underlying: Error)

    var errorDescription: String? {
        switch self {
        case .emptyTaskID:
            return "Boş görev kimliği yerel süreklilik kaydında kullanılamaz."
        case .unsafeStorageLocation(let path):
            return "AiWingman yerel verileri ~/.codex dışında tutulmalıdır: \(path)"
        case .unsupportedSchema(let file, let version):
            return "Desteklenmeyen AiWingman veri şeması (\(file), sürüm \(version))."
        case .corruptStore(let file, let underlying):
            return "AiWingman yerel veri dosyası okunamadı (\(file)): \(underlying.localizedDescription)"
        }
    }
}

enum RadarSecureTemporaryFilePhase: Equatable, Sendable {
    case opened
    case preparedForWrite
}

actor RadarContinuityStore {
    private struct ContinuityDocument: Codable {
        static let currentSchemaVersion = 1

        var schemaVersion: Int
        var records: [String: RadarStoredContinuityRecord]

        static var empty: ContinuityDocument {
            ContinuityDocument(schemaVersion: currentSchemaVersion, records: [:])
        }
    }

    private struct ResearchDocument: Codable {
        static let currentSchemaVersion = 1

        var schemaVersion: Int
        var isEnabled: Bool
        var events: [RadarResearchEvent]

        static var empty: ResearchDocument {
            ResearchDocument(
                schemaVersion: currentSchemaVersion,
                isEnabled: false,
                events: []
            )
        }
    }

    private struct ResearchExportDocument: Codable {
        let schemaVersion: Int
        let exportedAt: Date
        let events: [RadarResearchEvent]
    }

    private let fileManager: FileManager
    private let rootDirectory: URL
    private let policy: RadarContinuityStorePolicy
    private let nowProvider: @Sendable () -> Date
    private let temporaryFileObserver: (@Sendable (URL, RadarSecureTemporaryFilePhase) throws -> Void)?
    private var cachedSalt: Data?

    private var continuityURL: URL {
        rootDirectory.appendingPathComponent("continuity-v1.json", isDirectory: false)
    }

    private var researchURL: URL {
        rootDirectory.appendingPathComponent("research-ledger-v1.json", isDirectory: false)
    }

    private var saltURL: URL {
        rootDirectory.appendingPathComponent("pseudonym-salt-v1.bin", isDirectory: false)
    }

    init(
        rootDirectory: URL? = nil,
        policy: RadarContinuityStorePolicy = RadarContinuityStorePolicy(),
        fileManager: FileManager = .default,
        nowProvider: @escaping @Sendable () -> Date = { Date() },
        temporaryFileObserver: (@Sendable (URL, RadarSecureTemporaryFilePhase) throws -> Void)? = nil
    ) {
        self.fileManager = fileManager
        self.rootDirectory = rootDirectory
            ?? Self.defaultRootDirectory(fileManager: fileManager)
        self.policy = policy
        self.nowProvider = nowProvider
        self.temporaryFileObserver = temporaryFileObserver
    }

    // Raw task IDs are used only as ephemeral hash inputs. Neither this method
    // nor any caller-facing save API persists them.
    func pseudonym(forTaskID taskID: String) throws -> String {
        let normalized = taskID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            throw RadarContinuityStoreError.emptyTaskID
        }

        var input = Data("ActivityRadar.task.v1\u{0}".utf8)
        input.append(try loadOrCreateSalt())
        input.append(Data(normalized.utf8))
        return SHA256.hash(data: input)
            .map { String(format: "%02x", $0) }
            .joined()
    }

    func record(forTaskID taskID: String) throws -> RadarStoredContinuityRecord? {
        let key = try pseudonym(forTaskID: taskID)
        return try loadContinuityDocument().records[key]
    }

    // The returned dictionary is keyed by the caller's raw task IDs for cheap
    // ViewModel lookup. Those keys exist only in memory and are never encoded.
    func records(
        forTaskIDs taskIDs: [String]
    ) throws -> [String: RadarStoredContinuityRecord] {
        let document = try loadContinuityDocument()
        var result: [String: RadarStoredContinuityRecord] = [:]
        result.reserveCapacity(taskIDs.count)

        for taskID in Set(taskIDs) {
            let key = try pseudonym(forTaskID: taskID)
            if let record = document.records[key] {
                result[taskID] = record
            }
        }
        return result
    }

    func allRecords() throws -> [RadarStoredContinuityRecord] {
        try loadContinuityDocument().records.values.sorted {
            if $0.updatedAt != $1.updatedAt {
                return $0.updatedAt > $1.updatedAt
            }
            return $0.taskPseudonym < $1.taskPseudonym
        }
    }

    @discardableResult
    func save(
        capsule: RadarContinuityCapsule,
        metadata: RadarContinuityMetadata,
        forTaskID taskID: String,
        at date: Date = Date()
    ) throws -> RadarStoredContinuityRecord {
        let key = try pseudonym(forTaskID: taskID)
        var document = try loadContinuityDocument()
        let existing = document.records[key]
        var record = RadarStoredContinuityRecord(
            taskPseudonym: key,
            capsule: normalized(capsule),
            metadata: metadata,
            lifecycleHistory: existing?.lifecycleHistory ?? [],
            createdAt: existing?.createdAt ?? date,
            updatedAt: date
        )
        record.lifecycleHistory = boundedLifecycleHistory(record.lifecycleHistory)
        document.records[key] = record
        pruneContinuityDocument(&document)
        try write(document, to: continuityURL)
        return record
    }

    @discardableResult
    func appendLifecycleDecision(
        _ decision: RadarLifecycleDecision,
        forTaskID taskID: String
    ) throws -> RadarStoredContinuityRecord {
        let key = try pseudonym(forTaskID: taskID)
        var document = try loadContinuityDocument()
        var record = document.records[key] ?? RadarStoredContinuityRecord(
            taskPseudonym: key,
            capsule: RadarContinuityCapsule(),
            metadata: RadarContinuityMetadata(),
            lifecycleHistory: [],
            createdAt: decision.recordedAt,
            updatedAt: decision.recordedAt
        )
        record.lifecycleHistory.append(decision)
        record.lifecycleHistory = boundedLifecycleHistory(record.lifecycleHistory)
        record.updatedAt = max(record.updatedAt, decision.recordedAt)
        document.records[key] = record
        pruneContinuityDocument(&document)
        try write(document, to: continuityURL)
        return record
    }

    func removeRecord(forTaskID taskID: String) throws {
        let key = try pseudonym(forTaskID: taskID)
        var document = try loadContinuityDocument()
        guard document.records.removeValue(forKey: key) != nil else { return }
        try write(document, to: continuityURL)
    }

    func clearContinuityRecords() throws {
        try write(ContinuityDocument.empty, to: continuityURL)
    }

    func isResearchLoggingEnabled() throws -> Bool {
        try loadResearchDocument().isEnabled
    }

    func setResearchLoggingEnabled(_ isEnabled: Bool) throws {
        var document = try loadResearchDocument()
        document.isEnabled = isEnabled
        _ = pruneResearchDocument(&document, now: nowProvider())
        try write(document, to: researchURL)
    }

    @discardableResult
    func appendResearchEvent(
        kind: RadarResearchEventKind,
        forTaskID taskID: String,
        condition: RadarResearchCondition = .unspecified,
        at date: Date = Date()
    ) throws -> RadarResearchAppendResult {
        try appendResearchEvents(
            kind: kind,
            forTaskIDs: [taskID],
            condition: condition,
            at: date
        )
    }

    @discardableResult
    func appendResearchEvents(
        kind: RadarResearchEventKind,
        forTaskIDs taskIDs: [String],
        condition: RadarResearchCondition = .unspecified,
        at date: Date = Date()
    ) throws -> RadarResearchAppendResult {
        var document = try loadResearchDocument()
        guard document.isEnabled else {
            return .loggingDisabled
        }

        // Resolve every subject before mutating the document. If any ID is
        // invalid, the batch fails without a partial event write.
        let taskPseudonyms = try taskIDs.map(pseudonym(forTaskID:))
        document.events.append(contentsOf: taskPseudonyms.map {
            RadarResearchEvent(
                taskPseudonym: $0,
                kind: kind,
                occurredAt: date,
                condition: condition
            )
        })
        // Retention is evaluated against store time, never the event's own
        // timestamp. Actor scheduling and clock corrections can legitimately
        // deliver events out of chronological order.
        _ = pruneResearchDocument(&document, now: nowProvider())
        try write(document, to: researchURL)
        return .stored
    }

    func researchEvents(now: Date = Date()) throws -> [RadarResearchEvent] {
        var document = try loadResearchDocument()
        if pruneResearchDocument(&document, now: now) {
            try write(document, to: researchURL)
        }
        return document.events
    }

    func researchExportSnapshot(
        now: Date = Date()
    ) throws -> RadarResearchExportSnapshot {
        let document = try decodedResearchDocumentAfterPruning(now: now)
        let events = document.events
        let export = ResearchExportDocument(
            schemaVersion: ResearchDocument.currentSchemaVersion,
            exportedAt: now,
            events: events
        )
        let exportData = try encoder().encode(export)
        let kindCounts = Dictionary(grouping: events, by: { $0.kind.rawValue })
            .mapValues(\.count)
        let conditionCounts = Dictionary(grouping: events, by: { $0.condition.rawValue })
            .mapValues(\.count)

        return RadarResearchExportSnapshot(
            preview: RadarResearchExportPreview(
                eventCount: events.count,
                oldestEventAt: events.map(\.occurredAt).min(),
                newestEventAt: events.map(\.occurredAt).max(),
                eventKindCounts: kindCounts,
                conditionCounts: conditionCounts,
                estimatedJSONBytes: exportData.count,
                containsHumanAuthoredText: false
            ),
            data: exportData
        )
    }

    func researchExportPreview(
        now: Date = Date()
    ) throws -> RadarResearchExportPreview {
        try researchExportSnapshot(now: now).preview
    }

    // Callers should present researchExportPreview() and obtain explicit user
    // consent before writing this returned data outside the app container.
    func researchExportData(now: Date = Date()) throws -> Data {
        try researchExportSnapshot(now: now).data
    }

    func clearResearchLedger() throws {
        var document = try loadResearchDocument()
        document.events = []
        try write(document, to: researchURL)
    }

    // Clears all AiWingman-owned local state and rotates the pseudonym
    // salt. It never touches ~/.codex or Codex-owned files.
    func clearAllLocalData() throws {
        try validateStorageLocation()
        for url in [continuityURL, researchURL, saltURL]
        where fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
        cachedSalt = nil
    }

    private static func defaultRootDirectory(fileManager: FileManager) -> URL {
        let base = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support", isDirectory: true)
        return base.appendingPathComponent("Activity Radar", isDirectory: true)
    }

    private func validateStorageLocation() throws {
        let candidate = rootDirectory.standardizedFileURL.resolvingSymlinksInPath()
        let codex = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex", isDirectory: true)
            .standardizedFileURL
            .resolvingSymlinksInPath()
        let candidatePath = candidate.path
        let codexPath = codex.path
        guard candidatePath != codexPath,
              !candidatePath.hasPrefix(codexPath + "/") else {
            throw RadarContinuityStoreError.unsafeStorageLocation(candidatePath)
        }
    }

    private func ensureRootDirectory() throws {
        try validateStorageLocation()
        try fileManager.createDirectory(
            at: rootDirectory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try fileManager.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: rootDirectory.path
        )
    }

    private func loadOrCreateSalt() throws -> Data {
        if let cachedSalt {
            return cachedSalt
        }
        try ensureRootDirectory()
        if fileManager.fileExists(atPath: saltURL.path) {
            let data = try Data(contentsOf: saltURL)
            guard data.count >= 32 else {
                throw RadarContinuityStoreError.corruptStore(
                    file: saltURL.lastPathComponent,
                    underlying: CocoaError(.fileReadCorruptFile)
                )
            }
            cachedSalt = data
            return data
        }

        let key = SymmetricKey(size: .bits256)
        let data = key.withUnsafeBytes { Data($0) }
        try writeRawData(data, to: saltURL)
        cachedSalt = data
        return data
    }

    private func loadContinuityDocument() throws -> ContinuityDocument {
        try validateStorageLocation()
        guard fileManager.fileExists(atPath: continuityURL.path) else {
            return .empty
        }
        let document: ContinuityDocument = try decode(from: continuityURL)
        guard document.schemaVersion == ContinuityDocument.currentSchemaVersion else {
            throw RadarContinuityStoreError.unsupportedSchema(
                file: continuityURL.lastPathComponent,
                version: document.schemaVersion
            )
        }
        return document
    }

    private func loadResearchDocument() throws -> ResearchDocument {
        try validateStorageLocation()
        guard fileManager.fileExists(atPath: researchURL.path) else {
            return .empty
        }
        let document: ResearchDocument = try decode(from: researchURL)
        guard document.schemaVersion == ResearchDocument.currentSchemaVersion else {
            throw RadarContinuityStoreError.unsupportedSchema(
                file: researchURL.lastPathComponent,
                version: document.schemaVersion
            )
        }
        return document
    }

    private func decodedResearchDocumentAfterPruning(
        now: Date
    ) throws -> ResearchDocument {
        var document = try loadResearchDocument()
        if pruneResearchDocument(&document, now: now) {
            try write(document, to: researchURL)
        }
        return document
    }

    private func decode<T: Decodable>(from url: URL) throws -> T {
        do {
            return try decoder().decode(T.self, from: Data(contentsOf: url))
        } catch let error as RadarContinuityStoreError {
            throw error
        } catch {
            throw RadarContinuityStoreError.corruptStore(
                file: url.lastPathComponent,
                underlying: error
            )
        }
    }

    private func write<T: Encodable>(_ value: T, to url: URL) throws {
        try writeRawData(try encoder().encode(value), to: url)
    }

    private func writeRawData(_ data: Data, to url: URL) throws {
        try ensureRootDirectory()
        let openedTemporaryFile = try openSecureTemporaryFile(nextTo: url)
        let temporaryURL = openedTemporaryFile.url
        var descriptor = openedTemporaryFile.descriptor
        var renamed = false

        defer {
            if descriptor >= 0 {
                _ = Darwin.close(descriptor)
            }
            if !renamed {
                _ = Darwin.unlink(temporaryURL.path)
            }
        }
        try temporaryFileObserver?(temporaryURL, .opened)

        // A restrictive process umask may remove bits from the requested mode,
        // so set the exact private mode on the still-empty descriptor. The file
        // is never broader than 0600 and no pathname-based post-rename chmod is
        // required.
        while Darwin.fchmod(descriptor, mode_t(0o600)) != 0 {
            if errno == EINTR { continue }
            throw posixWriteError(
                operation: "set secure temporary-file permissions",
                path: temporaryURL.path,
                errorNumber: errno
            )
        }
        try temporaryFileObserver?(temporaryURL, .preparedForWrite)

        try data.withUnsafeBytes { bytes in
            guard let baseAddress = bytes.baseAddress else { return }
            var offset = 0
            while offset < bytes.count {
                let written = Darwin.write(
                    descriptor,
                    baseAddress.advanced(by: offset),
                    bytes.count - offset
                )
                if written < 0 {
                    if errno == EINTR { continue }
                    throw posixWriteError(
                        operation: "write secure temporary file",
                        path: temporaryURL.path,
                        errorNumber: errno
                    )
                }
                guard written > 0 else {
                    throw posixWriteError(
                        operation: "write secure temporary file",
                        path: temporaryURL.path,
                        errorNumber: EIO
                    )
                }
                offset += written
            }
        }

        while Darwin.fsync(descriptor) != 0 {
            if errno == EINTR { continue }
            throw posixWriteError(
                operation: "sync secure temporary file",
                path: temporaryURL.path,
                errorNumber: errno
            )
        }

        let closeResult = Darwin.close(descriptor)
        descriptor = -1
        guard closeResult == 0 else {
            throw posixWriteError(
                operation: "close secure temporary file",
                path: temporaryURL.path,
                errorNumber: errno
            )
        }

        guard Darwin.rename(temporaryURL.path, url.path) == 0 else {
            throw posixWriteError(
                operation: "atomically replace store file",
                path: url.path,
                errorNumber: errno
            )
        }
        renamed = true
        try syncContainingDirectory(of: url)
    }

    private func openSecureTemporaryFile(
        nextTo url: URL
    ) throws -> (url: URL, descriptor: Int32) {
        let parent = url.deletingLastPathComponent()
        for _ in 0..<16 {
            let candidate = parent.appendingPathComponent(
                ".\(url.lastPathComponent).\(UUID().uuidString).tmp",
                isDirectory: false
            )
            let descriptor = Darwin.open(
                candidate.path,
                O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW,
                mode_t(0o600)
            )
            if descriptor >= 0 {
                return (candidate, descriptor)
            }
            let errorNumber = errno
            if errorNumber == EEXIST { continue }
            throw posixWriteError(
                operation: "create secure temporary file",
                path: candidate.path,
                errorNumber: errorNumber
            )
        }
        throw posixWriteError(
            operation: "create uniquely named secure temporary file",
            path: parent.path,
            errorNumber: EEXIST
        )
    }

    private func posixWriteError(
        operation: String,
        path: String,
        errorNumber: Int32
    ) -> NSError {
        NSError(
            domain: NSPOSIXErrorDomain,
            code: Int(errorNumber),
            userInfo: [
                NSFilePathErrorKey: path,
                NSLocalizedDescriptionKey: "Failed to \(operation): \(String(cString: strerror(errorNumber)))"
            ]
        )
    }

    private func syncContainingDirectory(of url: URL) throws {
        let directoryURL = url.deletingLastPathComponent()
        var descriptor = Darwin.open(
            directoryURL.path,
            O_RDONLY | O_DIRECTORY | O_CLOEXEC
        )
        guard descriptor >= 0 else {
            throw posixWriteError(
                operation: "open store directory for sync",
                path: directoryURL.path,
                errorNumber: errno
            )
        }
        defer {
            if descriptor >= 0 {
                _ = Darwin.close(descriptor)
            }
        }

        while Darwin.fsync(descriptor) != 0 {
            if errno == EINTR { continue }
            throw posixWriteError(
                operation: "sync atomic store-file replacement",
                path: directoryURL.path,
                errorNumber: errno
            )
        }

        let closeResult = Darwin.close(descriptor)
        descriptor = -1
        guard closeResult == 0 else {
            throw posixWriteError(
                operation: "close synced store directory",
                path: directoryURL.path,
                errorNumber: errno
            )
        }
    }

    private func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private func normalized(_ capsule: RadarContinuityCapsule) -> RadarContinuityCapsule {
        RadarContinuityCapsule(
            checkpoint: normalizedText(
                capsule.checkpoint,
                maximumLength: policy.maximumCheckpointLength
            ),
            nextAction: normalizedText(
                capsule.nextAction,
                maximumLength: policy.maximumNextActionLength
            ),
            waitingOn: normalizedText(
                capsule.waitingOn,
                maximumLength: policy.maximumWaitingOnLength
            )
        )
    }

    private func normalizedText(_ value: String?, maximumLength: Int) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(maximumLength))
    }

    private func boundedLifecycleHistory(
        _ history: [RadarLifecycleDecision]
    ) -> [RadarLifecycleDecision] {
        Array(
            history
                .sorted { $0.recordedAt < $1.recordedAt }
                .suffix(policy.maximumLifecycleHistoryPerTask)
        )
    }

    private func pruneContinuityDocument(_ document: inout ContinuityDocument) {
        guard document.records.count > policy.maximumContinuityRecords else { return }
        let keep = document.records.values
            .sorted {
                if $0.updatedAt != $1.updatedAt {
                    return $0.updatedAt > $1.updatedAt
                }
                return $0.taskPseudonym < $1.taskPseudonym
            }
            .prefix(policy.maximumContinuityRecords)
        document.records = Dictionary(uniqueKeysWithValues: keep.map {
            ($0.taskPseudonym, $0)
        })
    }

    @discardableResult
    private func pruneResearchDocument(
        _ document: inout ResearchDocument,
        now: Date
    ) -> Bool {
        let original = document.events
        let cutoff = now.addingTimeInterval(-policy.ledgerRetentionInterval)
        let retained = document.events
            .enumerated()
            .filter { $0.element.occurredAt >= cutoff }
            .sorted { left, right in
                if left.element.occurredAt != right.element.occurredAt {
                    return left.element.occurredAt < right.element.occurredAt
                }
                return left.offset < right.offset
            }
            .suffix(policy.maximumLedgerEvents)
            .map(\.element)
        document.events = Array(retained)
        return document.events != original
    }
}
