import AppKit
import Combine
import DesktopCard
import ICopyCore
import SwiftUI

/// 单张桌面卡片的窗口控制器:在 DesktopCardPanel 中托管 DesktopCardView,按锁定态切换窗口层级与
/// 可移动/可缩放,持久化几何,并把视图上报的可复制区域转交锁定覆盖层。
@MainActor
final class DesktopCardWindowController: NSObject, NSWindowDelegate {
    let id: StickyCardItem.ID

    private let viewModel: DesktopCardViewModel
    private let toast: CopiedToastController
    private let onCloseRequested: (StickyCardItem.ID) -> Void

    private var panel: DesktopCardPanel?
    private var overlay: LockOverlayController?
    private var settingsPanel: NSPanel?
    private var cardObservation: AnyCancellable?
    private var lastLocked: Bool?

    init(
        viewModel: DesktopCardViewModel,
        toast: CopiedToastController,
        onCloseRequested: @escaping (StickyCardItem.ID) -> Void
    ) {
        self.id = viewModel.id
        self.viewModel = viewModel
        self.toast = toast
        self.onCloseRequested = onCloseRequested
        super.init()
    }

    func show(activate: Bool = true) {
        let panel = panel ?? makeWindow()
        self.panel = panel
        applyState(viewModel.card, force: true)
        if viewModel.card.isLocked {
            panel.orderFront(nil)
        } else if activate {
            // 无边框面板需 app 激活 + 成为 key,内部 NSTextView 才能取得第一响应者接受输入。
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
            if viewModel.card.isManual { focusFirstTextView() }
        } else {
            panel.orderFront(nil)
        }
    }

    func close() {
        cardObservation?.cancel()
        cardObservation = nil
        overlay?.teardown()
        overlay = nil
        panel?.teardownResizeHandling()
        settingsPanel?.orderOut(nil)
        settingsPanel = nil
        panel?.orderOut(nil)
        panel = nil
    }

    // MARK: - 窗口构建

    private func makeWindow() -> DesktopCardPanel {
        // 刻意不加 .nonactivatingPanel:解锁卡片需成为 key 窗口供文本编辑;
        // 覆盖层面板才用 nonactivating(它们不应激活 app)。
        let panel = DesktopCardPanel(
            contentRect: viewModel.card.frame,
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
        panel.delegate = self
        panel.onFrameCommitted = { [weak self] frame in
            self?.viewModel.setFrame(frame)
            self?.overlay?.reposition()
        }

        let view = DesktopCardView(
            viewModel: viewModel,
            onOpenSettings: { [weak self] in self?.showSettings() },
            onClose: { [weak self] in self?.requestClose() },
            onRegionsChanged: { [weak self] regions in self?.overlay?.updateRegions(regions) },
            onCopied: { [weak self] in self?.toast.flash(at: NSEvent.mouseLocation) }
        )
        panel.contentView = FirstMouseHostingView(rootView: view)
        panel.setFrame(viewModel.card.frame, display: false)
        panel.installResizeHandling()

        overlay = LockOverlayController(
            panel: panel,
            onUnlock: { [weak self] in self?.viewModel.toggleLock() },
            onInsertDivider: { [weak self] in self?.insertDividerFromToolbar() },
            onOpenSettings: { [weak self] in self?.showSettings() },
            onClose: { [weak self] in self?.requestClose() },
            onCopy: { [weak self] payload, screenPoint in self?.performCopy(payload, at: screenPoint) },
            scrollForwardingEnabled: true
        )

        cardObservation = viewModel.$card.sink { [weak self] card in
            self?.applyState(card, force: false)
        }
        return panel
    }

    // MARK: - 锁定/解锁态

    private func applyState(_ card: StickyCardItem, force: Bool) {
        guard let panel else { return }
        let locked = card.isLocked
        overlay?.updateToolbar(includesDividerButton: card.isManual)
        guard force || locked != lastLocked else { return }
        lastLocked = locked

        if locked {
            panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) - 1)
            panel.isMovable = false
            panel.isMovableByWindowBackground = false
            panel.isResizingEnabled = false
        } else {
            panel.level = .normal
            panel.isMovable = true
            panel.isMovableByWindowBackground = true
            panel.isResizingEnabled = true
        }
        overlay?.setLocked(locked)
    }

    private func performCopy(_ payload: CardCopyableRegion.Payload, at screenPoint: NSPoint) {
        let copied: Bool
        switch payload {
        case .section(let sectionID):
            copied = viewModel.copySection(id: sectionID)
        case .clipboardItem(let itemID):
            copied = viewModel.copyItem(id: itemID)
        case .translation:
            copied = viewModel.copyTranslation()
        }
        if copied { toast.flash(at: screenPoint) }
    }

    private func requestClose() {
        onCloseRequested(id)
    }

    private func insertDividerFromToolbar() {
        guard viewModel.card.isManual,
              let section = viewModel.sections.last else { return }
        _ = viewModel.insertDivider(inSectionID: section.id, atGraphemeOffset: section.text.count)
    }

    /// 新建/呼出手动卡片时自动聚焦首个文本框,便于立即输入。
    private func focusFirstTextView() {
        guard let panel else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            guard let content = panel.contentView,
                  let textView = Self.firstTextView(in: content) else { return }
            panel.makeFirstResponder(textView)
        }
    }

    private static func firstTextView(in view: NSView) -> NSTextView? {
        if let textView = view as? NSTextView { return textView }
        for sub in view.subviews {
            if let found = firstTextView(in: sub) { return found }
        }
        return nil
    }

    // MARK: - 设置面板

    private func showSettings() {
        let settings = settingsPanel ?? makeSettingsPanel()
        self.settingsPanel = settings
        if let card = panel {
            settings.setFrameTopLeftPoint(NSPoint(x: card.frame.maxX + 8, y: card.frame.maxY))
        }
        settings.makeKeyAndOrderFront(nil)
    }

    private func makeSettingsPanel() -> NSPanel {
        let host = NSHostingController(rootView: CardSettingsHost(viewModel: viewModel))
        let panel = NSPanel(contentViewController: host)
        panel.styleMask = [.titled, .closable, .utilityWindow]
        panel.title = "卡片设置"
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        return panel
    }

    // MARK: - NSWindowDelegate

    func windowDidMove(_ notification: Notification) {
        guard let panel, notification.object as? NSWindow === panel else { return }
        viewModel.setFrame(panel.frame)
        overlay?.reposition()
    }
}

/// 设置面板内容:观察 viewModel,使内容模式/外观变化即时反映。
private struct CardSettingsHost: View {
    @ObservedObject var viewModel: DesktopCardViewModel

    var body: some View {
        CardSettingsView(
            appearance: viewModel.appearanceBinding,
            contentMode: viewModel.card.contentMode,
            onChangeMode: { viewModel.setMode($0) },
            onReset: { viewModel.resetAppearance() }
        )
    }
}
