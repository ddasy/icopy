import AppKit
import SwiftUI

/// 全应用共享的"已复制"提示。锁定卡片沉在桌面层,其自身 SwiftUI 无法可靠浮出提示,
/// 故用一个点击穿透的悬浮小窗口统一在屏幕坐标处闪现,锁定/解锁两态通用。
@MainActor
final class CopiedToastController {
    private var panel: NSPanel?
    private var dismissTask: Task<Void, Never>?

    func flash(at screenPoint: NSPoint, text: String = "已复制") {
        let panel = ensurePanel()
        let host = NSHostingView(rootView: ToastView(text: text))
        host.layout()
        let size = host.fittingSize
        panel.setContentSize(size)
        panel.contentView = host
        // 在点击点上方居中显示
        panel.setFrameOrigin(NSPoint(x: screenPoint.x - size.width / 2, y: screenPoint.y + 12))
        panel.alphaValue = 0
        panel.orderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            panel.animator().alphaValue = 1
        }

        dismissTask?.cancel()
        dismissTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled else { return }
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.2
                panel.animator().alphaValue = 0
            } completionHandler: {
                Task { @MainActor in panel.orderOut(nil) }
            }
        }
    }

    private func ensurePanel() -> NSPanel {
        if let panel { return panel }
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 80, height: 32),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true // 点击穿透
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
        self.panel = panel
        return panel
    }
}

private struct ToastView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule().fill(Color.black.opacity(0.82))
            )
            .fixedSize()
    }
}
