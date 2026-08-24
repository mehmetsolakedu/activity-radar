import Foundation

private func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("ERROR: \(message)\n".utf8))
    exit(1)
}

guard CommandLine.arguments.count == 7 else {
    FileHandle.standardError.write(Data(
        "Usage: release-notes-check.swift FILE REPOSITORY TAG ZIP_NAME DMG_NAME ACCEPTANCE_NAME\n".utf8
    ))
    exit(64)
}

let fileURL = URL(fileURLWithPath: CommandLine.arguments[1])
let repository = CommandLine.arguments[2]
let tag = CommandLine.arguments[3]
let zipName = CommandLine.arguments[4]
let dmgName = CommandLine.arguments[5]
let acceptanceName = CommandLine.arguments[6]

guard
    repository.range(of: #"^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$"#, options: .regularExpression) != nil,
    tag.range(of: #"^v[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?$"#, options: .regularExpression) != nil,
    zipName.range(of: #"^AiWingman-[0-9A-Za-z.-]+-macOS-universal2\.zip$"#, options: .regularExpression) != nil,
    dmgName.range(of: #"^AiWingman-[0-9A-Za-z.-]+-macOS-universal2\.dmg$"#, options: .regularExpression) != nil,
    acceptanceName.range(of: #"^AiWingman-[0-9A-Za-z.-]+-CLEAN-MACHINE-ACCEPTANCE\.json$"#, options: .regularExpression) != nil
else {
    fail("invalid expected release-notes parameters")
}

let requiredHeadings = [
    "## Release status",
    "## Requirements",
    "## Install",
    "## Verify",
    "## First launch",
    "## Changes",
    "## Known limitations",
    "## Privacy, support, update, and removal",
    "## Release assets",
]

let draftAcceptanceLine = "During maintainer-only draft testing, the clean-machine acceptance asset is intentionally absent while the four base assets—the DMG, ZIP, `SHA256SUMS`, and `RELEASE-MANIFEST.txt`—are tested."
let publishedAcceptanceLine = "For a published release, the clean-machine acceptance asset listed below is mandatory; stop if it is absent."

do {
    let data = try Data(contentsOf: fileURL, options: [.mappedIfSafe])
    guard !data.isEmpty, data.count <= 64 * 1024 else {
        fail("release notes must be between 1 byte and 64 KiB")
    }
    guard !data.contains(0), !data.contains(0x0D) else {
        fail("release notes contain a NUL byte or CR line ending")
    }
    guard let text = String(data: data, encoding: .utf8) else {
        fail("release notes are not UTF-8")
    }
    let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    guard lines.first == "# AiWingman \(tag)" else {
        fail("release notes H1 must exactly match the release tag")
    }
    guard lines.dropFirst().allSatisfy({ !$0.hasPrefix("# ") }) else {
        fail("release notes contain an unexpected additional H1")
    }

    var previousIndex = -1
    var headingIndices: [String: Int] = [:]
    for heading in requiredHeadings {
        let matchingIndices = lines.indices.filter { lines[$0] == heading }
        guard matchingIndices.count == 1, let index = matchingIndices.first, index > previousIndex else {
            fail("required release-notes heading is missing, duplicated, or out of order: \(heading)")
        }
        headingIndices[heading] = index
        previousIndex = index
    }
    let unexpectedHeadings = lines.filter {
        $0.hasPrefix("## ") && !requiredHeadings.contains($0)
    }
    guard unexpectedHeadings.isEmpty else {
        fail("release notes contain an unexpected level-two heading")
    }

    func sectionLines(_ heading: String) -> [String] {
        guard
            let headingPosition = requiredHeadings.firstIndex(of: heading),
            let startIndex = headingIndices[heading]
        else {
            fail("release-notes section could not be resolved: \(heading)")
        }
        let endIndex: Int
        if headingPosition + 1 < requiredHeadings.count {
            guard let nextIndex = headingIndices[requiredHeadings[headingPosition + 1]] else {
                fail("release-notes section boundary could not be resolved: \(heading)")
            }
            endIndex = nextIndex
        } else {
            endIndex = lines.endIndex
        }
        return Array(lines[(startIndex + 1)..<endIndex])
    }

    func requireExactLine(_ requiredLine: String, in heading: String) {
        guard
            lines.filter({ $0 == requiredLine }).count == 1,
            sectionLines(heading).filter({ $0 == requiredLine }).count == 1
        else {
            fail("required release-notes line is missing, duplicated, or in the wrong section: \(requiredLine)")
        }
    }

    func requirePhrases(_ phrases: [String], in heading: String) {
        let sectionText = sectionLines(heading).joined(separator: "\n")
        for phrase in phrases where !sectionText.contains(phrase) {
            fail("release-notes section is missing a required anchor: \(heading): \(phrase)")
        }
    }

    func requireMeaningfulBullet(in heading: String) {
        let hasMeaningfulBullet = sectionLines(heading).contains { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("- ") else {
                return false
            }
            let body = trimmed.dropFirst(2).trimmingCharacters(in: .whitespaces)
            return !body.isEmpty && body.contains(where: { $0.isLetter || $0.isNumber })
        }
        guard hasMeaningfulBullet else {
            fail("release-notes section requires at least one nonempty descriptive bullet: \(heading)")
        }
    }

    let forbiddenPlaceholders = [
        "{{", "}}", "REPLACE_WITH", "TODO", "TBD", "FIXME", "XXX", "???", "PENDING",
        "<version>", "<tag>", "TEAMID1234",
    ]
    for placeholder in forbiddenPlaceholders where text.localizedCaseInsensitiveContains(placeholder) {
        fail("release notes contain an unresolved placeholder: \(placeholder)")
    }

    let exactRequiredLines: [(heading: String, line: String)] = [
        ("## Release status", "This is a Developer ID-signed and Apple-notarized installable public beta."),
        ("## Release status", "Historical note: v1.2.0-beta.1 is source-only and contains no installable binary."),
        ("## Verify", draftAcceptanceLine),
        ("## Verify", publishedAcceptanceLine),
        ("## Release assets", "- Recommended download: `\(dmgName)`"),
        ("## Release assets", "- Alternative download: `\(zipName)`"),
        ("## Release assets", "- Checksums: `SHA256SUMS`"),
        ("## Release assets", "- Build and signing provenance: `RELEASE-MANIFEST.txt`"),
        ("## Release assets", "- Clean-machine acceptance: `\(acceptanceName)`"),
        ("## Privacy, support, update, and removal", "- Installation: https://github.com/\(repository)/blob/\(tag)/INSTALL.md"),
        ("## Privacy, support, update, and removal", "- Privacy: https://github.com/\(repository)/blob/\(tag)/PRIVACY.md"),
        ("## Privacy, support, update, and removal", "- Security: https://github.com/\(repository)/blob/\(tag)/SECURITY.md"),
    ]
    for required in exactRequiredLines {
        requireExactLine(required.line, in: required.heading)
    }

    requirePhrases([
        "DMG is the recommended download",
        "drag AiWingman to Applications",
    ], in: "## Install")
    requirePhrases([
        "SHA256SUMS",
        "RELEASE-MANIFEST.txt",
        "four base assets",
    ], in: "## Verify")
    requirePhrases(["menu bar", "⌘⇧K"], in: "## First launch")
    requirePhrases([
        "Full Disk Access is not required",
        "INSTALL.md",
        "PRIVACY.md",
        "SECURITY.md",
    ], in: "## Privacy, support, update, and removal")
    requireMeaningfulBullet(in: "## Changes")
    requireMeaningfulBullet(in: "## Known limitations")

    print("PASS  installable release-notes contract")
} catch {
    fail("release notes could not be read")
}
