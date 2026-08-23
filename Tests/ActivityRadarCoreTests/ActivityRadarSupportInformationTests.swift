#if canImport(Testing)
import Testing
@testable import ActivityRadarCore

@Test
func supportInformationFormatsOnlyContentFreeBuildMetadata() {
    let revision = "3454b66ec5758dd334aef4167397a49a5aa56eea"
    let information = ActivityRadarSupportInformation(
        applicationVersion: "1.2.0",
        buildNumber: "4",
        releaseTag: "v1.2.0-beta.2",
        sourceRevision: revision,
        architecture: "arm64",
        operatingSystemVersion: "Version 13.7.8 (Build 22H730)"
    )

    #expect(
        information.formattedText == """
        AiWingman destek bilgisi
        Uygulama sürümü: 1.2.0 (4)
        Yayın etiketi: v1.2.0-beta.2
        Kaynak revizyonu: 3454b66ec575
        Çalışan mimari: arm64
        macOS: Version 13.7.8 (Build 22H730)
        """
    )
    #expect(!information.formattedText.contains(revision))
    #expect(
        information.aboutText == """
        Uygulama sürümü: 1.2.0 (4)
        Yayın etiketi: v1.2.0-beta.2
        Kaynak revizyonu: 3454b66ec575
        Çalışan mimari: arm64
        macOS: Version 13.7.8 (Build 22H730)

        Bağımsız bir topluluk projesidir.
        Resmi bir OpenAI ürünü değildir.
        Gizlilik: projenin PRIVACY.md belgesi
        Destek: projenin SUPPORT.md belgesi
        """
    )
    #expect(!information.formattedText.contains("OpenAI"))
    #expect(!information.formattedText.contains("PRIVACY.md"))
    #expect(!information.formattedText.contains("SUPPORT.md"))
}

@Test
func supportInformationRejectsUnexpectedOrContentBearingMetadata() {
    let information = ActivityRadarSupportInformation(
        applicationVersion: "1.2.0\nsecret",
        buildNumber: "4 /Users/example/private",
        releaseTag: "private-task-title",
        sourceRevision: "thread-id-checkpoint",
        architecture: "arm64; /Users/example/private",
        operatingSystemVersion: "private task title"
    )

    #expect(information.applicationVersion == "bilinmiyor")
    #expect(information.buildNumber == "bilinmiyor")
    #expect(information.releaseTag == nil)
    #expect(information.shortSourceRevision == nil)
    #expect(information.architecture == "bilinmiyor")
    #expect(information.operatingSystemVersion == "bilinmiyor")
    #expect(!information.formattedText.contains("private-task-title"))
    #expect(!information.formattedText.contains("/Users/example/private"))
    #expect(!information.formattedText.contains("thread-id-checkpoint"))
    #expect(!information.formattedText.contains("private task title"))
    #expect(!information.aboutText.contains("private-task-title"))
    #expect(!information.aboutText.contains("/Users/example/private"))
    #expect(!information.aboutText.contains("thread-id-checkpoint"))
    #expect(!information.aboutText.contains("private task title"))
}

@Test
func supportInformationAcceptsAndShortensSha256SourceRevision() {
    let revision = String(repeating: "A1", count: 32)
    let information = ActivityRadarSupportInformation(
        applicationVersion: "1.2.0",
        buildNumber: "4",
        releaseTag: nil,
        sourceRevision: revision,
        architecture: "x86_64",
        operatingSystemVersion: "Version 15.7.1 (Build 24G231)"
    )

    #expect(information.shortSourceRevision == "a1a1a1a1a1a1")
    #expect(information.releaseTag == nil)
    #expect(information.formattedText.contains("Yayın etiketi: atanmamış (yerel derleme)"))
}
#endif
