import Darwin
import Foundation

struct CodexFileIdentity: Equatable {
    let device: UInt64
    let inode: UInt64
    let size: UInt64
    let modifiedSeconds: Int64
    let modifiedNanoseconds: Int64
    let changedSeconds: Int64
    let changedNanoseconds: Int64

    var cacheSignature: String {
        [
            device, inode, size,
            UInt64(bitPattern: modifiedSeconds), UInt64(bitPattern: modifiedNanoseconds),
            UInt64(bitPattern: changedSeconds), UInt64(bitPattern: changedNanoseconds),
        ].map(String.init).joined(separator: "-")
    }

}

struct CodexFileRead {
    let data: Data
    let identity: CodexFileIdentity
}

/// Opens files relative to a fixed Codex root without following the root,
/// intermediate directory components, or the final file. Every returned
/// descriptor is verified as a regular file before a bounded `pread`.
struct CodexSafeFileAccess {
    private let root: URL

    init(root: URL) {
        self.root = root.standardizedFileURL
    }

    func metadata(path: String) -> CodexFileIdentity? {
        guard let opened = openRegularFile(path: path) else { return nil }
        defer { Darwin.close(opened.descriptor) }
        return opened.identity
    }

    func read(
        path: String,
        offset: UInt64,
        maximumLength: UInt64,
        expectedIdentity: CodexFileIdentity? = nil
    ) -> CodexFileRead? {
        guard maximumLength <= UInt64(Int.max),
              offset <= UInt64(Int64.max),
              let opened = openRegularFile(path: path) else {
            return nil
        }
        defer { Darwin.close(opened.descriptor) }

        if let expectedIdentity, opened.identity != expectedIdentity {
            return nil
        }
        guard offset <= opened.identity.size else { return nil }

        let requested = min(maximumLength, opened.identity.size - offset)
        let requestedCount = Int(requested)
        guard requestedCount > 0 else {
            return CodexFileRead(data: Data(), identity: opened.identity)
        }

        var data = Data(count: requestedCount)
        let count = data.withUnsafeMutableBytes { buffer -> Int in
            guard let baseAddress = buffer.baseAddress else { return 0 }
            var total = 0
            while total < requestedCount {
                let result = pread(
                    opened.descriptor,
                    baseAddress.advanced(by: total),
                    requestedCount - total,
                    off_t(offset) + off_t(total)
                )
                if result < 0 {
                    if errno == EINTR { continue }
                    return -1
                }
                if result == 0 { break }
                total += result
            }
            return total
        }
        guard count >= 0 else { return nil }
        if count < data.count {
            data.removeSubrange(count..<data.count)
        }

        var finalStatus = stat()
        guard fstat(opened.descriptor, &finalStatus) == 0,
              let finalIdentity = Self.identity(from: finalStatus),
              finalIdentity == opened.identity else {
            return nil
        }
        return CodexFileRead(data: data, identity: finalIdentity)
    }

    private func openRegularFile(path: String) -> (descriptor: Int32, identity: CodexFileIdentity)? {
        guard !path.isEmpty else { return nil }
        let candidate = URL(fileURLWithPath: path).standardizedFileURL
        let rootComponents = root.pathComponents
        let candidateComponents = candidate.pathComponents
        guard candidateComponents.count > rootComponents.count,
              candidateComponents.prefix(rootComponents.count).elementsEqual(rootComponents) else {
            return nil
        }

        let relativeComponents = Array(candidateComponents.dropFirst(rootComponents.count))
        guard let fileName = relativeComponents.last,
              Self.isSafeComponent(fileName),
              relativeComponents.dropLast().allSatisfy(Self.isSafeComponent) else {
            return nil
        }

        let directoryFlags = O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK
        var directoryDescriptor = root.path.withCString { open($0, directoryFlags) }
        guard directoryDescriptor >= 0,
              Self.isTrustedDirectory(descriptor: directoryDescriptor) else {
            if directoryDescriptor >= 0 { Darwin.close(directoryDescriptor) }
            return nil
        }

        for component in relativeComponents.dropLast() {
            let nextDescriptor = component.withCString {
                openat(directoryDescriptor, $0, directoryFlags)
            }
            Darwin.close(directoryDescriptor)
            guard nextDescriptor >= 0,
                  Self.isTrustedDirectory(descriptor: nextDescriptor) else {
                if nextDescriptor >= 0 { Darwin.close(nextDescriptor) }
                return nil
            }
            directoryDescriptor = nextDescriptor
        }

        let fileFlags = O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK
        let descriptor = fileName.withCString {
            openat(directoryDescriptor, $0, fileFlags)
        }
        Darwin.close(directoryDescriptor)
        guard descriptor >= 0 else { return nil }

        var status = stat()
        guard fstat(descriptor, &status) == 0,
              status.st_uid == geteuid(),
              status.st_nlink == 1,
              status.st_mode & (S_IWGRP | S_IWOTH) == 0,
              let identity = Self.identity(from: status) else {
            Darwin.close(descriptor)
            return nil
        }
        return (descriptor, identity)
    }

    private static func identity(from status: stat) -> CodexFileIdentity? {
        guard status.st_mode & S_IFMT == S_IFREG, status.st_size >= 0 else {
            return nil
        }
        return CodexFileIdentity(
            device: UInt64(status.st_dev),
            inode: UInt64(status.st_ino),
            size: UInt64(status.st_size),
            modifiedSeconds: Int64(status.st_mtimespec.tv_sec),
            modifiedNanoseconds: Int64(status.st_mtimespec.tv_nsec),
            changedSeconds: Int64(status.st_ctimespec.tv_sec),
            changedNanoseconds: Int64(status.st_ctimespec.tv_nsec)
        )
    }

    private static func isTrustedDirectory(descriptor: Int32) -> Bool {
        var status = stat()
        return fstat(descriptor, &status) == 0
            && status.st_mode & S_IFMT == S_IFDIR
            && status.st_uid == geteuid()
            && status.st_mode & (S_IWGRP | S_IWOTH) == 0
    }

    private static func isSafeComponent(_ component: String) -> Bool {
        !component.isEmpty && component != "." && component != ".." && !component.contains("/")
    }
}
