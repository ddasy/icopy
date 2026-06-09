import AppKit
import DesktopCard
import SwiftUI

/// 单卡片的锁定态覆盖子系统:卡片沉入桌面层后收不到任何鼠标事件(Finder 桌面窗口拦截),
/// 本控制器用一组独立可点击层窗口把交互还给用户——快捷条(解锁/设置/关闭)、每个可复制
/// 区域的单击复制热区、以及滚轮转发。
///
/// 与 FeedBar 的关键差异:FeedBar 假设只有一张常驻卡片,事件监视器从不移除;本应用多卡片
/// 反复增删,故所有 NSEvent 监视器 token 都被保存,并在 `teardown()` 移除,杜绝监视器泄漏/误派发。
@MainActor
final class LockOverlayController {
    private let panel: DesktopCardPanel
    private let onUnlock: () -> Void
    private let onOpenSettings: () -> Void
    private let onClose: () -> Void
    /// 单击某复制区域时回调(payload + 屏幕点,后者用于在点击处弹"已复制")。
    private let onCopy: (CardCopyableRegion.Payload, NSPoint) -> Void
    private let scrollForwardingEnabled: Bool

    private var stripPanel: DesktopCardPanel?
    private var copyZonePanels: [DesktopCardPanel] = []
    private var regions: [CardCopyableRegion] = []
    private var isLocked = false
    private var copyZoneMonitorInstalled = false

    private var monitorTokens: [Any] = []

    private let stripSize = NSSize(width: 96, height: 32)

    init(
        panel: DesktopCardPanel,
        onUnlock: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void,
        onClose: @escaping () -> Void,
        onCopy: @escaping (CardCopyableRegion.Payload, NSPoint) -> Void,
        scrollForwardingEnabled: Bool
    ) {
        self.panel = panel
        self.onUnlock = onUnlock
        self.onOpenSettings = onOpenSettings
        self.onClose = onClose
        self.onCopy = onCopy
        self.scrollForwardingEnabled = scrollForwardingEnabled
        if scrollForwardingEnabled { installLockedScrollForwarding() }
    }

    // MARK: - 对外入口

    func setLocked(_ locked: Bool) {
        isLocked = locked
        if locked {
            showOverlays()
        } else {
            hideOverlays()
        }
    }

    func updateRegions(_ regions: [CardCopyableRegion]) {
        self.regions = regions
        if isLocked { layoutCopyZones() }
    }

    /// 卡片被移动/缩放后重摆覆盖窗口。
    func reposition() {
        guard isLocked else { return }
        if let strip = stripPanel { positionStrip(strip) }
        layoutCopyZones()
    }

    func teardown() {
        for token in monitorTokens { NSEvent.removeMonitor(token) }
        monitorTokens.removeAll()
        copyZoneMonitorInstalled = false
        stripPanel?.orderOut(nil)
        copyZonePanels.forEach { $0.orderOut(nil) }
        stripPanel = nil
        copyZonePanels.removeAll()
    }

    // MARK: - 覆盖窗口

    private func showOverlays() {
        let strip = ensureStripPanel()
        positionStrip(strip)
        guard panel.isVisible else { return }
        strip.orderFront(nil)
        layoutCopyZones()
    }

    private func hideOverlays() {
        stripPanel?.orderOut(nil)
        copyZonePanels.forEach { $0.orderOut(nil) }
    }

    /// 锁定可点击层窗口的公共配置。必须用 DesktopCardPanel:无边框普通 NSPanel 不能成为 key window。
    private func makeOverlayPanel(size: NSSize) -> DesktopCardPanel {
        let overlay = DesktopCardPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        overlay.isResizingEnabled = false
        overlay.isFloatingPanel = false
        overlay.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)))
        overlay.backgroundColor = .clear
        overlay.isOpaque = false
        overlay.hasShadow = false
        overlay.isMovable = false
        overlay.hidesOnDeactivate = false
        overlay.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
        return overlay
    }

    // MARK: - 快捷条(解锁 / 设置 / 关闭)

    private func ensureStripPanel() -> DesktopCardPanel {
        if let stripPanel { return stripPanel }
        let strip = makeOverlayPanel(size: stripSize)
        strip.contentView = FirstMouseHostingView(rootView: LockControlStripView())
        // 同 FeedBar:此类面板上 SwiftUI Button 手势不可靠,改用事件监视器按 x 区间手动分派。
        let token = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseUp]) { [weak self, weak strip] event in
            guard let self, let strip, event.window === strip else { return event }
            self.handleStripClick(at: event.locationInWindow)
            return event
        }
        if let token { monitorTokens.append(token) }
        stripPanel = strip
        return strip
    }

    /// 96pt 宽,3 个图标,中心约在 x = 24 / 48 / 72(解锁/设置/关闭),边界取中点。
    private func handleStripClick(at point: NSPoint) {
        guard point.y >= 2, point.y <= stripSize.height - 2 else { return }
        switch point.x {
        case ..<36: onUnlock()
        case ..<60: onOpenSettings()
        default: onClose()
        }
    }

    /// 快捷条置于卡片右上角内侧(对齐解锁态 header 按钮组的大致位置)。
    private func positionStrip(_ strip: NSPanel) {
        let card = panel.frame
        strip.setFrameOrigin(NSPoint(
            x: card.maxX - stripSize.width - 14,
            y: card.maxY - stripSize.height - 14
        ))
    }

    // MARK: - 复制热区

    /// 把每个可复制区域(窗口内 .global 坐标,左上原点)转屏幕坐标,裁剪到卡片范围,
    /// 用透明窗口池覆盖。单击某热区 → 查 payload → onCopy。
    private func layoutCopyZones() {
        guard isLocked, panel.isVisible else {
            copyZonePanels.forEach { $0.orderOut(nil) }
            return
        }
        let card = panel.frame
        let rects: [NSRect] = regions.map { region in
            NSRect(
                x: card.minX + region.frame.minX,
                y: card.maxY - region.frame.maxY,
                width: region.frame.width,
                height: region.frame.height
            )
        }

        installCopyZoneMonitorIfNeeded()

        while copyZonePanels.count < rects.count {
            let zone = makeOverlayPanel(size: NSSize(width: 10, height: 10))
            zone.contentView = FirstMouseHostingView(rootView: CopyZoneProxyView())
            copyZonePanels.append(zone)
        }
        for (index, zonePanel) in copyZonePanels.enumerated() {
            if index < rects.count {
                // display: true —— 尺寸变化后必须立即重绘近透明层铺满新区域,
                // 否则未绘制部分被 Window Server 视为全透明而点击穿透。
                zonePanel.setFrame(rects[index], display: true)
                zonePanel.orderFront(nil)
            } else {
                zonePanel.orderOut(nil)
            }
        }
    }

    private func installCopyZoneMonitorIfNeeded() {
        guard !copyZoneMonitorInstalled else { return }
        copyZoneMonitorInstalled = true
        let token = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] event in
            guard let self else { return event }
            guard let index = self.copyZonePanels.firstIndex(where: { $0 === event.window }),
                  index < self.regions.count else { return event }
            self.onCopy(self.regions[index].payload, NSEvent.mouseLocation)
            return event
        }
        if let token { monitorTokens.append(token) }
    }

    // MARK: - 滚动转发(剪贴板列表卡片需要)

    private func installLockedScrollForwarding() {
        let global = NSEvent.addGlobalMonitorForEvents(matching: [.scrollWheel]) { [weak self] event in
            self?.forwardLockedScroll(event, fromOwnWindow: false)
        }
        if let global { monitorTokens.append(global) }

        let local = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel]) { [weak self] event in
            self?.forwardLockedScroll(event, fromOwnWindow: true)
            return event
        }
        if let local { monitorTokens.append(local) }
    }

    private func forwardLockedScroll(_ event: NSEvent, fromOwnWindow: Bool) {
        guard isLocked, panel.isVisible else { return }
        if fromOwnWindow {
            guard isOwnOverlayWindow(event.window) else { return }
        }
        let screenPoint = NSEvent.mouseLocation
        guard panel.frame.contains(screenPoint) else { return }
        let pointInWindow = panel.convertPoint(fromScreen: screenPoint)
        guard let scrollView = scrollView(at: pointInWindow) else { return }
        applyScroll(event, to: scrollView)
    }

    private func isOwnOverlayWindow(_ window: NSWindow?) -> Bool {
        guard let window else { return false }
        return window === stripPanel || copyZonePanels.contains { $0 === window }
    }

    private func scrollView(at pointInWindow: NSPoint) -> NSScrollView? {
        guard let root = panel.contentView else { return nil }
        var found: NSScrollView?
        func walk(_ view: NSView) {
            for sub in view.subviews {
                if let sv = sub as? NSScrollView,
                   sv.convert(sv.bounds, to: nil).contains(pointInWindow) {
                    found = sv
                }
                walk(sub)
            }
        }
        walk(root)
        return found
    }

    private func applyScroll(_ event: NSEvent, to scrollView: NSScrollView) {
        guard let doc = scrollView.documentView else { return }
        let dy = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY : event.scrollingDeltaY * 17
        guard dy != 0 else { return }
        let clip = scrollView.contentView
        var origin = clip.bounds.origin
        origin.y -= dy
        origin.y = min(max(0, origin.y), max(0, doc.frame.height - clip.bounds.height))
        clip.setBoundsOrigin(origin)
        scrollView.reflectScrolledClipView(clip)
    }
}

/// 锁定快捷条内容:解锁 / 设置 / 关闭(点击分派在控制器,不依赖这些 Button 的手势)。
private struct LockControlStripView: View {
    var body: some View {
        HStack(spacing: 8) {
            icon("lock.open")
            icon("gearshape")
            icon("xmark")
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Capsule().fill(.ultraThinMaterial)
        )
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.16)))
    }

    private func icon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(width: 16, height: 16)
    }
}

/// 复制热区填充层:近透明形状层防点击穿透(空内容会被 Window Server 当透明而穿透)。
private struct CopyZoneProxyView: View {
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.001))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
    }
}
