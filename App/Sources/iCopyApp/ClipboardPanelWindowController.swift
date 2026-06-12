import AppKit
import ClipboardPanel
import SwiftUI

@MainActor
final class ClipboardPanelWindowController: NSObject, NSWindowDelegate {
    private let viewModel: ClipboardViewModel
    private let appearance: ClipboardAppearancePreferences
    private let openSettings: () -> Void
    private var window: NSWindow?
    private static let savedFrameKey = "clipboardPanel.windowFrame"

    init(
        viewModel: ClipboardViewModel,
        appearance: ClipboardAppearancePreferences,
        openSettings: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.appearance = appearance
        self.openSettings = openSettings
    }

    func showOrToggle() {
        if let window, window.isVisible {
            window.orderOut(nil)
        } else {
            show()
        }
    }

    func show() {
        let window = window ?? makeWindow()
        self.window = window
        viewModel.synchronizeClipboard()
        if let savedFrame = Self.loadSavedFrame(), let screenFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame {
            window.setFrame(Self.constrain(savedFrame, to: screenFrame), display: false)
        } else {
            window.center()
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowDidMove(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        Self.saveFrame(window.frame)
    }

    func windowDidResize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        Self.saveFrame(window.frame)
    }

    private func makeWindow() -> NSWindow {
        let controller = NSHostingController(
            rootView: ClipboardPanelView(
                viewModel: viewModel,
                appearance: appearance,
                openSettings: openSettings,
                closePanel: { [weak self] in self?.window?.orderOut(nil) }
            )
        )
        let window = NSWindow(contentViewController: controller)
        window.title = "iCopy"
        window.setContentSize(NSSize(width: 440, height: 560))
        window.styleMask = [.titled, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.delegate = self
        return window
    }

    private static func saveFrame(_ frame: NSRect) {
        UserDefaults.standard.set(NSStringFromRect(frame), forKey: savedFrameKey)
    }

    private static func loadSavedFrame() -> NSRect? {
        guard let value = UserDefaults.standard.string(forKey: savedFrameKey) else { return nil }
        let frame = NSRectFromString(value)
        return frame.isEmpty ? nil : frame
    }

    private static func constrain(_ frame: NSRect, to visibleFrame: NSRect) -> NSRect {
        var constrained = frame
        constrained.size.width = min(constrained.width, visibleFrame.width)
        constrained.size.height = min(constrained.height, visibleFrame.height)

        if constrained.maxX > visibleFrame.maxX {
            constrained.origin.x = visibleFrame.maxX - constrained.width
        }
        if constrained.minX < visibleFrame.minX {
            constrained.origin.x = visibleFrame.minX
        }
        if constrained.maxY > visibleFrame.maxY {
            constrained.origin.y = visibleFrame.maxY - constrained.height
        }
        if constrained.minY < visibleFrame.minY {
            constrained.origin.y = visibleFrame.minY
        }

        return constrained
    }
}
