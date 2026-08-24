import CoreFoundation
import Foundation

private let requiredRootKeys: Set<String> = [
    "dmgAssetName",
    "dmgSHA256",
    "records",
    "releaseCreatedAt",
    "releaseID",
    "releaseTag",
    "repository",
    "schemaVersion",
]

private let requiredRecordKeys: Set<String> = [
    "aboutReleaseIdentityVerified",
    "applicationCopiedToApplications",
    "applicationReplacementSucceeded",
    "architecture",
    "browserDownloadQuarantineObserved",
    "checksumVerified",
    "dmgEjected",
    "dmgMountedReadOnly",
    "downloadedFromGitHubRelease",
    "gatekeeperLaunchSucceeded",
    "interfaceLanguageSwitchPersisted",
    "macOSBuild",
    "macOSVersion",
    "machineDidNotBuildRelease",
    "menuBarItemVisible",
    "syntheticCodexDeepLinkSucceeded",
    "supportInformationContentFree",
    "testedAt",
    "uninstallSucceeded",
    "wingmanCLIUnavailableFallbackVerified",
    "wingmanConsentPreviewVerified",
    "wingmanRemoteReviewSucceeded",
]

private func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("ERROR: \(message)\n".utf8))
    exit(1)
}

private func isJSONInteger(_ value: Any?, equalTo expected: Int? = nil) -> Bool {
    guard
        let number = value as? NSNumber,
        CFGetTypeID(number) != CFBooleanGetTypeID(),
        !CFNumberIsFloatType(number),
        number.int64Value > 0
    else {
        return false
    }
    return expected.map { number.int64Value == Int64($0) } ?? true
}

private func isTrueJSONBoolean(_ value: Any?) -> Bool {
    guard
        let number = value as? NSNumber,
        CFGetTypeID(number) == CFBooleanGetTypeID()
    else {
        return false
    }
    return number.boolValue
}

private func matches(_ value: String, _ pattern: String) -> Bool {
    value.range(of: pattern, options: .regularExpression) != nil
}

private func parseCanonicalUTC(_ value: String) -> Date? {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    guard
        let date = formatter.date(from: value),
        formatter.string(from: date) == value
    else {
        return nil
    }
    return date
}

private enum JSONStructureError: Error {
    case malformed
    case duplicateKey
}

private struct DuplicateRejectingJSONParser {
    private let characters: [Character]
    private var index = 0

    init(_ text: String) {
        characters = Array(text)
    }

    mutating func parse() throws {
        skipWhitespace()
        try parseValue()
        skipWhitespace()
        guard index == characters.count else {
            throw JSONStructureError.malformed
        }
    }

    private mutating func parseValue() throws {
        skipWhitespace()
        guard let character = current else {
            throw JSONStructureError.malformed
        }
        switch character {
        case "{":
            try parseObject()
        case "[":
            try parseArray()
        case "\"":
            _ = try parseString()
        case "t":
            try consumeLiteral("true")
        case "f":
            try consumeLiteral("false")
        case "n":
            try consumeLiteral("null")
        case "-", "0"..."9":
            try parseNumberToken()
        default:
            throw JSONStructureError.malformed
        }
    }

    private mutating func parseObject() throws {
        try consume("{")
        skipWhitespace()
        if consumeIfPresent("}") {
            return
        }
        var keys = Set<String>()
        while true {
            skipWhitespace()
            let key = try parseString()
            guard keys.insert(key).inserted else {
                throw JSONStructureError.duplicateKey
            }
            skipWhitespace()
            try consume(":")
            try parseValue()
            skipWhitespace()
            if consumeIfPresent("}") {
                return
            }
            try consume(",")
        }
    }

    private mutating func parseArray() throws {
        try consume("[")
        skipWhitespace()
        if consumeIfPresent("]") {
            return
        }
        while true {
            try parseValue()
            skipWhitespace()
            if consumeIfPresent("]") {
                return
            }
            try consume(",")
        }
    }

    private mutating func parseString() throws -> String {
        guard current == "\"" else {
            throw JSONStructureError.malformed
        }
        let start = index
        index += 1
        while let character = current {
            if character == "\"" {
                index += 1
                let token = String(characters[start..<index])
                guard let tokenData = token.data(using: .utf8) else {
                    throw JSONStructureError.malformed
                }
                return try JSONDecoder().decode(String.self, from: tokenData)
            }
            if character == "\\" {
                index += 1
                guard let escape = current,
                      ["\"", "\\", "/", "b", "f", "n", "r", "t", "u"].contains(escape) else {
                    throw JSONStructureError.malformed
                }
                index += 1
                if escape == "u" {
                    for _ in 0..<4 {
                        guard let hex = current, hex.isHexDigit else {
                            throw JSONStructureError.malformed
                        }
                        index += 1
                    }
                }
                continue
            }
            guard character.unicodeScalars.allSatisfy({ $0.value >= 0x20 }) else {
                throw JSONStructureError.malformed
            }
            index += 1
        }
        throw JSONStructureError.malformed
    }

    private mutating func parseNumberToken() throws {
        let start = index
        while let character = current, "-+0123456789.eE".contains(character) {
            index += 1
        }
        guard index > start else {
            throw JSONStructureError.malformed
        }
    }

    private mutating func consumeLiteral(_ literal: String) throws {
        for character in literal {
            try consume(character)
        }
    }

    private mutating func consume(_ expected: Character) throws {
        guard current == expected else {
            throw JSONStructureError.malformed
        }
        index += 1
    }

    private mutating func consumeIfPresent(_ expected: Character) -> Bool {
        guard current == expected else {
            return false
        }
        index += 1
        return true
    }

    private mutating func skipWhitespace() {
        while let character = current, [" ", "\t", "\n", "\r"].contains(character) {
            index += 1
        }
    }

    private var current: Character? {
        index < characters.count ? characters[index] : nil
    }
}

let canonicalize = CommandLine.arguments.dropFirst().first == "--canonicalize"
let argumentOffset = canonicalize ? 2 : 1
let expectedArgumentCount = canonicalize ? 9 : 8

guard CommandLine.arguments.count == expectedArgumentCount else {
    FileHandle.standardError.write(Data(
        "Usage: clean-machine-acceptance-check.swift [--canonicalize] FILE REPOSITORY TAG RELEASE_ID RELEASE_CREATED_AT DMG_NAME DMG_SHA256\n".utf8
    ))
    exit(64)
}

let inputURL = URL(fileURLWithPath: CommandLine.arguments[argumentOffset])
let expectedRepository = CommandLine.arguments[argumentOffset + 1]
let expectedTag = CommandLine.arguments[argumentOffset + 2]
let expectedReleaseID = CommandLine.arguments[argumentOffset + 3]
let expectedReleaseCreatedAt = CommandLine.arguments[argumentOffset + 4]
let expectedDMGName = CommandLine.arguments[argumentOffset + 5]
let expectedDMGSHA256 = CommandLine.arguments[argumentOffset + 6]

guard
    matches(expectedRepository, #"^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$"#),
    matches(expectedTag, #"^v[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?$"#),
    matches(expectedReleaseID, #"^[1-9][0-9]*$"#),
    matches(expectedReleaseCreatedAt, #"^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$"#),
    parseCanonicalUTC(expectedReleaseCreatedAt) != nil,
    matches(expectedDMGName, #"^AiWingman-[0-9A-Za-z.-]+-macOS-universal2\.dmg$"#),
    matches(expectedDMGSHA256, #"^[0-9a-f]{64}$"#)
else {
    fail("invalid expected release parameters")
}

do {
    let inputData = try Data(contentsOf: inputURL, options: [.mappedIfSafe])
    guard !inputData.isEmpty, inputData.count <= 64 * 1024 else {
        fail("acceptance file must be between 1 byte and 64 KiB")
    }
    guard !inputData.contains(0) else {
        fail("acceptance file contains a NUL byte")
    }
    guard let inputText = String(data: inputData, encoding: .utf8) else {
        fail("acceptance file is not UTF-8")
    }
    do {
        var structureParser = DuplicateRejectingJSONParser(inputText)
        try structureParser.parse()
    } catch JSONStructureError.duplicateKey {
        fail("acceptance file contains a duplicate JSON object key")
    } catch {
        fail("acceptance file has malformed JSON structure")
    }
    guard
        let root = try JSONSerialization.jsonObject(with: inputData) as? [String: Any],
        Set(root.keys) == requiredRootKeys
    else {
        fail("acceptance root schema is not exact")
    }

    guard isJSONInteger(root["schemaVersion"], equalTo: 1) else {
        fail("schemaVersion must be the integer 1")
    }
    guard root["repository"] as? String == expectedRepository else {
        fail("repository does not match the release repository")
    }
    guard root["releaseTag"] as? String == expectedTag else {
        fail("releaseTag does not match the release tag")
    }
    guard root["releaseCreatedAt"] as? String == expectedReleaseCreatedAt else {
        fail("releaseCreatedAt does not match the GitHub draft release")
    }
    guard
        isJSONInteger(root["releaseID"]),
        String((root["releaseID"] as! NSNumber).int64Value) == expectedReleaseID
    else {
        fail("releaseID does not match the GitHub draft release")
    }
    guard root["dmgAssetName"] as? String == expectedDMGName else {
        fail("dmgAssetName does not match the verified DMG")
    }
    guard root["dmgSHA256"] as? String == expectedDMGSHA256 else {
        fail("dmgSHA256 does not match the verified DMG")
    }
    guard let records = root["records"] as? [[String: Any]], records.count == 2 else {
        fail("records must contain exactly one arm64 and one x86_64 result")
    }

    let expectedArchitectures = ["arm64", "x86_64"]
    let releaseCreatedDate = parseCanonicalUTC(expectedReleaseCreatedAt)!
    var hasVenturaRecord = false
    for (index, record) in records.enumerated() {
        guard Set(record.keys) == requiredRecordKeys else {
            fail("record \(index + 1) schema is not exact")
        }
        guard record["architecture"] as? String == expectedArchitectures[index] else {
            fail("records must be ordered arm64, then x86_64")
        }
        guard
            let macOSVersion = record["macOSVersion"] as? String,
            matches(macOSVersion, #"^(?:1[3-9]|[2-9][0-9])\.(?:0|[1-9][0-9]?)(?:\.(?:0|[1-9][0-9]?))?$"#),
            let major = Int(macOSVersion.split(separator: ".", maxSplits: 1)[0]),
            major >= 13
        else {
            fail("record \(index + 1) has an invalid macOSVersion")
        }
        if major == 13 {
            hasVenturaRecord = true
        }
        guard
            let macOSBuild = record["macOSBuild"] as? String,
            matches(macOSBuild, #"^[0-9]{2}[A-Z][A-Za-z0-9]{1,12}$"#)
        else {
            fail("record \(index + 1) has an invalid macOSBuild")
        }
        guard
            let testedAt = record["testedAt"] as? String,
            matches(testedAt, #"^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$"#),
            let testedDate = parseCanonicalUTC(testedAt),
            testedDate >= releaseCreatedDate,
            testedDate <= Date().addingTimeInterval(10 * 60)
        else {
            fail("record \(index + 1) testedAt must be canonical UTC, after draft creation, and not in the future")
        }

        for booleanKey in requiredRecordKeys.subtracting([
            "architecture", "macOSBuild", "macOSVersion", "testedAt",
        ]) {
            guard isTrueJSONBoolean(record[booleanKey]) else {
                fail("record \(index + 1) requires true for \(booleanKey)")
            }
        }
    }
    guard hasVenturaRecord else {
        fail("at least one record must be a real macOS 13.x runtime check")
    }

    var canonicalData = try JSONSerialization.data(
        withJSONObject: root,
        options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    )
    canonicalData.append(0x0A)
    if canonicalize {
        FileHandle.standardOutput.write(canonicalData)
        exit(0)
    }
    guard inputData == canonicalData else {
        fail("acceptance file is not canonical sorted JSON with one trailing newline")
    }

    print("PASS  clean-machine acceptance: arm64 + x86_64, including macOS 13.x")
} catch {
    fail("acceptance file is not valid UTF-8 JSON")
}
