import AppKit
import SwiftUI

/// 无边框面板:可成为 key window(按钮/文本编辑正常响应),自带边缘拖拽缩放
/// (borderless 窗口无系统缩放手柄)。多卡片版本:用 `onFrameCommitted` 按卡片回传几何,
/// 不再用 setFrameAutosaveName(多窗口会冲突),并在 teardown 时移除事件监视器(防泄漏)。
final class DesktopCardPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    var isResizingEnabled = true
    /// 缩放结束时回传新 frame(由窗口控制器持久化)。
    var onFrameCommitted: ((NSRect) -> Void)?

    struct ResizeEdges: OptionSet {
        let rawValue: Int
        static let left = ResizeEdges(rawValue: 1)
        static let right = ResizeEdges(rawValue: 2)
        static let top = ResizeEdges(rawValue: 4)
        static let bottom = ResizeEdges(rawValue: 8)
    }

    private let edgeBand: CGFloat = 18
    private let cornerLength: CGFloat = 36
    private let minCardSize = NSSize(width: 180, height: 140)

    private var activeEdges: ResizeEdges = []
    private var dragOrigin: NSPoint = .zero
    private var originalFrame: NSRect = .zero
    private var eventMonitor: Any?

    func installResizeHandling() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]
        ) { [weak self] event in
            self?.handleResizeEvent(event) ?? event
        }
    }

    /// 移除本面板安装的事件监视器(多卡片反复增删时防止监视器累积、误派发)。
    func teardownResizeHandling() {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
    }

    func edges(at pointInWindow: NSPoint) -> ResizeEdges {
        guard isResizingEnabled else { return [] }
        var result: ResizeEdges = []
        if pointInWindow.x <= edgeBand { result.insert(.left) }
        if pointInWindow.x >= frame.width - edgeBand { result.insert(.right) }
        if pointInWindow.y <= edgeBand { result.insert(.bottom) }
        if pointInWindow.y >= frame.height - edgeBand { result.insert(.top) }
        guard !result.isEmpty else { return [] }
        if !result.isDisjoint(with: [.top, .bottom]) {
            if pointInWindow.x <= cornerLength { result.insert(.left) }
            if pointInWindow.x >= frame.width - cornerLength { result.insert(.right) }
        }
        if !result.isDisjoint(with: [.left, .right]) {
            if pointInWindow.y <= cornerLength { result.insert(.bottom) }
            if pointInWindow.y >= frame.height - cornerLength { result.insert(.top) }
        }
        return result
    }

    func updateResizeCursor(at pointInWindow: NSPoint) {
        guard activeEdges.isEmpty else { return }
        (cursor(for: edges(at: pointInWindow)) ?? .arrow).set()
    }

    private func cursor(for edges: ResizeEdges) -> NSCursor? {
        switch edges {
        case [.left], [.right]: return .resizeLeftRight
        case [.top], [.bottom]: return .resizeUpDown
        case [.top, .left]: return .frameResize(position: .topLeft, directions: .all)
        case [.top, .right]: return .frameResize(position: .topRight, directions: .all)
        case [.bottom, .left]: return .frameResize(position: .bottomLeft, directions: .all)
        case [.bottom, .right]: return .frameResize(position: .bottomRight, directions: .all)
        default: return nil
        }
    }

    private func handleResizeEvent(_ event: NSEvent) -> NSEvent? {
        guard event.window === self else { return event }
        switch event.type {
        case .leftMouseDown:
            let hit = edges(at: event.locationInWindow)
            guard !hit.isEmpty else { return event }
            activeEdges = hit
            dragOrigin = NSEvent.mouseLocation
            originalFrame = frame
            return nil
        case .leftMouseDragged:
            guard !activeEdges.isEmpty else { return event }
            applyResize(to: NSEvent.mouseLocation)
            cursor(for: activeEdges)?.set()
            return nil
        case .leftMouseUp:
            guard !activeEdges.isEmpty else { return event }
            activeEdges = []
            onFrameCommitted?(frame)
            return nil
        default:
            return event
        }
    }

    private func applyResize(to mouse: NSPoint) {
        let dx = mouse.x - dragOrigin.x
        let dy = mouse.y - dragOrigin.y
        var f = originalFrame
        if activeEdges.contains(.right) {
            f.size.width = max(minCardSize.width, originalFrame.width + dx)
        }
        if activeEdges.contains(.left) {
            let newWidth = max(minCardSize.width, originalFrame.width - dx)
            f.origin.x = originalFrame.maxX - newWidth
            f.size.width = newWidth
        }
        if activeEdges.contains(.top) {
            f.size.height = max(minCardSize.height, originalFrame.height + dy)
        }
        if activeEdges.contains(.bottom) {
            let newHeight = max(minCardSize.height, originalFrame.height - dy)
            f.origin.y = originalFrame.maxY - newHeight
            f.size.height = newHeight
        }
        setFrame(f, display: true)
    }
}

/// 让第一次点击直接生效(无需先点一下激活窗口);并把鼠标移动转发给面板用于边缘光标提示。
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    private var edgeTrackingArea: NSTrackingArea?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let area = edgeTrackingArea { removeTrackingArea(area) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        edgeTrackingArea = area
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        (window as? DesktopCardPanel)?.updateResizeCursor(at: event.locationInWindow)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        NSCursor.arrow.set()
    }
}
