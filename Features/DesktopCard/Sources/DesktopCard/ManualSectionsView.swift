import AppKit
import ICopyCore
import SwiftUI

/// 手动卡片内容:解锁态每个分区一个可编辑文本框(上报焦点+光标,供"分割"按钮在光标处插入分隔符);
/// 锁定态每个分区渲染为只读文本并上报可复制区域(单击复制由覆盖层完成)。
struct ManualSectionsView: View {
    @ObservedObject var viewModel: DesktopCardViewModel
    let appearance: StickyCardAppearance
    @Binding var focusedSectionID: StickyCardSection.ID?
    @Binding var caretCharOffset: Int

    var body: some View {
        if viewModel.card.isLocked {
            lockedSections
        } else {
            editableSections
        }
    }

    private var editableSections: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(viewModel.sections) { section in
                    SectionTextView(
                        text: Binding(
                            get: { section.text },
                            set: { viewModel.setText($0, sectionID: section.id) }
                        ),
                        font: nsFont,
                        textColor: nsTextColor,
                        onFocus: { focusedSectionID = section.id },
                        onCaret: { caretCharOffset = $0 }
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)

                    if section.id != viewModel.sections.last?.id {
                        Divider().opacity(0.45).padding(.horizontal, 8)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .scrollContentBackground(.hidden)
    }

    private var lockedSections: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(viewModel.sections) { section in
                    Text(section.isEmpty ? " " : section.text)
                        .font(appearance.swiftUIFont)
                        .foregroundStyle(appearance.swiftUITextColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                        .reportCopyRegion(.section(section.id))

                    if section.id != viewModel.sections.last?.id {
                        Divider().opacity(0.45).padding(.horizontal, 8)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .scrollContentBackground(.hidden)
    }

    private var nsFont: NSFont {
        let weight: NSFont.Weight
        switch appearance.fontWeight {
        case .regular: weight = .regular
        case .medium: weight = .medium
        case .semibold: weight = .semibold
        case .bold: weight = .bold
        }
        if let family = appearance.fontFamily, !family.isEmpty,
           let f = NSFont(name: family, size: appearance.fontSize) {
            return f
        }
        return NSFont.systemFont(ofSize: appearance.fontSize, weight: weight)
    }

    private var nsTextColor: NSColor {
        let c = appearance.textColor
        return NSColor(srgbRed: c.red, green: c.green, blue: c.blue, alpha: c.alpha * appearance.textIntensity)
    }
}

/// 自适应高度、可上报焦点与光标(字符偏移)的 NSTextView 包装。SwiftUI 的 TextEditor
/// 无法暴露光标位置,而"在光标处插入分隔符"需要它,故下沉到 AppKit。
struct SectionTextView: NSViewRepresentable {
    @Binding var text: String
    var font: NSFont
    var textColor: NSColor
    var onFocus: () -> Void
    var onCaret: (Int) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> AutoGrowingTextView {
        let tv = AutoGrowingTextView()
        tv.delegate = context.coordinator
        tv.onFocus = onFocus
        tv.isRichText = false
        tv.isEditable = true
        tv.isSelectable = true
        tv.drawsBackground = false
        tv.allowsUndo = true
        tv.font = font
        tv.textColor = textColor
        tv.string = text
        tv.textContainerInset = NSSize(width: 0, height: 2)
        tv.isVerticallyResizable = false
        tv.isHorizontallyResizable = false
        tv.textContainer?.widthTracksTextView = true
        tv.textContainer?.lineFragmentPadding = 0
        return tv
    }

    func updateNSView(_ tv: AutoGrowingTextView, context: Context) {
        context.coordinator.parent = self
        if tv.string != text { tv.string = text }
        tv.font = font
        tv.textColor = textColor
        tv.invalidateIntrinsicContentSize()
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: SectionTextView

        init(_ parent: SectionTextView) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            parent.text = tv.string
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            let nsString = tv.string as NSString
            let location = min(tv.selectedRange().location, nsString.length)
            let charOffset = nsString.substring(to: location).count
            parent.onCaret(charOffset)
        }
    }
}

final class AutoGrowingTextView: NSTextView {
    var onFocus: (() -> Void)?

    override var intrinsicContentSize: NSSize {
        guard let layoutManager, let textContainer else { return super.intrinsicContentSize }
        layoutManager.ensureLayout(for: textContainer)
        let height = layoutManager.usedRect(for: textContainer).height + textContainerInset.height * 2
        let minHeight = (font?.pointSize ?? 14) + 10
        return NSSize(width: NSView.noIntrinsicMetric, height: max(height, minHeight))
    }

    override func didChangeText() {
        super.didChangeText()
        invalidateIntrinsicContentSize()
    }

    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if result { onFocus?() }
        return result
    }
}
