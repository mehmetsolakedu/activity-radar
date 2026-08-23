import Foundation
import Dispatch
#if canImport(Testing)
import Testing
@testable import ActivityRadar

@Test
func wingmanTemporaryRootCleanupRemovesNestedAuthenticationArea() throws {
    let fileManager = FileManager.default
    let root = fileManager.temporaryDirectory.appendingPathComponent(
        "ActivityRadar-Wingman-cleanup-fixture-\(UUID().uuidString)",
        isDirectory: true
    )
    let codexHome = root.appendingPathComponent("codex-home", isDirectory: true)
    let authCopy = codexHome.appendingPathComponent("auth.json")
    defer { try? fileManager.removeItem(at: root) }

    try fileManager.createDirectory(
        at: codexHome,
        withIntermediateDirectories: true,
        attributes: [.posixPermissions: 0o700]
    )
    try Data("fixture-secret".utf8).write(to: authCopy, options: .withoutOverwriting)

    try WingmanTemporaryRootCleanup.remove(root)

    #expect(!fileManager.fileExists(atPath: root.path))
    #expect(!fileManager.fileExists(atPath: authCopy.path))
}

@Test
func wingmanTemporaryRootCleanupMapsInjectedFailureToSanitizedError() {
    let privatePath = "/" + "Users/" + "alice/.codex/auth.json"
    let injectedFailure = NSError(
        domain: "WingmanCleanupFixture",
        code: 13,
        userInfo: [
            NSLocalizedDescriptionKey: "Could not remove \(privatePath)",
            NSFilePathErrorKey: privatePath
        ]
    )

    do {
        _ = try WingmanTemporaryRootCleanup.perform(
            at: URL(fileURLWithPath: "/fixture/temporary-root"),
            remover: { _ in throw injectedFailure }
        ) {
            17
        }
        #expect(Bool(false), "Cleanup failure should reject an otherwise successful result")
    } catch let error as WingmanRunnerError {
        guard case .cleanupFailed = error else {
            #expect(Bool(false), "Expected a sanitized cleanup failure")
            return
        }
        for message in [
            error.message(language: .turkish),
            error.message(language: .english)
        ] {
            #expect(!message.contains("/" + "Users"))
            #expect(!message.contains("alice"))
            #expect(!message.contains("auth.json"))
        }
    } catch {
        #expect(Bool(false), "Expected WingmanRunnerError.cleanupFailed")
    }
}

@Test
func wingmanTemporaryRootCleanupPreservesCancellationAfterCleanupAttempt() {
    let recorder = CleanupAttemptRecorder()

    do {
        try WingmanTemporaryRootCleanup.perform(
            at: URL(fileURLWithPath: "/fixture/temporary-root"),
            remover: { _ in
                recorder.record()
            }
        ) { () throws -> Void in
            throw WingmanRunnerError.cancelled
        }
        #expect(Bool(false), "Cancellation should be preserved")
    } catch let error as WingmanRunnerError {
        guard case .cancelled = error else {
            #expect(Bool(false), "Expected cancellation to remain the primary error")
            return
        }
    } catch {
        #expect(Bool(false), "Expected WingmanRunnerError.cancelled")
    }

    #expect(recorder.count == 1)
}

@Test
func wingmanTemporaryRootCleanupPreservesTimeoutAfterCleanupAttempt() {
    let recorder = CleanupAttemptRecorder()

    do {
        try WingmanTemporaryRootCleanup.perform(
            at: URL(fileURLWithPath: "/fixture/temporary-root"),
            remover: { _ in
                recorder.record()
            }
        ) { () throws -> Void in
            throw WingmanRunnerError.timedOut
        }
        #expect(Bool(false), "Timeout should be preserved")
    } catch let error as WingmanRunnerError {
        guard case .timedOut = error else {
            #expect(Bool(false), "Expected timeout to remain the primary error")
            return
        }
    } catch {
        #expect(Bool(false), "Expected WingmanRunnerError.timedOut")
    }

    #expect(recorder.count == 1)
}

@MainActor
@Test
func wingmanCleanupFailureOverridesRequestedCancellationInTheModel() {
    let model = WingmanFeatureModel(language: .english)
    model.markAgentCallStarted()
    model.cancelAgentCall()

    model.completeAgentCall(.failure(WingmanRunnerError.cleanupFailed))

    let expected = WingmanRunnerError.cleanupFailed.message(language: .english)
    #expect(!model.isCallingAgent)
    #expect(!model.isCancellingAgent)
    #expect(model.agentReview == nil)
    #expect(model.errorMessage == expected)
    #expect(model.cliState == .unavailable(expected))
}

@Test
func wingmanCleanupLatchBlocksUntilPendingRootsCanBeVerifiedAbsent() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(
        "ActivityRadar-Wingman-latch-fixture-\(UUID().uuidString)",
        isDirectory: true
    )
    defer { try? WingmanTemporaryRootCleanupLatch.retryPending() }

    WingmanTemporaryRootCleanupLatch.record(root)
    do {
        try WingmanTemporaryRootCleanupLatch.retryPending { _ in
            throw NSError(domain: "CleanupLatchFixture", code: 1)
        }
        #expect(Bool(false), "An unresolved cleanup must keep the process latch closed")
    } catch let error as WingmanRunnerError {
        guard case .cleanupFailed = error else {
            #expect(Bool(false), "Expected cleanupFailed from the process latch")
            return
        }
    }
    #expect(WingmanTemporaryRootCleanupLatch.hasPendingCleanup)

    try WingmanTemporaryRootCleanupLatch.retryPending()
    #expect(!WingmanTemporaryRootCleanupLatch.hasPendingCleanup)
}

@Test
func wingmanRemoteOperationGateRejectsConcurrentRemoteWork() throws {
    let entered = DispatchSemaphore(value: 0)
    let release = DispatchSemaphore(value: 0)
    let finished = DispatchSemaphore(value: 0)
    let firstSucceeded = LockedBoolean()

    DispatchQueue.global(qos: .userInitiated).async {
        defer { finished.signal() }
        do {
            try WingmanRemoteOperationGate.perform {
                entered.signal()
                _ = release.wait(timeout: .now() + 2)
            }
            firstSucceeded.set(true)
        } catch {
            firstSucceeded.set(false)
        }
    }

    #expect(entered.wait(timeout: .now() + 1) == .success)
    var overlapRejected = false
    do {
        try WingmanRemoteOperationGate.perform {}
        #expect(Bool(false), "A concurrent remote operation must be rejected")
    } catch let error as WingmanRunnerError {
        if case .operationInProgress = error {
            overlapRejected = true
        } else {
            #expect(Bool(false), "Expected operationInProgress")
        }
    }

    release.signal()
    #expect(finished.wait(timeout: .now() + 1) == .success)
    #expect(overlapRejected)
    #expect(firstSucceeded.value)
}

@Test
func wingmanRunnerReservationCannotBeOverwrittenBeforeCompletion() {
    let runner = CodexWingmanRunner()

    #expect(runner.prepareInvocation())
    #expect(!runner.prepareInvocation())
}

private final class CleanupAttemptRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storedCount = 0

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return storedCount
    }

    func record() {
        lock.lock()
        storedCount += 1
        lock.unlock()
    }
}

private final class LockedBoolean: @unchecked Sendable {
    private let lock = NSLock()
    private var storedValue = false

    var value: Bool {
        lock.lock()
        defer { lock.unlock() }
        return storedValue
    }

    func set(_ value: Bool) {
        lock.lock()
        storedValue = value
        lock.unlock()
    }
}
#endif
