#!/usr/bin/env swift

import Foundation

private let hfsTypeUUID = "48465300-0000-" + "11AA-AA11-00306543ECAC"

private func resolvedPath(_ path: String) -> String {
    URL(fileURLWithPath: path).resolvingSymlinksInPath().path
}

private func loadPlist(_ path: String) throws -> [String: Any] {
    let data = try Data(contentsOf: URL(fileURLWithPath: path))
    guard let plist = try PropertyListSerialization.propertyList(
        from: data,
        format: nil
    ) as? [String: Any] else {
        throw CocoaError(.propertyListReadCorrupt)
    }
    return plist
}

private func checkBundle(_ appPath: String) throws {
    let root = URL(fileURLWithPath: appPath, isDirectory: true).standardizedFileURL
    let rootPrefix = root.path.hasSuffix("/") ? root.path : root.path + "/"
    let expectedEntries = Set([
        "Contents",
        "Contents/Info.plist",
        "Contents/MacOS",
        "Contents/MacOS/ActivityRadar",
        "Contents/Resources",
        "Contents/Resources/ActivityRadar.icns",
        "Contents/_CodeSignature",
        "Contents/_CodeSignature/CodeResources",
    ])
    var enumerationFailed = false
    guard let enumerator = FileManager.default.enumerator(
        at: root,
        includingPropertiesForKeys: nil,
        options: [],
        errorHandler: { _, _ in
            enumerationFailed = true
            return false
        }
    ) else {
        throw CocoaError(.fileReadUnknown)
    }

    var actualEntries = Set<String>()
    for case let entryURL as URL in enumerator {
        let entryPath = entryURL.standardizedFileURL.path
        guard entryPath.hasPrefix(rootPrefix) else {
            throw CocoaError(.fileReadInvalidFileName)
        }
        actualEntries.insert(String(entryPath.dropFirst(rootPrefix.count)))
    }
    guard !enumerationFailed, actualEntries == expectedEntries else {
        throw CocoaError(.fileReadCorruptFile)
    }
}

private func checkImageInfo(plistPath: String, imagePath: String) throws {
    let plist = try loadPlist(plistPath)
    guard
        plist["Class Name"] as? String == "CUDIFDiskImage",
        plist["Format"] as? String == "UDZO",
        let properties = plist["Properties"] as? [String: Any],
        properties["Checksummed"] as? Bool == true,
        properties["Compressed"] as? Bool == true,
        properties["Encrypted"] as? Bool == false,
        properties["Software License Agreement"] as? Bool == false,
        let segments = plist["Segments"] as? [String],
        segments.count == 1,
        resolvedPath(segments[0]) == resolvedPath(imagePath),
        let partitionContainer = plist["partitions"] as? [String: Any],
        partitionContainer["partition-scheme"] as? String == "GUID",
        partitionContainer["block-size"] as? Int == 512,
        partitionContainer["burnable"] as? Bool == false,
        let partitions = partitionContainer["partitions"] as? [[String: Any]]
    else {
        throw CocoaError(.propertyListReadCorrupt)
    }

    let expectedHints = [
        "MBR",
        "Primary GPT Header",
        "Primary GPT Table",
        "Apple_Free",
        "Apple_HFS",
        "Apple_Free",
        "Backup GPT Table",
        "Backup GPT Header",
    ]
    let exactHints = zip(partitions, expectedHints).allSatisfy {
        $0.0["partition-hint"] as? String == $0.1
    }
    guard
        partitions.count == expectedHints.count,
        exactHints,
        partitions.enumerated().allSatisfy({ index, partition in
            index == 4
                ? partition["partition-synthesized"] == nil
                : partition["partition-synthesized"] as? Bool == true
        }),
        partitions[0]["partition-start"] as? Int == 0,
        partitions[0]["partition-length"] as? Int == 1,
        partitions[1]["partition-start"] as? Int == 1,
        partitions[1]["partition-length"] as? Int == 1,
        partitions[2]["partition-start"] as? Int == 2,
        partitions[2]["partition-length"] as? Int == 32,
        partitions[3]["partition-start"] as? Int == 34,
        partitions[3]["partition-length"] as? Int == 6,
        partitions[4]["partition-start"] as? Int == 40,
        let hfsLength = partitions[4]["partition-length"] as? Int,
        hfsLength > 0,
        partitions[5]["partition-start"] as? Int == 40 + hfsLength,
        let trailingFreeLength = partitions[5]["partition-length"] as? Int,
        (1...7).contains(trailingFreeLength),
        partitions[6]["partition-start"] as? Int == 40 + hfsLength + trailingFreeLength,
        partitions[6]["partition-length"] as? Int == 32,
        partitions[7]["partition-start"] as? Int == 72 + hfsLength + trailingFreeLength,
        partitions[7]["partition-length"] as? Int == 1,
        let sizeInfo = plist["Size Information"] as? [String: Any],
        sizeInfo["Sector Count"] as? Int == 73 + hfsLength + trailingFreeLength,
        partitions[4]["partition-hint"] as? String == "Apple_HFS",
        partitions[4]["partition-hint-UUID"] as? String == hfsTypeUUID,
        partitions[4]["partition-number"] as? Int == 1,
        partitions[4]["partition-name"] as? String == "disk image",
        let filesystems = partitions[4]["partition-filesystems"] as? [String: Any],
        Set(filesystems.keys) == Set(["HFS+"]),
        let partitionInfo = plist["Partition Information"] as? [String: Any],
        Set(partitionInfo.keys) == Set(["-1", "0", "1", "2", "3", "4", "5", "6"]),
        partitionInfo.allSatisfy({ key, value in
            guard
                let entry = value as? [String: Any],
                let number = Int(key),
                entry["Partition Number"] as? Int == number
            else {
                return false
            }
            return true
        })
    else {
        throw CocoaError(.propertyListReadCorrupt)
    }

    let freeRegionNames = Set([" (Apple_Free : 3)", " (Apple_Free : 5)"])
    let freeRegions = partitionInfo.values.compactMap { $0 as? [String: Any] }.filter {
        guard let name = $0["Name"] as? String else { return false }
        return freeRegionNames.contains(name)
    }
    guard
        freeRegions.count == 2,
        freeRegions.allSatisfy({
            $0["Checksum Type"] as? String == "CRC32"
                && $0["Checksum Value"] as? String == "$00000000"
        })
    else {
        throw CocoaError(.propertyListReadCorrupt)
    }
}

private func checkAttach(plistPath: String, mountPath: String) throws -> (String, String) {
    let plist = try loadPlist(plistPath)
    guard let entities = plist["system-entities"] as? [[String: Any]] else {
        throw CocoaError(.propertyListReadCorrupt)
    }

    let hfsEntities = entities.filter { ($0["content-hint"] as? String) == "Apple_HFS" }
    let schemeEntities = entities.filter {
        ($0["content-hint"] as? String) == "GUID_partition_scheme"
    }
    let mountable = entities.filter { ($0["potentially-mountable"] as? Bool) == true }
    let mounted = entities.filter { $0["mount-point"] != nil }
    guard
        entities.count == 2,
        hfsEntities.count == 1,
        schemeEntities.count == 1,
        mountable.count == 1,
        mounted.count == 1,
        let leaf = hfsEntities.first,
        let scheme = schemeEntities.first,
        leaf["potentially-mountable"] as? Bool == true,
        leaf["unmapped-content-hint"] as? String == hfsTypeUUID,
        leaf["volume-kind"] as? String == "hfs",
        let mountPoint = leaf["mount-point"] as? String,
        resolvedPath(mountPoint) == resolvedPath(mountPath),
        let leafDevice = leaf["dev-entry"] as? String,
        leafDevice.range(
            of: #"^/dev/disk[0-9]+s1$"#,
            options: .regularExpression
        ) != nil,
        mountable[0]["dev-entry"] as? String == leafDevice,
        mounted[0]["dev-entry"] as? String == leafDevice,
        scheme["potentially-mountable"] as? Bool == false,
        scheme["mount-point"] == nil,
        scheme["unmapped-content-hint"] as? String == "GUID_partition_scheme",
        let schemeDevice = scheme["dev-entry"] as? String,
        schemeDevice.range(
            of: #"^/dev/disk[0-9]+$"#,
            options: .regularExpression
        ) != nil,
        leafDevice == schemeDevice + "s1"
    else {
        throw CocoaError(.propertyListReadCorrupt)
    }
    return (leafDevice, schemeDevice)
}

private func checkDiskInfo(
    plistPath: String,
    mountPath: String,
    leafDevice: String,
    wholeDevice: String
) throws {
    let info = try loadPlist(plistPath)
    guard
        info["BusProtocol"] as? String == "Disk Image",
        info["Content"] as? String == "Apple_HFS",
        info["FilesystemName"] as? String == "HFS+",
        info["FilesystemType"] as? String == "hfs",
        info["VolumeName"] as? String == "Activity Radar",
        info["DeviceNode"] as? String == leafDevice,
        info["DeviceIdentifier"] as? String == String(leafDevice.dropFirst("/dev/".count)),
        info["ParentWholeDisk"] as? String == String(wholeDevice.dropFirst("/dev/".count)),
        let actualMount = info["MountPoint"] as? String,
        resolvedPath(actualMount) == resolvedPath(mountPath),
        info["PartitionMapPartition"] as? Bool == true,
        info["WholeDisk"] as? Bool == false,
        info["Internal"] as? Bool == false,
        info["Ejectable"] as? Bool == true,
        info["Removable"] as? Bool == true,
        info["Bootable"] as? Bool == false,
        info["SystemImage"] as? Bool == false,
        info["Writable"] as? Bool == false,
        info["WritableMedia"] as? Bool == false,
        info["WritableVolume"] as? Bool == false
    else {
        throw CocoaError(.propertyListReadCorrupt)
    }
}

private func fail() -> Never {
    FileHandle.standardError.write(Data("DMG topology check failed.\n".utf8))
    exit(1)
}

do {
    guard CommandLine.arguments.count >= 2 else { fail() }
    switch CommandLine.arguments[1] {
    case "bundle":
        guard CommandLine.arguments.count == 3 else { fail() }
        try checkBundle(CommandLine.arguments[2])
    case "imageinfo":
        guard CommandLine.arguments.count == 4 else { fail() }
        try checkImageInfo(
            plistPath: CommandLine.arguments[2],
            imagePath: CommandLine.arguments[3]
        )
    case "attach":
        guard CommandLine.arguments.count == 4 else { fail() }
        let devices = try checkAttach(
            plistPath: CommandLine.arguments[2],
            mountPath: CommandLine.arguments[3]
        )
        print(devices.0 + "\t" + devices.1)
    case "diskutil":
        guard CommandLine.arguments.count == 6 else { fail() }
        try checkDiskInfo(
            plistPath: CommandLine.arguments[2],
            mountPath: CommandLine.arguments[3],
            leafDevice: CommandLine.arguments[4],
            wholeDevice: CommandLine.arguments[5]
        )
    default:
        fail()
    }
} catch {
    fail()
}
