import AppKit
import ActivityRadarCore

@MainActor
final class StatusBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let onOpen: () -> Void
    private let onRefresh: () -> Void
    private let supportInformation: ActivityRadarSupportInformation

    init(onOpen: @escaping () -> Void, onRefresh: @escaping () -> Void) {
        self.onOpen = onOpen
        self.onRefresh = onRefresh
        self.supportInformation = Self.makeSupportInformation()
        super.init()

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "scope", accessibilityDescription: "Activity Radar")
            button.toolTip = "Activity Radar · Work Continuity · ⌘⇧K"
        }

        let menu = NSMenu()
        let openItem = NSMenuItem(
            title: "Activity Radar’ı Aç",
            action: #selector(openRadar),
            keyEquivalent: "k"
        )
        openItem.keyEquivalentModifierMask = [.command, .shift]
        openItem.target = self
        menu.addItem(openItem)

        let refreshItem = NSMenuItem(
            title: "Şimdi Yenile",
            action: #selector(refresh),
            keyEquivalent: "r"
        )
        refreshItem.keyEquivalentModifierMask = [.command]
        refreshItem.target = self
        menu.addItem(refreshItem)
        menu.addItem(.separator())

        let aboutItem = NSMenuItem(
            title: "Activity Radar Hakkında…",
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)

        let copySupportItem = NSMenuItem(
            title: "Destek Bilgisini Kopyala",
            action: #selector(copySupportInformation),
            keyEquivalent: ""
        )
        copySupportItem.target = self
        menu.addItem(copySupportItem)
        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Activity Radar’dan Çık",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.keyEquivalentModifierMask = [.command]
        quitItem.target = self
        menu.addItem(quitItem)
        statusItem.menu = menu
    }

    @objc private func openRadar() {
        onOpen()
    }

    @objc private func refresh() {
        onRefresh()
    }

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Activity Radar"
        alert.informativeText = supportInformation.aboutText
        alert.icon = NSApp.applicationIconImage
        alert.addButton(withTitle: "Tamam")

        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    @objc private func copySupportInformation() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(supportInformation.formattedText, forType: .string)
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
        "bilinmiyor"
        #endif
    }
}
