import ActivityRadarCore
import Darwin
import Foundation
#if canImport(Testing)
import Testing
@testable import ActivityRadar

@Test
func wingmanJSONLCollectorHandlesSplitChunksAndRejectsUnknownEvents() throws {
    let review = WingmanAgentReview(
        portfolioSummary: "Kanıta dayalı özet",
        promptFindings: [],
        harnessFindings: [],
        unfinishedWork: [],
        tokenFindings: [],
        recommendations: [],
        limitations: []
    )
    let reviewData = try JSONEncoder().encode(review)
    let reviewText = try #require(String(data: reviewData, encoding: .utf8))
    let lines = try [
        runnerJSONData(["type": "thread.started"]),
        runnerJSONData([
            "type": "item.completed",
            "item": ["type": "agent_message", "text": reviewText]
        ]),
        runnerJSONData([
            "type": "turn.completed",
            "usage": ["input_tokens": 12, "output_tokens": 3]
        ])
    ]
    var stream = Data()
    for line in lines {
        stream.append(line)
        stream.append(0x0A)
    }

    let collector = WingmanJSONLCollector(limit: 64 * 1_024)
    let chunkSizes = [1, 2, 7, 3, 29, 5, 11]
    var offset = 0
    var chunkIndex = 0
    while offset < stream.count {
        let size = min(chunkSizes[chunkIndex % chunkSizes.count], stream.count - offset)
        collector.append(stream.subdata(in: offset..<(offset + size)))
        offset += size
        chunkIndex += 1
    }
    collector.finish()
    let result = try collector.result()
    #expect(result.review == review)
    #expect(result.usage?.inputTokens == 12)
    #expect(!collector.exceeded)

    let unknown = try runnerJSONData(["type": "future.unrecognized"])
    let unknownCollector = WingmanJSONLCollector(limit: 1_024)
    let midpoint = max(1, unknown.count / 2)
    unknownCollector.append(unknown.subdata(in: 0..<midpoint))
    #expect(unknownCollector.failure == nil)
    var finalChunk = unknown.subdata(in: midpoint..<unknown.count)
    finalChunk.append(0x0A)
    unknownCollector.append(finalChunk)
    #expect(unknownCollector.failure == .forbiddenToolEvent("future.unrecognized"))
}

@Test
func wingmanInputWriterCancellationJoinsWhenStdinIsUnread() {
    let pipe = Pipe()
    defer {
        try? pipe.fileHandleForReading.close()
        try? pipe.fileHandleForWriting.close()
    }
    let writer = WingmanInputWriter()
    writer.start(packetData: Data(repeating: 0x41, count: 8 * 1_024 * 1_024), pipe: pipe)

    #expect(!writer.wait(timeout: .milliseconds(50)))
    let startedAt = DispatchTime.now().uptimeNanoseconds
    writer.cancel()
    #expect(writer.wait(timeout: .seconds(1)))
    #expect(elapsedSeconds(since: startedAt) < 1.5)
    #expect(!writer.failed)
    #expect(!writer.succeeded)
}

@Test
func wingmanPipeReaderCancellationJoinsWhileWriterRemainsOpen() throws {
    let pipe = Pipe()
    defer {
        try? pipe.fileHandleForReading.close()
        try? pipe.fileHandleForWriting.close()
    }
    let collector = BoundedPipeCollector(limit: 1_024)
    let reader = WingmanPipeReader(pipe: pipe, collector: collector)
    reader.start()
    let expectedOutput = Data("partial output".utf8)
    try pipe.fileHandleForWriting.write(contentsOf: expectedOutput)

    #expect(waitForCollectedData(collector, expected: expectedOutput, timeout: 1))
    #expect(!reader.wait(timeout: .milliseconds(50)))
    let startedAt = DispatchTime.now().uptimeNanoseconds
    reader.cancel()
    #expect(reader.wait(timeout: .seconds(1)))
    #expect(elapsedSeconds(since: startedAt) < 1.5)
    #expect(!reader.failed)
    #expect(String(data: collector.data(), encoding: .utf8) == "partial output")
}

@Test
func wingmanSpawnedProcessSignalsItsOwnGroupWithoutShell() throws {
    let executable = URL(fileURLWithPath: "/bin/sleep")
    #expect(FileManager.default.isExecutableFile(atPath: executable.path))

    let terminated = try spawnSleep(executable: executable)
    defer { forceStop(terminated.process, pipes: terminated.pipes) }
    #expect(terminated.process.processIdentifier == terminated.process.processGroupIdentifier)
    #expect(terminated.process.groupExists)
    terminated.process.signalGroup(SIGTERM)
    if !terminated.process.waitUntilExit(timeout: .milliseconds(250)) {
        terminated.process.signalGroup(SIGKILL)
    }
    #expect(terminated.process.waitUntilExit(timeout: .seconds(2)))
    let terminatedStatus = try #require(terminated.process.terminationStatus)
    #expect([128 + SIGTERM, 128 + SIGKILL].contains(terminatedStatus))
    #expect(waitForGroupToDisappear(terminated.process, timeout: 1))

    let killed = try spawnSleep(executable: executable)
    defer { forceStop(killed.process, pipes: killed.pipes) }
    #expect(killed.process.processIdentifier == killed.process.processGroupIdentifier)
    #expect(killed.process.groupExists)
    killed.process.signalGroup(SIGKILL)
    #expect(killed.process.waitUntilExit(timeout: .seconds(2)))
    #expect(killed.process.terminationStatus == 128 + SIGKILL)
    #expect(waitForGroupToDisappear(killed.process, timeout: 1))
}

@Test
func wingmanProbeErrorMessagesDoNotExposeUnknownFilesystemPaths() {
    let privatePath = "/" + "Users/" + "alice/.codex/auth.json"
    let unknownError = NSError(
        domain: "ActivityRadarProbeFixture",
        code: 7,
        userInfo: [
            NSLocalizedDescriptionKey: "Could not read \(privatePath)",
            NSFilePathErrorKey: privatePath
        ]
    )

    let message = wingmanProbeErrorMessage(for: unknownError)
    #expect(message == "Codex CLI güvenlik denetimi tamamlanamadı. Yerel analiz kullanılabilir; uzak Wingman çağrısı başlatılamaz.")
    #expect(!message.contains("/" + "Users"))
    #expect(!message.contains("alice"))
    #expect(!message.contains("auth.json"))
    #expect(
        wingmanProbeErrorMessage(for: WingmanRunnerError.notLoggedIn)
            == WingmanRunnerError.notLoggedIn.localizedDescription
    )
}

@Test
func wingmanCLIReadyBadgeNeverIncludesTheExecutablePath() {
    let path = "/" + "Users/" + "alice/.codex/packages/standalone/bin/codex"
    let raw = "codex-cli 0.146.0 \(path)"

    let turkish = WingmanPresentationText.cliReady(rawVersion: raw, language: .turkish)
    let english = WingmanPresentationText.cliReady(rawVersion: raw, language: .english)

    #expect(turkish == "Codex CLI hazır · 0.146.0")
    #expect(english == "Codex CLI ready · 0.146.0")
    for label in [turkish, english] {
        #expect(!label.contains("/"))
        #expect(!label.contains("alice"))
        #expect(!label.contains("packages"))
    }
}

@MainActor
@Test
func openingWingmanDoesNotProbeCLIUntilExplicitlyRequested() {
    let blockedWorkQueue = DispatchQueue(label: "ActivityRadarTests.prepare-blocked-work")
    let workStarted = DispatchSemaphore(value: 0)
    let releaseWork = DispatchSemaphore(value: 0)
    blockedWorkQueue.async {
        workStarted.signal()
        releaseWork.wait()
    }
    #expect(workStarted.wait(timeout: .now() + 1) == .success)
    defer { releaseWork.signal() }

    let runner = FakeWingmanRunner(probe: fakeWingmanProbe)
    let model = WingmanFeatureModel(runner: runner, queue: blockedWorkQueue)

    model.prepare()

    #expect(model.cliState == .unchecked)
    #expect(runner.probeCount == 0)
}

@MainActor
@Test
func wingmanProbeUsesDedicatedQueueAndIgnoresLateResultAfterDismissal() {
    let blockedWorkQueue = DispatchQueue(label: "ActivityRadarTests.blocked-work")
    let workStarted = DispatchSemaphore(value: 0)
    let releaseWork = DispatchSemaphore(value: 0)
    blockedWorkQueue.async {
        workStarted.signal()
        releaseWork.wait()
    }
    #expect(workStarted.wait(timeout: .now() + 1) == .success)
    defer { releaseWork.signal() }

    let probeStarted = DispatchSemaphore(value: 0)
    let releaseProbe = DispatchSemaphore(value: 0)
    let probeFinished = DispatchSemaphore(value: 0)
    let runner = FakeWingmanRunner(
        probe: {
            probeStarted.signal()
            _ = releaseProbe.wait(timeout: .now() + 2)
            defer { probeFinished.signal() }
            return fakeWingmanProbe()
        },
        onCancel: {
            releaseProbe.signal()
        }
    )
    let model = WingmanFeatureModel(
        runner: runner,
        queue: blockedWorkQueue,
        probeQueue: DispatchQueue(label: "ActivityRadarTests.probe")
    )
    model.transmissionConsent = true

    model.probeCLI()
    #expect(probeStarted.wait(timeout: .now() + 1) == .success)
    model.cancelOutstandingWork()

    #expect(runner.cancelCount == 1)
    #expect(!model.transmissionConsent)
    #expect(probeFinished.wait(timeout: .now() + 1) == .success)
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))
    #expect(model.cliState == .unchecked)
}

@MainActor
@Test
func wingmanAgentCancellationIsOneShotAndRejectsLateSuccess() {
    let runner = FakeWingmanRunner(probe: fakeWingmanProbe)
    let model = WingmanFeatureModel(runner: runner)
    model.markAgentCallStarted()

    model.cancelAgentCall()
    model.cancelAgentCall()

    #expect(model.isCallingAgent)
    #expect(model.isCancellingAgent)
    #expect(runner.cancelCount == 1)

    let lateOutput = WingmanInvocationOutput(
        review: WingmanAgentReview(
            portfolioSummary: "Geç gelen sonuç",
            promptFindings: [],
            harnessFindings: [],
            unfinishedWork: [],
            tokenFindings: [],
            recommendations: [],
            limitations: []
        ),
        usage: nil
    )
    model.completeAgentCall(.success(lateOutput))

    #expect(!model.isCallingAgent)
    #expect(!model.isCancellingAgent)
    #expect(model.agentReview == nil)
    #expect(model.errorMessage == WingmanRunnerError.cancelled.localizedDescription)
}

private struct SpawnFixture {
    let process: WingmanSpawnedProcess
    let pipes: [Pipe]
}

private final class FakeWingmanRunner: WingmanRunning, @unchecked Sendable {
    private let lock = NSLock()
    private let probeHandler: () throws -> WingmanCLIProbe
    private let cancelHandler: () -> Void
    private var storedCancelCount = 0
    private var storedProbeCount = 0

    init(
        probe: @escaping () throws -> WingmanCLIProbe,
        onCancel: @escaping () -> Void = {}
    ) {
        probeHandler = probe
        cancelHandler = onCancel
    }

    var cancelCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return storedCancelCount
    }

    var probeCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return storedProbeCount
    }

    func prepareInvocation() -> Bool { true }

    func probe() throws -> WingmanCLIProbe {
        lock.lock()
        storedProbeCount += 1
        lock.unlock()
        return try probeHandler()
    }

    func invoke(
        packetData: Data,
        executable: WingmanVerifiedExecutable
    ) throws -> WingmanInvocationOutput {
        throw WingmanRunnerError.launchFailed
    }

    func cancel() {
        lock.lock()
        storedCancelCount += 1
        lock.unlock()
        cancelHandler()
    }
}

private func fakeWingmanProbe() -> WingmanCLIProbe {
    WingmanCLIProbe(
        executable: WingmanVerifiedExecutable(
            url: URL(fileURLWithPath: "/fixture/codex"),
            device: 1,
            inode: 2,
            size: 3,
            modificationSeconds: 4,
            modificationNanoseconds: 5
        ),
        version: "codex-cli fixture"
    )
}

private func spawnSleep(executable: URL) throws -> SpawnFixture {
    let input = Pipe()
    let output = Pipe()
    let error = Pipe()
    let process = try WingmanSpawnedProcess(
        executable: executable,
        arguments: ["30"],
        environment: ["PATH": "/usr/bin:/bin"],
        input: input,
        output: output,
        error: error
    )
    return SpawnFixture(process: process, pipes: [input, output, error])
}

private func forceStop(_ process: WingmanSpawnedProcess, pipes: [Pipe]) {
    if process.isRunning || process.groupExists {
        process.signalGroup(SIGKILL)
        _ = process.waitUntilExit(timeout: .seconds(1))
    }
    for pipe in pipes {
        try? pipe.fileHandleForReading.close()
        try? pipe.fileHandleForWriting.close()
    }
}

private func waitForGroupToDisappear(
    _ process: WingmanSpawnedProcess,
    timeout: TimeInterval
) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while process.groupExists, Date() < deadline {
        Thread.sleep(forTimeInterval: 0.01)
    }
    return !process.groupExists
}

private func waitForCollectedData(
    _ collector: BoundedPipeCollector,
    expected: Data,
    timeout: TimeInterval
) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while collector.data() != expected, Date() < deadline {
        Thread.sleep(forTimeInterval: 0.005)
    }
    return collector.data() == expected
}

private func elapsedSeconds(since startedAt: UInt64) -> Double {
    Double(DispatchTime.now().uptimeNanoseconds - startedAt) / 1_000_000_000
}

private func runnerJSONData(_ object: [String: Any]) throws -> Data {
    try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
}
#endif
