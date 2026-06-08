import AppKit
import ClipboardPanel
import SwiftUI

@MainActor
final class ClipboardPanelWindowController {
    private let viewModel = ClipboardViewModel()
    private let appearance: ClipboardAppearancePreferences
    private let openSettings: () -> Void
    private var window: NSWindow?

    init(
        appearance: ClipboardAppearancePreferences,
        openSettings: @escaping () -> Void
    ) {
        self.appearance = appearance
        self.openSettings = openSettings
    }

    func showOrToggle() {
        if let window, window.isVisible, NSApp.isActive {
            window.orderOut(nil)
        } else {
            show()
        }
    }

    func show() {
        let window = window ?? makeWindow()
        self.window = window
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func makeWindow() -> NSWindow {
        let controller = NSHostingController(
            rootView: ClipboardPanelView(
                viewModel: viewModel,
                appearance: appearance,
                openSettings: openSettings
            )
        )
        let window = NSWindow(contentViewController: controller)
        window.title = "iCopy"
        window.setContentSize(NSSize(width: 440, height: 560))
        window.styleMask = [.titled, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.isReleasedWhenClosed = false
        window.level = .floating
        return window
    }
}
