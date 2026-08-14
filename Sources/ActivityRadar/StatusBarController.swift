import AppKit

@MainActor
final class StatusBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let onOpen: () -> Void
    private let onRefresh: () -> Void

    init(onOpen: @escaping () -> Void, onRefresh: @escaping () -> Void) {
        self.onOpen = onOpen
        self.onRefresh = onRefresh
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

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
