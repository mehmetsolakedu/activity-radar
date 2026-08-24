import Darwin
import Foundation

@main
struct ContinuityStoreSelfTest {
    static func main() async throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("ActivityRadarStoreSelfTest-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: root) }

        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let day: TimeInterval = 24 * 60 * 60
        let store = RadarContinuityStore(
            rootDirectory: root,
            policy: RadarContinuityStorePolicy(
                maximumLedgerEvents: 4,
                ledgerRetentionInterval: 90 * day
            ),
            nowProvider: { now }
        )
        let rawTaskID = "raw-task-id-must-not-leak"
        let checkpoint = "PRIVATE-CHECKPOINT-SENTINEL"
        let nextAction = "PRIVATE-NEXT-ACTION-SENTINEL"
        let waitingOn = "PRIVATE-WAITING-SENTINEL"

        let initiallyEnabled = try await store.isResearchLoggingEnabled()
        try require(!initiallyEnabled, "research logging was not default-off")
        let disabled = try await store.appendResearchEvent(
            kind: .taskOpened,
            forTaskID: rawTaskID
        )
        try require(disabled == .loggingDisabled, "disabled research logger accepted an event")

        _ = try await store.save(
            capsule: RadarContinuityCapsule(
                checkpoint: checkpoint,
                nextAction: nextAction,
                waitingOn: waitingOn
            ),
            metadata: RadarContinuityMetadata(
                importance: .critical,
                deadline: Date(timeIntervalSince1970: 2_000_100_000)
            ),
            forTaskID: rawTaskID,
            at: now
        )
        let loaded = try await store.records(forTaskIDs: [rawTaskID])
        try require(loaded[rawTaskID]?.capsule.nextAction == nextAction, "continuity record did not round-trip")

        try await store.setResearchLoggingEnabled(true)
        let future = now.addingTimeInterval(60)
        let withinRetention = now.addingTimeInterval(-89 * day)
        let expired = now.addingTimeInterval(-91 * day)

        // Intentionally append a future event before older events. A later
        // out-of-order append must not treat the future record as invalid.
        try await append(
            .taskOpened,
            at: future,
            to: store,
            taskID: rawTaskID
        )
        try await append(
            .capsuleSaved,
            at: now,
            to: store,
            taskID: rawTaskID
        )
        try await append(
            .lifecycleConfirmed,
            at: withinRetention,
            to: store,
            taskID: rawTaskID
        )
        try await append(
            .lifecycleCorrected,
            at: expired,
            to: store,
            taskID: rawTaskID
        )

        let afterRetention = try await store.researchEvents(now: now)
        try require(
            afterRetention.map(\.kind) == [.lifecycleConfirmed, .capsuleSaved, .taskOpened],
            "out-of-order/future preservation or 90-day retention failed"
        )

        try await append(
            .snoozeSet,
            at: now.addingTimeInterval(-2 * day),
            to: store,
            taskID: rawTaskID
        )
        try await append(
            .taskResumed,
            at: now.addingTimeInterval(-day),
            to: store,
            taskID: rawTaskID
        )

        let boundedEvents = try await store.researchEvents(now: now)
        try require(
            boundedEvents.map(\.kind) == [.snoozeSet, .taskResumed, .capsuleSaved, .taskOpened],
            "maximum event limit did not retain the chronologically newest events"
        )

        let snapshot = try await store.researchExportSnapshot(now: now)
        let preview = snapshot.preview
        try require(preview.eventCount == boundedEvents.count, "snapshot preview count disagrees with ledger")
        try require(preview.oldestEventAt == now.addingTimeInterval(-2 * day), "snapshot oldest timestamp changed")
        try require(preview.newestEventAt == future, "snapshot future timestamp was discarded")
        try require(preview.estimatedJSONBytes == snapshot.data.count, "snapshot byte estimate disagrees with data")
        try require(preview.eventKindCounts.values.reduce(0, +) == preview.eventCount, "snapshot kind counts disagree")
        try require(preview.conditionCounts == ["continuityAndTriage": 4], "snapshot condition counts disagree")
        try require(!preview.containsHumanAuthoredText, "research preview reported authored content")

        let exportedObject = try JSONSerialization.jsonObject(with: snapshot.data)
        guard let exportedDictionary = exportedObject as? [String: Any],
              let exportedEvents = exportedDictionary["events"] as? [[String: Any]] else {
            throw StoreSelfTestFailure(message: "research snapshot JSON shape changed")
        }
        try require(exportedEvents.count == preview.eventCount, "snapshot preview and encoded event count diverged")
        let encodedKindCounts = Dictionary(
            grouping: exportedEvents.compactMap { $0["kind"] as? String },
            by: { $0 }
        ).mapValues(\.count)
        try require(encodedKindCounts == preview.eventKindCounts, "snapshot preview and encoded kinds diverged")

        let compatibilityPreview = try await store.researchExportPreview(now: now)
        let compatibilityData = try await store.researchExportData(now: now)
        try require(compatibilityPreview == snapshot.preview, "compatibility preview changed snapshot semantics")
        try require(compatibilityData == snapshot.data, "compatibility data changed snapshot semantics")

        let exportedText = String(decoding: snapshot.data, as: UTF8.self)
        for forbidden in [rawTaskID, checkpoint, nextAction, waitingOn] {
            try require(!exportedText.contains(forbidden), "research export leaked private content")
        }

        let continuityText = try String(
            contentsOf: root.appendingPathComponent("continuity-v1.json"),
            encoding: .utf8
        )
        try require(!continuityText.contains(rawTaskID), "continuity store persisted a raw task ID")
        try require(continuityText.contains(nextAction), "local continuity content was not preserved")

        let rootPermissions = try permissions(at: root, fileManager: fileManager)
        try require(rootPermissions == 0o700, "store directory permissions are not 700")
        for filename in ["continuity-v1.json", "research-ledger-v1.json", "pseudonym-salt-v1.bin"] {
            let url = root.appendingPathComponent(filename)
            let filePermissions = try permissions(at: url, fileManager: fileManager)
            try require(filePermissions == 0o600, "store file permissions are not 600")
        }

        // A store file must be private before the atomic rename makes it
        // visible. Refuse pathname-based chmod for regular files so this test
        // fails if persistence ever returns to create/rename-then-chmod.
        let secureCreationRoot = fileManager.temporaryDirectory
            .appendingPathComponent(
                "ActivityRadarSecureCreationSelfTest-\(UUID().uuidString)",
                isDirectory: true
            )
        defer { try? fileManager.removeItem(at: secureCreationRoot) }
        let noPostRenameChmod = NoRegularFileAttributeMutationManager()
        let temporaryFileProbe = SecureTemporaryFileProbe()
        let secureCreationStore = RadarContinuityStore(
            rootDirectory: secureCreationRoot,
            fileManager: noPostRenameChmod,
            temporaryFileObserver: { url, phase in
                try temporaryFileProbe.observe(url, phase: phase)
            }
        )
        _ = try await secureCreationStore.save(
            capsule: RadarContinuityCapsule(nextAction: "secure creation"),
            metadata: RadarContinuityMetadata(),
            forTaskID: "secure-creation-task",
            at: now
        )
        for filename in ["continuity-v1.json", "pseudonym-salt-v1.bin"] {
            let url = secureCreationRoot.appendingPathComponent(filename)
            let filePermissions = try permissions(
                at: url,
                fileManager: noPostRenameChmod
            )
            try require(
                filePermissions == 0o600,
                "securely created store file permissions are not 600"
            )
        }
        let temporaryObservations = temporaryFileProbe.observations
        let openedObservations = temporaryObservations.filter { $0.phase == .opened }
        let preparedObservations = temporaryObservations.filter { $0.phase == .preparedForWrite }
        try require(
            openedObservations.count == 2 && preparedObservations.count == 2,
            "secure salt/continuity writes did not expose both temporary-file phases to the probe"
        )
        try require(
            openedObservations.allSatisfy { ($0.permissions & ~0o600) == 0 },
            "store temporary file had permissions broader than 600 when opened"
        )
        try require(
            preparedObservations.allSatisfy { $0.permissions == 0o600 },
            "store temporary file was not exactly 600 before writing and rename"
        )
        try require(
            temporaryObservations.allSatisfy { $0.byteCount == 0 && $0.isRegularFile },
            "store temporary path was not an empty regular file when prepared"
        )

        let unsafeRoot = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/activity-radar-self-test-must-not-exist", isDirectory: true)
        let unsafeStore = RadarContinuityStore(rootDirectory: unsafeRoot)
        do {
            try await unsafeStore.setResearchLoggingEnabled(true)
            throw StoreSelfTestFailure(message: "~/.codex storage location was accepted")
        } catch is RadarContinuityStoreError {
            // Expected: validation rejects the path before any write.
        }
        try require(!fileManager.fileExists(atPath: unsafeRoot.path), "unsafe test path was created")

        try await store.clearResearchLedger()
        do {
            _ = try await store.appendResearchEvents(
                kind: .triageShown,
                forTaskIDs: ["batch-a", ""],
                condition: .continuityAndTriage,
                at: now
            )
            throw StoreSelfTestFailure(message: "invalid research batch was accepted")
        } catch RadarContinuityStoreError.emptyTaskID {
            // Expected: all pseudonyms are resolved before document mutation.
        }
        let eventsAfterInvalidBatch = try await store.researchEvents(now: now)
        try require(eventsAfterInvalidBatch.isEmpty, "invalid research batch left a partial event")

        let batchResult = try await store.appendResearchEvents(
            kind: .triageShown,
            forTaskIDs: ["batch-a", "batch-b", "batch-c"],
            condition: .continuityAndTriage,
            at: now
        )
        try require(batchResult == .stored, "valid research batch was rejected")
        let batchEvents = try await store.researchEvents(now: now)
        try require(batchEvents.count == 3, "research batch count changed")
        try require(Set(batchEvents.map(\.taskPseudonym)).count == 3, "research batch subjects were collapsed")
        let batchSnapshot = try await store.researchExportSnapshot(now: now)
        try require(
            batchSnapshot.preview.eventKindCounts == ["triageShown": 3],
            "research batch preview count changed"
        )

        try await store.clearResearchLedger()
        let emptyPreview = try await store.researchExportSnapshot(now: now).preview
        try require(emptyPreview.eventCount == 0, "research ledger clear failed")

        print("PASS  continuity store privacy and retention contract")
    }

    private static func append(
        _ kind: RadarResearchEventKind,
        at date: Date,
        to store: RadarContinuityStore,
        taskID: String
    ) async throws {
        let result = try await store.appendResearchEvent(
            kind: kind,
            forTaskID: taskID,
            condition: .continuityAndTriage,
            at: date
        )
        try require(result == .stored, "enabled research logger rejected \(kind.rawValue)")
    }

    private static func permissions(at url: URL, fileManager: FileManager) throws -> Int {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        guard let number = attributes[.posixPermissions] as? NSNumber else {
            throw StoreSelfTestFailure(message: "POSIX permissions missing for \(url.lastPathComponent)")
        }
        return number.intValue & 0o777
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        guard condition() else {
            throw StoreSelfTestFailure(message: message)
        }
    }
}

private struct StoreSelfTestFailure: LocalizedError {
    let message: String

    var errorDescription: String? {
        "Continuity store self-test failed: \(message)"
    }
}

private final class NoRegularFileAttributeMutationManager: FileManager, @unchecked Sendable {
    override func setAttributes(
        _ attributes: [FileAttributeKey: Any],
        ofItemAtPath path: String
    ) throws {
        var isDirectory = ObjCBool(false)
        if fileExists(atPath: path, isDirectory: &isDirectory), !isDirectory.boolValue {
            throw StoreSelfTestFailure(
                message: "store attempted a pathname-based permission change after file creation"
            )
        }
        try super.setAttributes(attributes, ofItemAtPath: path)
    }
}

private final class SecureTemporaryFileProbe: @unchecked Sendable {
    struct Observation {
        let byteCount: Int64
        let isRegularFile: Bool
        let permissions: Int
        let phase: RadarSecureTemporaryFilePhase
    }

    private let lock = NSLock()
    private var recorded: [Observation] = []

    var observations: [Observation] {
        lock.lock()
        defer { lock.unlock() }
        return recorded
    }

    func observe(_ url: URL, phase: RadarSecureTemporaryFilePhase) throws {
        guard url.lastPathComponent.hasSuffix(".tmp") else {
            throw StoreSelfTestFailure(message: "prepared store path was not a temporary file")
        }
        var metadata = stat()
        guard lstat(url.path, &metadata) == 0 else {
            throw StoreSelfTestFailure(message: "prepared temporary store file could not be inspected")
        }
        let observation = Observation(
            byteCount: metadata.st_size,
            isRegularFile: (metadata.st_mode & S_IFMT) == S_IFREG,
            permissions: Int(metadata.st_mode & 0o777),
            phase: phase
        )
        lock.lock()
        recorded.append(observation)
        lock.unlock()
    }
}
