import Foundation

public struct ActivityRadarSupportInformation: Equatable, Sendable {
    public let applicationVersion: String
    public let buildNumber: String
    public let releaseTag: String?
    public let shortSourceRevision: String?
    public let architecture: String
    public let operatingSystemVersion: String

    public init(
        applicationVersion: String?,
        buildNumber: String?,
        releaseTag: String?,
        sourceRevision: String?,
        architecture: String,
        operatingSystemVersion: String
    ) {
        self.applicationVersion = Self.safeNumericVersion(applicationVersion) ?? "bilinmiyor"
        self.buildNumber = Self.safeBuildNumber(buildNumber) ?? "bilinmiyor"
        self.releaseTag = Self.safeReleaseTag(releaseTag)
        self.shortSourceRevision = Self.safeSourceRevision(sourceRevision).map {
            String($0.prefix(12))
        }
        self.architecture = Self.safeArchitecture(architecture) ?? "bilinmiyor"
        self.operatingSystemVersion = Self.safeOperatingSystemVersion(operatingSystemVersion)
            ?? "bilinmiyor"
    }

    public var formattedText: String {
        let displayedReleaseTag = releaseTag ?? "atanmamış (yerel derleme)"
        let displayedSourceRevision = shortSourceRevision ?? "atanmamış (yerel derleme)"
        return [
            "AiWingman destek bilgisi",
            "Uygulama sürümü: \(applicationVersion) (\(buildNumber))",
            "Yayın etiketi: \(displayedReleaseTag)",
            "Kaynak revizyonu: \(displayedSourceRevision)",
            "Çalışan mimari: \(architecture)",
            "macOS: \(operatingSystemVersion)"
        ].joined(separator: "\n")
    }

    public var aboutText: String {
        let buildMetadata = formattedText
            .split(separator: "\n", omittingEmptySubsequences: false)
            .dropFirst()
            .joined(separator: "\n")
        return [
            buildMetadata,
            "",
            "Bağımsız bir topluluk projesidir.",
            "Resmi bir OpenAI ürünü değildir.",
            "Gizlilik: projenin PRIVACY.md belgesi",
            "Destek: projenin SUPPORT.md belgesi"
        ].joined(separator: "\n")
    }

    private static func safeNumericVersion(_ value: String?) -> String? {
        guard let value = safeASCII(value, maximumLength: 32, allowing: { byte in
            (48...57).contains(byte) || byte == 46
        }), value.range(
            of: #"^[0-9]+(\.[0-9]+)*$"#,
            options: .regularExpression
        ) != nil else {
            return nil
        }
        return value
    }

    private static func safeBuildNumber(_ value: String?) -> String? {
        safeASCII(value, maximumLength: 20) { byte in
            (48...57).contains(byte)
        }
    }

    private static func safeReleaseTag(_ value: String?) -> String? {
        guard let value = safeASCII(value, maximumLength: 80, allowing: { byte in
            (48...57).contains(byte)
                || (65...90).contains(byte)
                || (97...122).contains(byte)
                || [43, 45, 46, 95].contains(byte)
        }), value.range(
            of: #"^v[0-9]+(\.[0-9]+)*(-[0-9A-Za-z][0-9A-Za-z.-]*)?$"#,
            options: .regularExpression
        ) != nil else {
            return nil
        }
        return value
    }

    private static func safeSourceRevision(_ value: String?) -> String? {
        guard let value,
              value.utf8.count == 40 || value.utf8.count == 64,
              value.utf8.allSatisfy({ byte in
                  (48...57).contains(byte)
                      || (65...70).contains(byte)
                      || (97...102).contains(byte)
              }) else {
            return nil
        }
        return value.lowercased()
    }

    private static func safeArchitecture(_ value: String) -> String? {
        ["arm64", "x86_64"].contains(value) ? value : nil
    }

    private static func safeOperatingSystemVersion(_ value: String) -> String? {
        guard let value = safeASCII(value, maximumLength: 100, allowing: { byte in
            (48...57).contains(byte)
                || (65...90).contains(byte)
                || (97...122).contains(byte)
                || [32, 40, 41, 45, 46, 95].contains(byte)
        }), value.range(
            of: #"^Version [0-9]+(\.[0-9]+){1,2} \(Build [0-9A-Za-z]+\)$"#,
            options: .regularExpression
        ) != nil else {
            return nil
        }
        return value
    }

    private static func safeASCII(
        _ value: String?,
        maximumLength: Int,
        allowing isAllowed: (UInt8) -> Bool
    ) -> String? {
        guard let value,
              !value.isEmpty,
              value.utf8.count <= maximumLength,
              value.utf8.allSatisfy(isAllowed) else {
            return nil
        }
        return value
    }
}
