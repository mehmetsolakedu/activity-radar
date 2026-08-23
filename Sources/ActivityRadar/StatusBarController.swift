import AppKit
import ActivityRadarCore

@MainActor
final class StatusBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let onOpen: () -> Void
    private let onRefresh: () -> Void
    private let supportInformation: ActivityRadarSupportInformation
    private let openItem = NSMenuItem()
    private let refreshItem = NSMenuItem()
    private let aboutItem = NSMenuItem()
    private let copySupportItem = NSMenuItem()
    private let quitItem = NSMenuItem()
    private var language: RadarLanguage

    init(
        language: RadarLanguage,
        onOpen: @escaping () -> Void,
        onRefresh: @escaping () -> Void
    ) {
        self.onOpen = onOpen
        self.onRefresh = onRefresh
        self.supportInformation = Self.makeSupportInformation()
        self.language = language
        super.init()

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "scope", accessibilityDescription: "AiWingman")
        }

        let menu = NSMenu()
        openItem.action = #selector(openRadar)
        openItem.keyEquivalent = "k"
        openItem.keyEquivalentModifierMask = [.command, .shift]
        openItem.target = self
        menu.addItem(openItem)

        refreshItem.action = #selector(refresh)
        refreshItem.keyEquivalent = "r"
        refreshItem.keyEquivalentModifierMask = [.command]
        refreshItem.target = self
        menu.addItem(refreshItem)
        menu.addItem(.separator())

        aboutItem.action = #selector(showAbout)
        aboutItem.target = self
        menu.addItem(aboutItem)

        copySupportItem.action = #selector(copySupportInformation)
        copySupportItem.target = self
        menu.addItem(copySupportItem)
        menu.addItem(.separator())

        quitItem.action = #selector(quit)
        quitItem.keyEquivalent = "q"
        quitItem.keyEquivalentModifierMask = [.command]
        quitItem.target = self
        menu.addItem(quitItem)
        statusItem.menu = menu
        updateLanguage(language)
    }

    func updateLanguage(_ language: RadarLanguage) {
        self.language = language
        let l10n = RadarL10n(language: language)
        statusItem.button?.toolTip = l10n.text(
            "AiWingman · İş Sürekliliği · ⌘⇧K",
            "AiWingman · Work Continuity · ⌘⇧K"
        )
        openItem.title = l10n.text("AiWingman’i Aç", "Open AiWingman")
        refreshItem.title = l10n.text("Şimdi Yenile", "Refresh Now")
        aboutItem.title = l10n.text("AiWingman Hakkında…", "About AiWingman…")
        copySupportItem.title = l10n.text("Destek Bilgisini Kopyala", "Copy Support Information")
        quitItem.title = l10n.text("AiWingman’den Çık", "Quit AiWingman")
    }

    @objc private func openRadar() {
        onOpen()
    }

    @objc private func refresh() {
        onRefresh()
    }

    @objc private func showAbout() {
        let alert = NSAlert()
        let l10n = RadarL10n(language: language)
        alert.alertStyle = .informational
        alert.messageText = "AiWingman"
        alert.informativeText = l10n.aboutText(supportInformation)
        alert.icon = NSApp.applicationIconImage
        alert.addButton(withTitle: l10n.text("Tamam", "OK"))

        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    @objc private func copySupportInformation() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(
            RadarL10n(language: language).supportText(supportInformation),
            forType: .string
        )
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private static func makeSupportInformation() -> ActivityRadarSupportInformation {
        let info = Bundle.main.infoDictionary ?? [:]
        return ActivityRadarSupportInformation(
            applicationVersion: info["CFBundleShortVersionString"] as? String,
            buildNumber: info["CFBundleVersion"] as? String,
            releaseTag: info["ActivityRadarReleaseTag"] as? String,
            sourceRevision: info["ActivityRadarSourceRevision"] as? String,
            architecture: runningArchitecture,
            operatingSystemVersion: ProcessInfo.processInfo.operatingSystemVersionString
        )
    }

    private static var runningArchitecture: String {
        #if arch(arm64)
        "arm64"
        #elseif arch(x86_64)
        "x86_64"
        #else
        "unknown"
        #endif
    }
}
