import ActivityRadarCore
import Darwin
import Foundation
import Security

enum WingmanHistoryScope: String, CaseIterable, Identifiable {
    case month
    case quarter
    case all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .month: return "30 gün"
        case .quarter: return "90 gün"
        case .all: return "Tüm zamanlar"
        }
    }

    func cutoff(relativeTo now: Date) -> Date? {
        let calendar = Calendar(identifier: .gregorian)
        switch self {
        case .month:
            return calendar.date(byAdding: .day, value: -30, to: now)
        case .quarter:
            return calendar.date(byAdding: .day, value: -90, to: now)
        case .all:
            return nil
        }
    }
}

enum WingmanCLIState: Equatable {
    case checking
    case ready(version: String)
    case unavailable(String)
}

struct WingmanCLIProbe {
    let executable: WingmanVerifiedExecutable
    let version: String
}

struct WingmanVerifiedExecutable: Sendable {
    let url: URL
    let device: UInt64
    let inode: UInt64
    let size: Int64
    let modificationSeconds: Int64
    let modificationNanoseconds: Int64
}

struct WingmanInvocationOutput {
    let review: WingmanAgentReview
    let usage: WingmanAgentUsage?
}

protocol WingmanRunning: AnyObject, Sendable {
    func prepareInvocation() -> Bool
    func probe() throws -> WingmanCLIProbe
    func invoke(
        packetData: Data,
        executable: WingmanVerifiedExecutable
    ) throws -> WingmanInvocationOutput
    func cancel()
}

enum WingmanRunnerError: LocalizedError {
    case cliUnavailable
    case cliIncompatible
    case cliUntrusted
    case notLoggedIn
    case launchFailed
    case timedOut
    case cancelled
    case outputTooLarge
    case cleanupFailed
    case operationInProgress
    case processFailed(Int32)

    var errorDescription: String? {
        message(language: .turkish)
    }

    func message(language: RadarLanguage) -> String {
        switch self {
        case .cliUnavailable:
            return language.text(
                tr: "Uyumlu Codex CLI bulunamadı. Yerel analiz kullanılabilir; uzak Wingman çağrısı başlatılamaz.",
                en: "No compatible Codex CLI was found. Local analysis remains available; the remote Wingman call cannot start."
            )
        case .cliIncompatible:
            return language.text(
                tr: "Kurulu Codex CLI, güvenli Wingman çağrısı için gereken bayrakları desteklemiyor.",
                en: "The installed Codex CLI does not support the flags required for a safe Wingman call."
            )
        case .cliUntrusted:
            return language.text(
                tr: "Codex CLI kimliği veya dosya güvenliği doğrulanamadı. Wingman çağrısı başlatılmadı.",
                en: "The Codex CLI identity or file safety could not be verified. The Wingman call was not started."
            )
        case .notLoggedIn:
            return language.text(
                tr: "Codex CLI oturumu açık değil. Terminalde `codex login` çalıştırdıktan sonra yeniden dene.",
                en: "Codex CLI is not signed in. Run `codex login` in Terminal, then try again."
            )
        case .launchFailed:
            return language.text(tr: "Wingman için Codex CLI başlatılamadı.", en: "Codex CLI could not be started for Wingman.")
        case .timedOut:
            return language.text(tr: "Wingman çağrısı 180 saniyelik süre sınırında durduruldu.", en: "The Wingman call stopped at the 180-second time limit.")
        case .cancelled:
            return language.text(tr: "Wingman çağrısı iptal edildi.", en: "The Wingman call was cancelled.")
        case .outputTooLarge:
            return language.text(tr: "Wingman çıktısı güvenli boyut sınırını aştı ve atıldı.", en: "The Wingman output exceeded the safe size limit and was discarded.")
        case .cleanupFailed:
            return language.text(
                tr: "Geçici Wingman kimlik alanının silindiği doğrulanamadı. Bu uygulama sürecindeki uzak çağrılar engellendi; yeniden açmadan önce ActivityRadar-Wingman- ve ActivityRadar-CLI-Probe- geçici klasörlerini denetleyip kaldır.",
                en: "Removal of the temporary Wingman authentication area could not be verified. Remote calls are blocked in this app process; inspect and remove ActivityRadar-Wingman- and ActivityRadar-CLI-Probe- temporary folders before reopening."
            )
        case .operationInProgress:
            return language.text(
                tr: "Başka bir Wingman uzak işlemi sürüyor. Bu işlem bitmeden yeni bir uzak çağrı başlatılmadı.",
                en: "Another Wingman remote operation is in progress. No new remote call was started."
            )
        case .processFailed(let status):
            return language.text(
                tr: "Wingman ajan turu tamamlanamadı (Codex çıkış kodu: \(status)). Kısmi çıktı kullanılmadı.",
                en: "The Wingman agent turn did not complete (Codex exit code: \(status)). Partial output was not used."
            )
        }
    }
}

func wingmanProbeErrorMessage(
    for error: Error,
    language: RadarLanguage = .turkish
) -> String {
    if let runnerError = error as? WingmanRunnerError {
        return runnerError.message(language: language)
    }
    return language.text(
        tr: "Codex CLI güvenlik denetimi tamamlanamadı. Yerel analiz kullanılabilir; uzak Wingman çağrısı başlatılamaz.",
        en: "The Codex CLI safety check could not be completed. Local analysis remains available; the remote Wingman call cannot start."
    )
}

protocol BoundedDataCollector: AnyObject {
    var exceeded: Bool { get }
    func append(_ data: Data)
}

final class BoundedPipeCollector: BoundedDataCollector, @unchecked Sendable {
    private let limit: Int
    private let lock = NSLock()
    private var storage = Data()
    private var didExceed = false

    init(limit: Int) {
        self.limit = limit
    }

    func append(_ data: Data) {
        lock.lock()
        defer { lock.unlock() }
        guard !didExceed else { return }
        if storage.count > limit - data.count {
            didExceed = true
            return
        }
        storage.append(data)
    }

    var exceeded: Bool {
        lock.lock()
        defer { lock.unlock() }
        return didExceed
    }

    func data() -> Data {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}

final class WingmanJSONLCollector: BoundedDataCollector, @unchecked Sendable {
    private let limit: Int
    private let lock = NSLock()
    private var receivedBytes = 0
    private var pending = Data()
    private var parser = WingmanCodexJSONLParser()
    private var didExceed = false

    init(limit: Int) {
        self.limit = limit
    }

    func append(_ data: Data) {
        lock.lock()
        defer { lock.unlock() }
        guard !didExceed, parser.failure == nil else { return }
        if receivedBytes > limit - data.count {
            didExceed = true
            return
        }
        receivedBytes += data.count
        pending.append(data)
        consumeCompleteLines()
    }

    var exceeded: Bool {
        lock.lock()
        defer { lock.unlock() }
        return didExceed
    }

    var failure: WingmanCodexContractError? {
        lock.lock()
        defer { lock.unlock() }
        return parser.failure
    }

    func finish() {
        lock.lock()
        defer { lock.unlock() }
        consumeCompleteLines()
        if !pending.isEmpty, parser.failure == nil {
            parser.consume(line: pending)
            pending.removeAll(keepingCapacity: false)
        }
    }

    func result() throws -> (review: WingmanAgentReview, usage: WingmanAgentUsage?) {
        lock.lock()
        defer { lock.unlock() }
        return try parser.result()
    }

    private func consumeCompleteLines() {
        while let newline = pending.firstIndex(of: 0x0A) {
            let line = Data(pending[..<newline])
            pending.removeSubrange(...newline)
            if !line.isEmpty {
                parser.consume(line: line)
            }
            if parser.failure != nil { return }
        }
    }
}

final class WingmanInputWriter: @unchecked Sendable {
    private let group = DispatchGroup()
    private let lock = NSLock()
    private var didFail = false
    private var didComplete = false
    private var wasStopped = false
    private var handle: FileHandle?

    func start(packetData: Data, pipe: Pipe) {
        let writeHandle = pipe.fileHandleForWriting
        let descriptor = writeHandle.fileDescriptor
        guard Self.makeNonBlocking(descriptor) else {
            didFail = true
            try? writeHandle.close()
            return
        }
        lock.lock()
        handle = writeHandle
        lock.unlock()

        group.enter()
        DispatchQueue.global(qos: .utility).async { [self] in
            defer { group.leave() }
            var blockedSignals = sigset_t()
            sigemptyset(&blockedSignals)
            sigaddset(&blockedSignals, SIGPIPE)
            pthread_sigmask(SIG_BLOCK, &blockedSignals, nil)
            var payload = packetData
            payload.append(0x0A)
            var offset = 0
            payload.withUnsafeBytes { rawBuffer in
                guard let base = rawBuffer.baseAddress else { return }
                while offset < rawBuffer.count {
                    lock.lock()
                    if wasStopped {
                        lock.unlock()
                        return
                    }
                    let written = Darwin.write(
                        descriptor,
                        base.advanced(by: offset),
                        rawBuffer.count - offset
                    )
                    let writeError = errno
                    lock.unlock()

                    if written > 0 {
                        offset += written
                    } else if written == -1 && writeError == EINTR {
                        continue
                    } else if written == -1 && (writeError == EAGAIN || writeError == EWOULDBLOCK) {
                        Thread.sleep(forTimeInterval: 0.01)
                    } else {
                        if writeError == EPIPE {
                            var pendingSignals = sigset_t()
                            if sigpending(&pendingSignals) == 0,
                               sigismember(&pendingSignals, SIGPIPE) == 1 {
                                var consumedSignal: Int32 = 0
                                _ = sigwait(&blockedSignals, &consumedSignal)
                            }
                        }
                        lock.lock()
                        if !wasStopped { didFail = true }
                        lock.unlock()
                        return
                    }
                }
            }
            lock.lock()
            if !wasStopped && offset != payload.count {
                didFail = true
            } else if !wasStopped {
                didComplete = true
            }
            if let handle {
                try? handle.close()
                self.handle = nil
            }
            lock.unlock()
        }
    }

    func cancel() {
        lock.lock()
        wasStopped = true
        if let handle {
            try? handle.close()
            self.handle = nil
        }
        lock.unlock()
    }

    func wait(timeout: DispatchTimeInterval) -> Bool {
        group.wait(timeout: .now() + timeout) == .success
    }

    var failed: Bool {
        lock.lock()
        defer { lock.unlock() }
        return didFail
    }

    var succeeded: Bool {
        lock.lock()
        defer { lock.unlock() }
        return didComplete && !didFail
    }

    private static func makeNonBlocking(_ descriptor: Int32) -> Bool {
        let flags = fcntl(descriptor, F_GETFL)
        return flags != -1 && fcntl(descriptor, F_SETFL, flags | O_NONBLOCK) != -1
    }
}

final class WingmanPipeReader<Collector: BoundedDataCollector>: @unchecked Sendable {
    private let collector: Collector
    private let group = DispatchGroup()
    private let lock = NSLock()
    private var didFail = false
    private var wasStopped = false
    private var handle: FileHandle?

    init(pipe: Pipe, collector: Collector) {
        self.collector = collector
        self.handle = pipe.fileHandleForReading
    }

    func start() {
        lock.lock()
        guard let handle else {
            didFail = true
            lock.unlock()
            return
        }
        let descriptor = handle.fileDescriptor
        let flags = fcntl(descriptor, F_GETFL)
        guard flags != -1,
              fcntl(descriptor, F_SETFL, flags | O_NONBLOCK) != -1 else {
            didFail = true
            try? handle.close()
            self.handle = nil
            lock.unlock()
            return
        }
        lock.unlock()

        group.enter()
        DispatchQueue.global(qos: .utility).async { [self] in
            defer { group.leave() }
            var buffer = [UInt8](repeating: 0, count: 32 * 1_024)
            while true {
                lock.lock()
                if wasStopped {
                    lock.unlock()
                    return
                }
                let count = buffer.withUnsafeMutableBytes { rawBuffer in
                    Darwin.read(descriptor, rawBuffer.baseAddress, rawBuffer.count)
                }
                let readError = errno
                lock.unlock()

                if count > 0 {
                    collector.append(Data(buffer.prefix(count)))
                    if collector.exceeded { return }
                } else if count == 0 {
                    closeHandle()
                    return
                } else if readError == EINTR {
                    continue
                } else if readError == EAGAIN || readError == EWOULDBLOCK {
                    Thread.sleep(forTimeInterval: 0.01)
                } else {
                    lock.lock()
                    if !wasStopped { didFail = true }
                    lock.unlock()
                    closeHandle()
                    return
                }
            }
        }
    }

    func cancel() {
        lock.lock()
        wasStopped = true
        if let handle {
            try? handle.close()
            self.handle = nil
        }
        lock.unlock()
    }

    func wait(timeout: DispatchTimeInterval) -> Bool {
        group.wait(timeout: .now() + timeout) == .success
    }

    var failed: Bool {
        lock.lock()
        defer { lock.unlock() }
        return didFail
    }

    private func closeHandle() {
        lock.lock()
        if let handle {
            try? handle.close()
            self.handle = nil
        }
        lock.unlock()
    }
}

final class WingmanSpawnedProcess: @unchecked Sendable {
    let processIdentifier: pid_t
    let processGroupIdentifier: pid_t

    private let lock = NSLock()
    private var rawWaitStatus: Int32?
    private var waitFailed = false

    init(
        executable: URL,
        arguments: [String],
        environment: [String: String],
        input: Pipe,
        output: Pipe,
        error: Pipe
    ) throws {
        var fileActions: posix_spawn_file_actions_t?
        guard posix_spawn_file_actions_init(&fileActions) == 0 else {
            throw WingmanRunnerError.launchFailed
        }
        defer { posix_spawn_file_actions_destroy(&fileActions) }

        let inputRead = input.fileHandleForReading.fileDescriptor
        let inputWrite = input.fileHandleForWriting.fileDescriptor
        let outputRead = output.fileHandleForReading.fileDescriptor
        let outputWrite = output.fileHandleForWriting.fileDescriptor
        let errorRead = error.fileHandleForReading.fileDescriptor
        let errorWrite = error.fileHandleForWriting.fileDescriptor

        guard posix_spawn_file_actions_adddup2(&fileActions, inputRead, STDIN_FILENO) == 0,
              posix_spawn_file_actions_adddup2(&fileActions, outputWrite, STDOUT_FILENO) == 0,
              posix_spawn_file_actions_adddup2(&fileActions, errorWrite, STDERR_FILENO) == 0 else {
            throw WingmanRunnerError.launchFailed
        }
        for descriptor in Set([inputRead, inputWrite, outputRead, outputWrite, errorRead, errorWrite])
        where descriptor > STDERR_FILENO {
            guard posix_spawn_file_actions_addclose(&fileActions, descriptor) == 0 else {
                throw WingmanRunnerError.launchFailed
            }
        }

        var attributes: posix_spawnattr_t?
        guard posix_spawnattr_init(&attributes) == 0 else {
            throw WingmanRunnerError.launchFailed
        }
        defer { posix_spawnattr_destroy(&attributes) }
        let spawnFlags = Int16(POSIX_SPAWN_SETPGROUP | POSIX_SPAWN_CLOEXEC_DEFAULT)
        guard posix_spawnattr_setpgroup(&attributes, 0) == 0,
              posix_spawnattr_setflags(&attributes, spawnFlags) == 0 else {
            throw WingmanRunnerError.launchFailed
        }

        let argumentStrings = [executable.path] + arguments
        let environmentStrings = environment
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
        var childPID: pid_t = 0
        let spawnResult = try Self.withCStringVector(argumentStrings) { argv in
            try Self.withCStringVector(environmentStrings) { environmentPointer in
                executable.path.withCString { executablePointer in
                    posix_spawn(
                        &childPID,
                        executablePointer,
                        &fileActions,
                        &attributes,
                        argv,
                        environmentPointer
                    )
                }
            }
        }
        guard spawnResult == 0, childPID > 0 else {
            throw WingmanRunnerError.launchFailed
        }

        processIdentifier = childPID
        processGroupIdentifier = childPID
        try? input.fileHandleForReading.close()
        try? output.fileHandleForWriting.close()
        try? error.fileHandleForWriting.close()
    }

    var isRunning: Bool {
        lock.lock()
        defer { lock.unlock() }
        refreshStatusLocked()
        return rawWaitStatus == nil && !waitFailed
    }

    var terminationStatus: Int32? {
        lock.lock()
        defer { lock.unlock() }
        refreshStatusLocked()
        guard let status = rawWaitStatus else { return nil }
        let signal = status & 0x7F
        if signal == 0 {
            return (status >> 8) & 0xFF
        }
        return 128 + signal
    }

    func signalGroup(_ signal: Int32) {
        guard processGroupIdentifier > 0 else { return }
        _ = Darwin.kill(-processGroupIdentifier, signal)
    }

    var groupExists: Bool {
        guard processGroupIdentifier > 0 else { return false }
        if Darwin.kill(-processGroupIdentifier, 0) == 0 { return true }
        return errno == EPERM
    }

    func waitUntilExit(timeout: DispatchTimeInterval) -> Bool {
        let deadline = DispatchTime.now() + timeout
        repeat {
            if !isRunning { return true }
            Thread.sleep(forTimeInterval: 0.01)
        } while DispatchTime.now() < deadline
        return !isRunning
    }

    private func refreshStatusLocked() {
        guard rawWaitStatus == nil, !waitFailed else { return }
        var status: Int32 = 0
        let result = waitpid(processIdentifier, &status, WNOHANG)
        if result == processIdentifier {
            rawWaitStatus = status
        } else if result == -1 && errno != EINTR {
            waitFailed = true
        }
    }

    private static func withCStringVector<Result>(
        _ strings: [String],
        _ body: (UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>) throws -> Result
    ) throws -> Result {
        var storage: [UnsafeMutablePointer<CChar>] = []
        storage.reserveCapacity(strings.count)
        for string in strings {
            guard let pointer = strdup(string) else {
                storage.forEach { free($0) }
                throw WingmanRunnerError.launchFailed
            }
            storage.append(pointer)
        }
        defer { storage.forEach { free($0) } }
        var pointers = storage.map(Optional.some)
        pointers.append(nil)
        return try pointers.withUnsafeMutableBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else {
                throw WingmanRunnerError.launchFailed
            }
            return try body(baseAddress)
        }
    }
}

typealias WingmanTemporaryRootRemover = @Sendable (URL) throws -> Void

enum WingmanTemporaryRootCleanup {
    static func perform<T>(
        at root: URL,
        remover: WingmanTemporaryRootRemover,
        operation: () throws -> T
    ) throws -> T {
        let operationResult: Result<T, Error>
        do {
            operationResult = .success(try operation())
        } catch {
            operationResult = .failure(error)
        }

        let cleanupSucceeded: Bool
        do {
            try remover(root)
            cleanupSucceeded = true
        } catch {
            cleanupSucceeded = false
        }

        // A cleanup failure is security-relevant and must never be hidden by
        // the operation result. Normal cancellation and timeout errors remain
        // unchanged when cleanup succeeds.
        guard cleanupSucceeded else { throw WingmanRunnerError.cleanupFailed }
        return try operationResult.get()
    }

    static func remove(_ root: URL) throws {
        guard isAllowedRoot(root) else { throw WingmanRunnerError.cleanupFailed }

        for attempt in 0..<2 {
            guard try pathExists(root) else { return }
            restoreOwnerAccessWithoutFollowingSymlinks(root)
            try? FileManager.default.removeItem(at: root)
            guard try pathExists(root) else { return }
            if attempt == 0 {
                Thread.sleep(forTimeInterval: 0.01)
            }
        }
        throw WingmanRunnerError.cleanupFailed
    }

    private static func isAllowedRoot(_ root: URL) -> Bool {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .standardizedFileURL.resolvingSymlinksInPath()
        let parent = root.deletingLastPathComponent()
            .standardizedFileURL.resolvingSymlinksInPath()
        let name = root.lastPathComponent
        return parent.path == temporaryDirectory.path
            && (name.hasPrefix("ActivityRadar-Wingman-")
                || name.hasPrefix("ActivityRadar-CLI-Probe-"))
    }

    private static func pathExists(_ root: URL) throws -> Bool {
        var metadata = stat()
        if lstat(root.path, &metadata) == 0 { return true }
        if errno == ENOENT { return false }
        throw WingmanRunnerError.cleanupFailed
    }

    private static func restoreOwnerAccessWithoutFollowingSymlinks(_ root: URL) {
        let descriptor = open(
            root.path,
            O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW
        )
        guard descriptor >= 0 else { return }
        defer { Darwin.close(descriptor) }
        _ = fchmod(descriptor, mode_t(0o700))
    }
}

enum WingmanTemporaryRootCleanupLatch {
    private static let lock = NSLock()
    private static var pendingRoots = Set<URL>()

    static var hasPendingCleanup: Bool {
        lock.lock()
        defer { lock.unlock() }
        return !pendingRoots.isEmpty
    }

    static func record(_ root: URL) {
        lock.lock()
        pendingRoots.insert(root.standardizedFileURL)
        lock.unlock()
    }

    static func retryPending(
        remover: WingmanTemporaryRootRemover = { try WingmanTemporaryRootCleanup.remove($0) }
    ) throws {
        lock.lock()
        defer { lock.unlock() }

        var unresolved = Set<URL>()
        for root in pendingRoots {
            do {
                try remover(root)
            } catch {
                unresolved.insert(root)
            }
        }
        pendingRoots = unresolved
        guard unresolved.isEmpty else { throw WingmanRunnerError.cleanupFailed }
    }
}

enum WingmanRemoteOperationGate {
    private static let lock = NSLock()
    private static var operationActive = false

    static func perform<T>(_ operation: () throws -> T) throws -> T {
        lock.lock()
        guard !operationActive else {
            lock.unlock()
            throw WingmanRunnerError.operationInProgress
        }
        operationActive = true
        lock.unlock()

        defer {
            lock.lock()
            operationActive = false
            lock.unlock()
        }
        return try operation()
    }
}

final class CodexWingmanRunner: WingmanRunning, @unchecked Sendable {
    private let lock = NSLock()
    private let temporaryRootRemover: WingmanTemporaryRootRemover
    private var activeProcess: WingmanSpawnedProcess?
    private var cancellationRequested = false
    private var invocationReserved = false

    private enum StopReason {
        case contract(WingmanCodexContractError)
        case outputTooLarge
        case inputFailed
        case cancelled
        case timedOut
    }

    init(
        temporaryRootRemover: @escaping WingmanTemporaryRootRemover = {
            try WingmanTemporaryRootCleanup.remove($0)
        }
    ) {
        self.temporaryRootRemover = temporaryRootRemover
    }

    func prepareInvocation() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !invocationReserved, activeProcess == nil else { return false }
        invocationReserved = true
        cancellationRequested = false
        return true
    }

    func probe() throws -> WingmanCLIProbe {
        try beginPreparedInvocation()
        defer { finishPreparedInvocation() }
        return try WingmanRemoteOperationGate.perform {
            try WingmanTemporaryRootCleanupLatch.retryPending()
            guard let executable = locateExecutable() else {
                throw WingmanRunnerError.cliUnavailable
            }
            return try withTemporaryRoot(prefix: "ActivityRadar-CLI-Probe") { probeRoot in
                let isolatedCodexHome = try makeIsolatedCodexHome(in: probeRoot)
                let environment = childEnvironment(codexHome: isolatedCodexHome)
                let versionResult = try runSimple(
                    executable: executable,
                    arguments: ["--version"],
                    environment: environment,
                    timeout: 8
                )
                guard versionResult.status == 0,
                      let version = String(data: versionResult.stdout, encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines),
                      !version.isEmpty else {
                    throw WingmanRunnerError.cliIncompatible
                }
                let help = try runSimple(
                    executable: executable,
                    arguments: ["exec", "--help"],
                    environment: environment,
                    timeout: 8
                )
                let helpText = String(data: help.stdout, encoding: .utf8) ?? ""
                let requiredFlags = [
                    "--sandbox", "--ephemeral", "--ignore-user-config",
                    "--output-schema", "--json"
                ]
                guard help.status == 0, requiredFlags.allSatisfy(helpText.contains) else {
                    throw WingmanRunnerError.cliIncompatible
                }
                let login = try runSimple(
                    executable: executable,
                    arguments: ["login", "status"],
                    environment: environment,
                    timeout: 12
                )
                guard login.status == 0 else {
                    throw WingmanRunnerError.notLoggedIn
                }
                return WingmanCLIProbe(
                    executable: executable,
                    version: String(version.prefix(120))
                )
            }
        }
    }

    func invoke(
        packetData: Data,
        executable: WingmanVerifiedExecutable
    ) throws -> WingmanInvocationOutput {
        try beginPreparedInvocation()
        defer { finishPreparedInvocation() }
        return try WingmanRemoteOperationGate.perform {
            try WingmanTemporaryRootCleanupLatch.retryPending()
            return try withTemporaryRoot(prefix: "ActivityRadar-Wingman") { temporaryRoot in
                try invokeUsingTemporaryRoot(
                    packetData: packetData,
                    executable: executable,
                    temporaryRoot: temporaryRoot
                )
            }
        }
    }

    private func beginPreparedInvocation() throws {
        lock.lock()
        defer { lock.unlock() }
        guard invocationReserved else {
            throw WingmanRunnerError.operationInProgress
        }
    }

    private func finishPreparedInvocation() {
        lock.lock()
        invocationReserved = false
        lock.unlock()
    }

    private func invokeUsingTemporaryRoot(
        packetData: Data,
        executable: WingmanVerifiedExecutable,
        temporaryRoot: URL
    ) throws -> WingmanInvocationOutput {
        let schemaURL = temporaryRoot.appendingPathComponent("review-schema.json")
        try writePrivateSnapshot(WingmanCodexContract.reviewSchemaData, to: schemaURL)
        let isolatedCodexHome = try makeIsolatedCodexHome(in: temporaryRoot)

        let arguments = WingmanCodexContract.arguments(
            workingDirectory: temporaryRoot,
            schemaURL: schemaURL
        )
        let environment = childEnvironment(codexHome: isolatedCodexHome)
        let input = Pipe()
        let output = Pipe()
        let error = Pipe()
        defer {
            Self.close(pipe: input)
            Self.close(pipe: output)
            Self.close(pipe: error)
        }

        let outputCollector = WingmanJSONLCollector(limit: 4 * 1_024 * 1_024)
        let errorCollector = BoundedPipeCollector(limit: 64 * 1_024)
        let inputWriter = WingmanInputWriter()
        let outputReader = WingmanPipeReader(pipe: output, collector: outputCollector)
        let errorReader = WingmanPipeReader(pipe: error, collector: errorCollector)

        let process = try startIfNotCancelled(
            executable: executable,
            arguments: arguments,
            environment: environment,
            input: input,
            output: output,
            error: error
        )
        var processGroupCleanupPerformed = false
        defer {
            inputWriter.cancel()
            outputReader.cancel()
            errorReader.cancel()
            if !processGroupCleanupPerformed {
                terminateProcessGroup(process, grace: .milliseconds(0))
            }
            clearActive(process)
        }

        outputReader.start()
        errorReader.start()
        inputWriter.start(packetData: packetData, pipe: input)
        let deadline = DispatchTime.now() + .seconds(180)
        var stopReason: StopReason?
        while process.isRunning && stopReason == nil {
            stopReason = currentStopReason(
                outputCollector: outputCollector,
                errorCollector: errorCollector,
                inputWriter: inputWriter,
                deadline: deadline
            )
            if stopReason != nil { break }
            Thread.sleep(forTimeInterval: 0.05)
        }

        if stopReason != nil {
            inputWriter.cancel()
            terminateProcessGroup(process, grace: .seconds(2))
        } else {
            _ = process.waitUntilExit(timeout: .milliseconds(100))
            terminateProcessGroup(process, grace: .milliseconds(250))
        }
        processGroupCleanupPerformed = true

        let writerJoined = inputWriter.wait(timeout: .milliseconds(500))
        if !writerJoined {
            inputWriter.cancel()
        }
        let outputJoined = outputReader.wait(timeout: .seconds(1))
        let errorJoined = errorReader.wait(timeout: .seconds(1))
        if !outputJoined { outputReader.cancel() }
        if !errorJoined { errorReader.cancel() }
        outputCollector.finish()

        if let failure = outputCollector.failure { throw failure }
        if outputCollector.exceeded || errorCollector.exceeded {
            throw WingmanRunnerError.outputTooLarge
        }
        if wasCancelled() { throw WingmanRunnerError.cancelled }
        switch stopReason {
        case .contract(let failure): throw failure
        case .outputTooLarge: throw WingmanRunnerError.outputTooLarge
        case .inputFailed: throw WingmanRunnerError.launchFailed
        case .cancelled: throw WingmanRunnerError.cancelled
        case .timedOut: throw WingmanRunnerError.timedOut
        case nil: break
        }
        guard writerJoined, inputWriter.succeeded, !inputWriter.failed,
              outputJoined, errorJoined, !outputReader.failed, !errorReader.failed else {
            throw WingmanRunnerError.launchFailed
        }
        guard let status = process.terminationStatus else {
            throw WingmanRunnerError.launchFailed
        }
        guard status == 0 else {
            throw WingmanRunnerError.processFailed(status)
        }

        let parsed = try outputCollector.result()
        return WingmanInvocationOutput(review: parsed.review, usage: parsed.usage)
    }

    func cancel() {
        lock.lock()
        cancellationRequested = true
        let process = activeProcess
        lock.unlock()
        process?.signalGroup(SIGTERM)
    }

    private func locateExecutable() -> WingmanVerifiedExecutable? {
        let environment = ProcessInfo.processInfo.environment
        let home = FileManager.default.homeDirectoryForCurrentUser
        var candidates = [
            home.appendingPathComponent(".local/bin/codex"),
            URL(fileURLWithPath: "/opt/homebrew/bin/codex"),
            URL(fileURLWithPath: "/usr/local/bin/codex")
        ]
        if let path = environment["PATH"] {
            candidates.append(contentsOf: path.split(separator: ":").map {
                URL(fileURLWithPath: String($0)).appendingPathComponent("codex")
            })
        }
        var seen = Set<String>()
        for candidate in candidates {
            let resolved = candidate.standardizedFileURL.resolvingSymlinksInPath()
            guard seen.insert(resolved.path).inserted,
                  let verified = try? verifyExecutable(candidate: candidate, expected: nil) else { continue }
            return verified
        }
        return nil
    }

    private func childEnvironment(codexHome: URL) -> [String: String] {
        var environment = WingmanCodexContract.sanitizedEnvironment(
            from: ProcessInfo.processInfo.environment
        )
        environment["CODEX_HOME"] = codexHome.path
        environment["HOME"] = codexHome.path
        environment["TMPDIR"] = codexHome.deletingLastPathComponent().path
        environment["PATH"] = "/usr/bin:/bin:/usr/sbin:/sbin"
        return environment
    }

    private func withTemporaryRoot<T>(
        prefix: String,
        operation: (URL) throws -> T
    ) throws -> T {
        let root = try makeTemporaryRoot(prefix: prefix)
        do {
            return try WingmanTemporaryRootCleanup.perform(
                at: root,
                remover: temporaryRootRemover
            ) {
                try operation(root)
            }
        } catch {
            if case .cleanupFailed? = error as? WingmanRunnerError {
                WingmanTemporaryRootCleanupLatch.record(root)
            }
            throw error
        }
    }

    private func makeTemporaryRoot(prefix: String) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(prefix)-\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(
                at: root,
                withIntermediateDirectories: false,
                attributes: [.posixPermissions: 0o700]
            )
        } catch {
            do {
                try WingmanTemporaryRootCleanup.remove(root)
            } catch {
                WingmanTemporaryRootCleanupLatch.record(root)
                throw WingmanRunnerError.cleanupFailed
            }
            throw WingmanRunnerError.launchFailed
        }
        guard chmod(root.path, 0o700) == 0 else {
            do {
                try WingmanTemporaryRootCleanup.remove(root)
            } catch {
                WingmanTemporaryRootCleanupLatch.record(root)
                throw WingmanRunnerError.cleanupFailed
            }
            throw WingmanRunnerError.launchFailed
        }
        return root
    }

    private func makeIsolatedCodexHome(in root: URL) throws -> URL {
        let fileManager = FileManager.default
        let sourceRoot: URL
        if let configured = ProcessInfo.processInfo.environment["CODEX_HOME"],
           !configured.isEmpty {
            sourceRoot = URL(fileURLWithPath: configured, isDirectory: true)
        } else {
            sourceRoot = fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent(".codex", isDirectory: true)
        }
        let authSource = sourceRoot.appendingPathComponent("auth.json")
            .standardizedFileURL.resolvingSymlinksInPath()
        guard isTrustedDirectoryChain(authSource.deletingLastPathComponent()) else {
            throw WingmanRunnerError.notLoggedIn
        }
        var authData = try readSecureRegularFile(
            at: authSource,
            maximumBytes: 1_048_576,
            allowEmpty: false,
            failure: .notLoggedIn
        )
        defer {
            if !authData.isEmpty { authData.resetBytes(in: 0..<authData.count) }
        }
        let isolated = root.appendingPathComponent("codex-home", isDirectory: true)
        try fileManager.createDirectory(
            at: isolated,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
        guard chmod(isolated.path, 0o700) == 0 else {
            throw WingmanRunnerError.launchFailed
        }
        let authCopy = isolated.appendingPathComponent("auth.json")
        try writePrivateSnapshot(authData, to: authCopy)
        return isolated
    }

    private func startIfNotCancelled(
        executable: WingmanVerifiedExecutable,
        arguments: [String],
        environment: [String: String],
        input: Pipe,
        output: Pipe,
        error: Pipe
    ) throws -> WingmanSpawnedProcess {
        let revalidated = try verifyExecutable(candidate: executable.url, expected: executable)
        lock.lock()
        defer { lock.unlock() }
        guard !cancellationRequested else {
            throw WingmanRunnerError.cancelled
        }
        let process = try WingmanSpawnedProcess(
            executable: revalidated.url,
            arguments: arguments,
            environment: environment,
            input: input,
            output: output,
            error: error
        )
        activeProcess = process
        return process
    }

    private func clearActive(_ process: WingmanSpawnedProcess) {
        lock.lock()
        if activeProcess === process {
            activeProcess = nil
        }
        lock.unlock()
    }

    private func wasCancelled() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancellationRequested
    }

    private func currentStopReason(
        outputCollector: WingmanJSONLCollector,
        errorCollector: BoundedPipeCollector,
        inputWriter: WingmanInputWriter,
        deadline: DispatchTime
    ) -> StopReason? {
        if let failure = outputCollector.failure { return .contract(failure) }
        if outputCollector.exceeded || errorCollector.exceeded { return .outputTooLarge }
        if inputWriter.failed { return .inputFailed }
        if wasCancelled() { return .cancelled }
        if DispatchTime.now() >= deadline { return .timedOut }
        return nil
    }

    private func terminateProcessGroup(
        _ process: WingmanSpawnedProcess,
        grace: DispatchTimeInterval
    ) {
        process.signalGroup(SIGTERM)
        let gracefulDeadline = DispatchTime.now() + grace
        while (process.isRunning || process.groupExists),
              DispatchTime.now() < gracefulDeadline {
            Thread.sleep(forTimeInterval: 0.01)
        }
        if process.isRunning || process.groupExists {
            process.signalGroup(SIGKILL)
        }
        _ = process.waitUntilExit(timeout: .seconds(1))
        let groupDeadline = DispatchTime.now() + .milliseconds(250)
        while process.groupExists, DispatchTime.now() < groupDeadline {
            Thread.sleep(forTimeInterval: 0.01)
        }
    }

    private func verifyExecutable(
        candidate: URL,
        expected: WingmanVerifiedExecutable?
    ) throws -> WingmanVerifiedExecutable {
        let standardized = candidate.standardizedFileURL
        guard standardized.isFileURL,
              standardized.path.hasPrefix("/"),
              isTrustedDirectoryChain(standardized.deletingLastPathComponent()) else {
            throw WingmanRunnerError.cliUntrusted
        }
        let resolved = standardized.resolvingSymlinksInPath()
        guard resolved.path.hasPrefix("/"),
              isTrustedDirectoryChain(resolved.deletingLastPathComponent()),
              FileManager.default.isExecutableFile(atPath: resolved.path) else {
            throw WingmanRunnerError.cliUntrusted
        }

        var before = stat()
        guard lstat(resolved.path, &before) == 0,
              isTrustedExecutableFile(before),
              hasTrustedCodexSignature(resolved) else {
            throw WingmanRunnerError.cliUntrusted
        }
        var after = stat()
        guard lstat(resolved.path, &after) == 0,
              sameFile(before, after),
              before.st_size == after.st_size,
              before.st_mtimespec.tv_sec == after.st_mtimespec.tv_sec,
              before.st_mtimespec.tv_nsec == after.st_mtimespec.tv_nsec,
              isTrustedExecutableFile(after) else {
            throw WingmanRunnerError.cliUntrusted
        }

        let verified = WingmanVerifiedExecutable(
            url: resolved,
            device: UInt64(after.st_dev),
            inode: UInt64(after.st_ino),
            size: after.st_size,
            modificationSeconds: Int64(after.st_mtimespec.tv_sec),
            modificationNanoseconds: Int64(after.st_mtimespec.tv_nsec)
        )
        if let expected {
            guard expected.url.path == verified.url.path,
                  expected.device == verified.device,
                  expected.inode == verified.inode,
                  expected.size == verified.size,
                  expected.modificationSeconds == verified.modificationSeconds,
                  expected.modificationNanoseconds == verified.modificationNanoseconds else {
                throw WingmanRunnerError.cliUntrusted
            }
        }
        return verified
    }

    private func hasTrustedCodexSignature(_ executable: URL) -> Bool {
        let requirementText = #"anchor apple generic and certificate leaf[subject.OU] = "2DC432GLL2" and identifier "codex""#
        var requirement: SecRequirement?
        guard SecRequirementCreateWithString(
            requirementText as CFString,
            [],
            &requirement
        ) == errSecSuccess,
              let requirement else { return false }
        var staticCode: SecStaticCode?
        guard SecStaticCodeCreateWithPath(executable as CFURL, [], &staticCode) == errSecSuccess,
              let staticCode else { return false }
        let flags = SecCSFlags(rawValue: kSecCSStrictValidate | kSecCSCheckAllArchitectures)
        return SecStaticCodeCheckValidity(staticCode, flags, requirement) == errSecSuccess
    }

    private func isTrustedDirectoryChain(_ directory: URL) -> Bool {
        var current = directory.standardizedFileURL.resolvingSymlinksInPath()
        while true {
            var status = stat()
            guard lstat(current.path, &status) == 0,
                  isTrustedDirectory(status) else { return false }
            if current.path == "/" { return true }
            let parent = current.deletingLastPathComponent().standardizedFileURL
            guard parent.path != current.path else { return false }
            current = parent
        }
    }

    private func isTrustedDirectory(_ status: stat) -> Bool {
        let ownerIsTrusted = status.st_uid == geteuid() || status.st_uid == 0
        return (status.st_mode & S_IFMT) == S_IFDIR
            && ownerIsTrusted
            && (status.st_mode & (S_IWGRP | S_IWOTH)) == 0
    }

    private func isTrustedExecutableFile(_ status: stat) -> Bool {
        let ownerIsTrusted = status.st_uid == geteuid() || status.st_uid == 0
        return (status.st_mode & S_IFMT) == S_IFREG
            && ownerIsTrusted
            && status.st_size > 0
            && (status.st_mode & (S_IWGRP | S_IWOTH | S_ISUID | S_ISGID)) == 0
    }

    private func isTrustedDataFile(_ status: stat) -> Bool {
        let ownerIsTrusted = status.st_uid == geteuid() || status.st_uid == 0
        return (status.st_mode & S_IFMT) == S_IFREG
            && ownerIsTrusted
            && status.st_size >= 0
            && (status.st_mode & (S_IWGRP | S_IWOTH | S_ISUID | S_ISGID)) == 0
    }

    private func sameFile(_ left: stat, _ right: stat) -> Bool {
        left.st_dev == right.st_dev && left.st_ino == right.st_ino
    }

    private func readSecureRegularFile(
        at url: URL,
        maximumBytes: Int,
        allowEmpty: Bool,
        failure: WingmanRunnerError
    ) throws -> Data {
        let descriptor = open(url.path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW)
        guard descriptor >= 0 else { throw failure }
        defer { Darwin.close(descriptor) }
        return try readSecureRegularFile(
            descriptor: descriptor,
            maximumBytes: maximumBytes,
            allowEmpty: allowEmpty,
            failure: failure
        )
    }

    private func readSecureRegularFile(
        directoryDescriptor: Int32,
        name: String,
        maximumBytes: Int,
        allowEmpty: Bool,
        failure: WingmanRunnerError
    ) throws -> Data {
        let descriptor = openat(
            directoryDescriptor,
            name,
            O_RDONLY | O_CLOEXEC | O_NOFOLLOW
        )
        guard descriptor >= 0 else { throw failure }
        defer { Darwin.close(descriptor) }
        return try readSecureRegularFile(
            descriptor: descriptor,
            maximumBytes: maximumBytes,
            allowEmpty: allowEmpty,
            failure: failure
        )
    }

    private func readSecureRegularFile(
        descriptor: Int32,
        maximumBytes: Int,
        allowEmpty: Bool,
        failure: WingmanRunnerError
    ) throws -> Data {
        guard maximumBytes >= 0 else { throw failure }
        var before = stat()
        guard fstat(descriptor, &before) == 0,
              isTrustedDataFile(before),
              before.st_size <= Int64(maximumBytes),
              allowEmpty || before.st_size > 0 else { throw failure }

        var data = Data()
        data.reserveCapacity(Int(before.st_size))
        var buffer = [UInt8](repeating: 0, count: 32 * 1_024)
        while true {
            let count = buffer.withUnsafeMutableBytes { rawBuffer in
                Darwin.read(descriptor, rawBuffer.baseAddress, rawBuffer.count)
            }
            if count > 0 {
                guard data.count <= maximumBytes - count else { throw failure }
                data.append(contentsOf: buffer.prefix(count))
            } else if count == 0 {
                break
            } else if errno == EINTR {
                continue
            } else {
                throw failure
            }
        }
        var after = stat()
        guard fstat(descriptor, &after) == 0,
              sameFile(before, after),
              before.st_size == after.st_size,
              before.st_mtimespec.tv_sec == after.st_mtimespec.tv_sec,
              before.st_mtimespec.tv_nsec == after.st_mtimespec.tv_nsec,
              Int64(data.count) == after.st_size,
              isTrustedDataFile(after),
              allowEmpty || !data.isEmpty else { throw failure }
        return data
    }

    private func writePrivateSnapshot(_ data: Data, to url: URL) throws {
        let descriptor = open(
            url.path,
            O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW,
            mode_t(0o600)
        )
        guard descriptor >= 0 else { throw WingmanRunnerError.launchFailed }
        defer { Darwin.close(descriptor) }
        guard fchmod(descriptor, mode_t(0o600)) == 0 else {
            throw WingmanRunnerError.launchFailed
        }
        var offset = 0
        try data.withUnsafeBytes { rawBuffer in
            guard let base = rawBuffer.baseAddress else { return }
            while offset < rawBuffer.count {
                let written = Darwin.write(
                    descriptor,
                    base.advanced(by: offset),
                    rawBuffer.count - offset
                )
                if written > 0 {
                    offset += written
                } else if written == -1 && errno == EINTR {
                    continue
                } else {
                    throw WingmanRunnerError.launchFailed
                }
            }
        }
        guard offset == data.count, fsync(descriptor) == 0 else {
            throw WingmanRunnerError.launchFailed
        }
    }

    private static func close(pipe: Pipe) {
        try? pipe.fileHandleForReading.close()
        try? pipe.fileHandleForWriting.close()
    }

    private func runSimple(
        executable: WingmanVerifiedExecutable,
        arguments: [String],
        environment: [String: String],
        timeout: TimeInterval
    ) throws -> (status: Int32, stdout: Data) {
        let input = Pipe()
        let output = Pipe()
        let error = Pipe()
        defer {
            Self.close(pipe: input)
            Self.close(pipe: output)
            Self.close(pipe: error)
        }
        let outputCollector = BoundedPipeCollector(limit: 256 * 1_024)
        let errorCollector = BoundedPipeCollector(limit: 64 * 1_024)
        let outputReader = WingmanPipeReader(pipe: output, collector: outputCollector)
        let errorReader = WingmanPipeReader(pipe: error, collector: errorCollector)
        let process = try startIfNotCancelled(
            executable: executable,
            arguments: arguments,
            environment: environment,
            input: input,
            output: output,
            error: error
        )
        var processGroupCleanupPerformed = false
        defer {
            outputReader.cancel()
            errorReader.cancel()
            if !processGroupCleanupPerformed {
                terminateProcessGroup(process, grace: .milliseconds(0))
            }
            clearActive(process)
        }
        try? input.fileHandleForWriting.close()
        outputReader.start()
        errorReader.start()

        let deadline = DispatchTime.now() + .milliseconds(max(1, Int(timeout * 1_000)))
        while process.isRunning,
              DispatchTime.now() < deadline,
              !outputCollector.exceeded,
              !errorCollector.exceeded {
            Thread.sleep(forTimeInterval: 0.05)
        }
        let timedOut = process.isRunning && DispatchTime.now() >= deadline
        if process.isRunning || outputCollector.exceeded || errorCollector.exceeded {
            terminateProcessGroup(process, grace: .seconds(1))
        } else {
            terminateProcessGroup(process, grace: .milliseconds(100))
        }
        processGroupCleanupPerformed = true
        let outputJoined = outputReader.wait(timeout: .seconds(1))
        let errorJoined = errorReader.wait(timeout: .seconds(1))
        guard outputJoined, errorJoined, !outputReader.failed, !errorReader.failed else {
            throw WingmanRunnerError.cliIncompatible
        }
        guard !timedOut,
              !outputCollector.exceeded,
              !errorCollector.exceeded,
              let status = process.terminationStatus else {
            throw WingmanRunnerError.cliIncompatible
        }
        return (status, outputCollector.data())
    }
}

@MainActor
final class WingmanFeatureModel: ObservableObject {
    @Published var scope: WingmanHistoryScope = .all
    @Published var includePromptExcerptsForAgent = false
    @Published var transmissionConsent = false
    @Published private(set) var isLoading = false
    @Published private(set) var isCallingAgent = false
    @Published private(set) var isCancellingAgent = false
    @Published private(set) var analysis: WingmanPortfolioAnalysis?
    @Published private(set) var agentReview: WingmanAgentReview?
    @Published private(set) var agentUsage: WingmanAgentUsage?
    @Published private(set) var cliState: WingmanCLIState = .checking
    @Published private(set) var packetPreview: WingmanAgentPacketPreview?
    @Published private(set) var errorMessage: String?
    @Published private(set) var actionMessage: String?

    private let reader = CodexWingmanEvidenceReader()
    private let runner: any WingmanRunning
    private let queue: DispatchQueue
    private let probeQueue: DispatchQueue
    private let language: RadarLanguage
    private var cliExecutable: WingmanVerifiedExecutable?
    private var prepared = false
    private var reloadPending = false
    private var cliProbeGeneration = 0

    init(
        runner: any WingmanRunning = CodexWingmanRunner(),
        queue: DispatchQueue? = nil,
        probeQueue: DispatchQueue? = nil,
        language: RadarLanguage = .turkish
    ) {
        self.runner = runner
        self.language = language
        self.queue = queue ?? DispatchQueue(
            label: "io.github.mehmetsolakedu.ActivityRadar.wingman",
            qos: .userInitiated
        )
        self.probeQueue = probeQueue ?? DispatchQueue(
            label: "io.github.mehmetsolakedu.ActivityRadar.wingman-probe",
            qos: .userInitiated
        )
    }

    func prepare() {
        guard !prepared else { return }
        prepared = true
        reload()
        probeCLI()
    }

    func scopeDidChange() {
        transmissionConsent = false
        reload()
    }

    func promptSharingDidChange() {
        transmissionConsent = false
        agentReview = nil
        agentUsage = nil
        refreshPacketPreview()
    }

    func retryCLIProbe() {
        guard !isLoading, !isCallingAgent else { return }
        if case .checking = cliState { return }
        transmissionConsent = false
        cliExecutable = nil
        probeCLI()
    }

    func reload() {
        reloadPending = true
        transmissionConsent = false
        performPendingReload()
    }

    func cancelOutstandingWork() {
        transmissionConsent = false
        cliProbeGeneration += 1
        cliExecutable = nil
        prepared = false
        if isCallingAgent {
            cancelAgentCall()
        } else {
            runner.cancel()
        }
    }

    private func performPendingReload() {
        guard reloadPending, !isLoading, !isCallingAgent else { return }
        reloadPending = false
        isLoading = true
        errorMessage = nil
        actionMessage = nil
        agentReview = nil
        agentUsage = nil
        let now = Date()
        let cutoff = scope.cutoff(relativeTo: now)
        let reader = self.reader
        queue.async { [weak self] in
            let result = Result {
                try reader.load(limit: 20, updatedAfter: cutoff, now: now)
            }
            DispatchQueue.main.async {
                guard let self else { return }
                self.isLoading = false
                switch result {
                case .success(let snapshot):
                    self.analysis = WingmanPortfolioAnalyzer.analyze(snapshot)
                    self.errorMessage = nil
                    self.refreshPacketPreview()
                case .failure:
                    self.analysis = nil
                    self.packetPreview = nil
                    self.errorMessage = self.language.text(
                        tr: "Wingman yerel analizi tamamlanamadı. Codex yerel kayıtlarını doğrulayıp yeniden dene.",
                        en: "The Wingman local analysis could not complete. Verify the local Codex records and try again."
                    )
                }
                self.performPendingReload()
            }
        }
    }

    func callWingman() {
        guard !isLoading, !isCallingAgent else { return }
        guard transmissionConsent else {
            errorMessage = language.text(
                tr: "Codex/OpenAI aktarımı için onay kutusunu işaretle.",
                en: "Select the consent checkbox for the Codex/OpenAI transfer."
            )
            return
        }
        transmissionConsent = false
        guard let analysis, let executable = cliExecutable else {
            errorMessage = language.text(
                tr: "Wingman ajanı hazır değil. Codex CLI durumunu denetleyip yeniden dene.",
                en: "The Wingman agent is not ready. Check the Codex CLI status and try again."
            )
            return
        }
        let packet = WingmanAgentPacketBuilder.make(
            analysis: analysis,
            includePromptExcerpts: includePromptExcerptsForAgent,
            responseLanguage: language.rawValue
        )
        let packetData: Data
        do {
            packetData = try WingmanAgentPacketBuilder.encode(packet)
        } catch {
            errorMessage = language.text(
                tr: "Wingman aktarım paketi hazırlanamadı.",
                en: "The Wingman transfer packet could not be prepared."
            )
            return
        }
        guard let previewData = packetPreview?.packetJSON.data(using: .utf8),
              previewData == packetData else {
            refreshPacketPreview()
            errorMessage = language.text(
                tr: "Gönderim önizlemesi değişti. Güncel paketi inceleyip yeniden onayla.",
                en: "The transfer preview changed. Review the current packet and consent again."
            )
            return
        }

        agentReview = nil
        agentUsage = nil
        guard runner.prepareInvocation() else {
            errorMessage = WingmanRunnerError.operationInProgress.message(language: language)
            return
        }
        markAgentCallStarted()
        errorMessage = nil
        actionMessage = language.text(
            tr: "Ayrı ve geçici Wingman oturumu çalışıyor…",
            en: "A separate, ephemeral Wingman session is running…"
        )
        let runner = self.runner
        queue.async { [weak self] in
            let result = Result {
                try runner.invoke(packetData: packetData, executable: executable)
            }
            DispatchQueue.main.async {
                guard let self else { return }
                self.completeAgentCall(result)
            }
        }
    }

    func cancelAgentCall() {
        guard isCallingAgent, !isCancellingAgent else { return }
        isCancellingAgent = true
        runner.cancel()
    }

    func markAgentCallStarted() {
        isCallingAgent = true
        isCancellingAgent = false
    }

    func completeAgentCall(_ result: Result<WingmanInvocationOutput, Error>) {
        let cancellationWasRequested = isCancellingAgent
        isCallingAgent = false
        isCancellingAgent = false

        if cancellationWasRequested {
            if case .failure(let error) = result,
               case .cleanupFailed? = error as? WingmanRunnerError {
                agentReview = nil
                agentUsage = nil
                actionMessage = nil
                errorMessage = WingmanRunnerError.cleanupFailed.message(language: language)
                cliExecutable = nil
                cliState = .unavailable(errorMessage ?? "")
                performPendingReload()
                return
            }
            agentReview = nil
            agentUsage = nil
            actionMessage = nil
            errorMessage = WingmanRunnerError.cancelled.message(language: language)
            performPendingReload()
            return
        }

        switch result {
        case .success(let output):
            agentReview = output.review
            agentUsage = output.usage
            actionMessage = language.text(
                tr: "Wingman incelemesi tamamlandı.",
                en: "The Wingman review is complete."
            )
            errorMessage = nil
        case .failure(let error):
            agentReview = nil
            agentUsage = nil
            actionMessage = nil
            errorMessage = (error as? WingmanRunnerError)?.message(language: language)
                ?? language.text(
                    tr: "Wingman ajan turu tamamlanamadı. Kısmi çıktı kullanılmadı.",
                    en: "The Wingman agent turn did not complete. Partial output was not used."
                )
            if let runnerError = error as? WingmanRunnerError {
                switch runnerError {
                case .cliUntrusted, .cleanupFailed:
                    cliExecutable = nil
                    cliState = .unavailable(runnerError.message(language: language))
                default:
                    break
                }
            }
        }
        performPendingReload()
    }

    func probeCLI() {
        cliProbeGeneration += 1
        let generation = cliProbeGeneration
        transmissionConsent = false
        cliExecutable = nil
        cliState = .checking
        let runner = self.runner
        guard runner.prepareInvocation() else {
            cliState = .unavailable(
                WingmanRunnerError.operationInProgress.message(language: language)
            )
            return
        }
        probeQueue.async { [weak self] in
            let result = Result { try runner.probe() }
            DispatchQueue.main.async {
                guard let self, generation == self.cliProbeGeneration else { return }
                switch result {
                case .success(let probe):
                    self.cliExecutable = probe.executable
                    self.cliState = .ready(version: probe.version)
                case .failure(let error):
                    self.cliExecutable = nil
                    self.cliState = .unavailable(wingmanProbeErrorMessage(
                        for: error,
                        language: self.language
                    ))
                }
            }
        }
    }

    private func refreshPacketPreview() {
        guard let analysis else {
            packetPreview = nil
            return
        }
        do {
            packetPreview = try WingmanAgentPacketBuilder.preview(
                analysis: analysis,
                includePromptExcerpts: includePromptExcerptsForAgent,
                responseLanguage: language.rawValue
            )
        } catch {
            packetPreview = nil
            errorMessage = language.text(
                tr: "Wingman aktarım önizlemesi hazırlanamadı.",
                en: "The Wingman transfer preview could not be prepared."
            )
        }
    }

}
