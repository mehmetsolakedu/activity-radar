import AppKit
import SwiftUI

extension Notification.Name {
    static let activityRadarDidShow = Notification.Name("ActivityRadar.didShow")
}

private final class KeyableRadarPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class RadarPanelController: NSObject, NSWindowDelegate {
    let panel: NSPanel
    private let model: RadarViewModel

    init(model: RadarViewModel) {
        self.model = model
        panel = KeyableRadarPanel(
            contentRect: NSRect(x: 0, y: 0, width: 930, height: 724),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        super.init()

        panel.delegate = self
        panel.title = "Activity Radar"
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.minSize = NSSize(width: 780, height: 620)
        panel.maxSize = NSSize(width: 1_080, height: 840)

        let rootView = RadarView(model: model) { [weak panel] in
            panel?.orderOut(nil)
        }
        panel.contentView = NSHostingView(rootView: rootView)
        panel.center()
    }

    var isVisible: Bool {
        panel.isVisible
    }

    func show() {
        model.prepareForPresentation()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        NotificationCenter.default.post(name: .activityRadarDidShow, object: nil)
    }

    func hide() {
        panel.orderOut(nil)
    }

    func toggle() {
        isVisible ? hide() : show()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }
}
