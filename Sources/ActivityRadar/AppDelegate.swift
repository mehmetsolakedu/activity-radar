import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var model: RadarViewModel!
    private var panelController: RadarPanelController!
    private var statusBarController: StatusBarController!
    private var globalHotKey: GlobalHotKey!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        model = RadarViewModel()
        panelController = RadarPanelController(model: model)
        model.didOpenThread = { [weak self] in
            self?.panelController.hide()
        }

        statusBarController = StatusBarController(
            language: model.language,
            onOpen: { [weak self] in self?.panelController.show() },
            onRefresh: { [weak self] in self?.model.refresh() }
        )
        model.languageDidChange = { [weak self] language in
            self?.statusBarController.updateLanguage(language)
        }

        globalHotKey = GlobalHotKey { [weak self] in
            self?.panelController.toggle()
        }
        _ = globalHotKey.register()

        model.start()
        panelController.show()
    }

    func applicationWillTerminate(_ notification: Notification) {
        model?.stop()
        globalHotKey?.unregister()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        panelController?.show()
        return true
    }
}
