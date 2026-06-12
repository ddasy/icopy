import AppKit
import SwiftUI

/// 翻译卡片原文输入:NSTextView 本地持有文本(SwiftUI 只提供初值,绝不回写),
/// 仅在非 IME 组合态提交文本;组合(标记文本)期间跳过提交与一切属性写入,绝不打断输入法。
struct TranslationSourceTextView: NSViewRepresentable {
    let initialText: String
    var font: NSFont
    var textColor: NSColor
    var onCommit: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> AutoGrowingTextView {
        let tv = AutoGrowingTextView()
        tv.delegate = context.coordinator
        tv.isRichText = false
        tv.isEditable = true
        tv.isSelectable = true
        tv.drawsBackground = false
        tv.allowsUndo = true
        tv.font = font
        tv.textColor = textColor
        tv.string = initialText
        tv.textContainerInset = NSSize(width: 0, height: 2)
        tv.isVerticallyResizable = false
        tv.isHorizontallyResizable = false
        tv.textContainer?.widthTracksTextView = true
        tv.textContainer?.lineFragmentPadding = 0
        return tv
    }

    func updateNSView(_ tv: AutoGrowingTextView, context: Context) {
        context.coordinator.parent = self
        guard !tv.hasMarkedText() else { return }
        if tv.font != font { tv.font = font }
        if tv.textColor != textColor { tv.textColor = textColor }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: TranslationSourceTextView

        init(_ parent: TranslationSourceTextView) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView, !tv.hasMarkedText() else { return }
            parent.onCommit(tv.string)
        }
    }
}
