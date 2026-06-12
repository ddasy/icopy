import AppKit
import ICopyCore
import SwiftUI

/// 手动卡片内容:按 `viewModel.rows` 分组渲染——行内横向并排(竖向分隔占独立间隔列,按 `columnWeight`
/// 分配文本列宽),行间纵向堆叠(横向分隔)。分隔线悬停浮出 ✕ 可删除(仅解锁态)。解锁态每个分区一个
/// 可编辑文本框(上报焦点+光标+光标横向占比);锁定态每个分区渲染为只读文本并上报可复制区域。
struct ManualSectionsView: View {
    @ObservedObject var viewModel: DesktopCardViewModel
    let appearance: StickyCardAppearance
    let onCopied: () -> Void
    @Binding var focusedSectionID: StickyCardSection.ID?
    @Binding var caretCharOffset: Int
    @Binding var caretXFraction: Double

    var body: some View {
        if viewModel.card.isLocked {
            sectionsScroll(canDelete: false) { section in
                Text(section.isEmpty ? " " : section.text)
                    .font(appearance.swiftUIFont)
                    .foregroundStyle(appearance.swiftUITextColor)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                    .reportCopyRegion(.section(section.id))
                    .onTapGesture {
                        guard viewModel.card.isLocked else { return }
                        if viewModel.copySection(id: section.id) { onCopied() }
                    }
            }
        } else {
            sectionsScroll(canDelete: true) { section in
                SectionTextView(
                    text: Binding(
                        get: { section.text },
                        set: { viewModel.setText($0, sectionID: section.id) }
                    ),
                    font: nsFont,
                    textColor: nsTextColor,
                    onFocus: { focusedSectionID = section.id },
                    onCaret: { offset, fraction in
                        caretCharOffset = offset
                        caretXFraction = fraction
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.vertical, 6)
            }
        }
    }

    /// 纵向堆叠各行,行间插入可删除的横向分隔;每行交给 `WeightedRow` 排列其列。
    private func sectionsScroll<Cell: View>(
        canDelete: Bool,
        @ViewBuilder cell: @escaping (StickyCardSection) -> Cell
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                let grouped = viewModel.rows
                ForEach(Array(grouped.enumerated()), id: \.offset) { rowIndex, rowSections in
                    WeightedRow(
                        sections: rowSections,
                        onDeleteColumn: canDelete ? { viewModel.deleteSection(id: $0) } : nil,
                        cell: cell
                    )
                    if rowIndex != grouped.count - 1 {
                        RowDividerHandle(onDelete: deleteRowHandler(canDelete: canDelete, firstOfNextRow: grouped[rowIndex + 1].first?.id))
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .scrollContentBackground(.hidden)
    }

    private func deleteRowHandler(canDelete: Bool, firstOfNextRow: StickyCardSection.ID?) -> (() -> Void)? {
        guard canDelete, let id = firstOfNextRow else { return nil }
        return { viewModel.deleteRow(startingAtSectionID: id) }
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

/// 单行:文本列按 `columnWeight` 比例分配宽度,列与列之间插入固定宽度的竖向分隔间隔列(分隔线独占,
/// 不再压在文字上);行高取最高列,各列填满行高使分隔线贯通整行。
private struct WeightedRow<Cell: View>: View {
    let sections: [StickyCardSection]
    let onDeleteColumn: ((StickyCardSection.ID) -> Void)?
    @ViewBuilder let cell: (StickyCardSection) -> Cell

    var body: some View {
        WeightedHStack {
            ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                cell(section)
                    .layoutValue(key: ColumnWeightKey.self, value: CGFloat(section.columnWeight))
                if section.id != sections.last?.id {
                    let nextID = sections[index + 1].id
                    ColumnDividerHandle(onDelete: onDeleteColumn.map { delete in { delete(nextID) } })
                        .layoutValue(key: ColumnWeightKey.self, value: 0)
                }
            }
        }
        .padding(.horizontal, ColumnLayout.rowInset)
    }
}

/// 列布局常量(分割补偿、间隔列宽度、行外边距共用,保持视图排布与权重切分一致)。
private enum ColumnLayout {
    /// 竖向分隔间隔列宽度(独占,内含居中分隔线 + 两侧留白)。
    static let gutter: CGFloat = 13
    /// 每行左右外边距(文本列之间不再各自加内边距,仅靠间隔列分隔)。
    static let rowInset: CGFloat = 8
    /// 切分时左列宽度的安全余量,保证光标前文本不被挤换行。
    static let splitSafetyMargin: CGFloat = 3
}

/// 按子视图 `ColumnWeightKey` 横向分配宽度:权重 ≤ 0 的子视图(分隔间隔列)取其固定理想宽度;文本列
/// 按"绝对占比"分宽——列宽 = 文本区宽 × 权重(权重和 ≤ 1,不归一化),故删列后其余列保持宽度、整体左移
/// 补位,右侧留空;仅当权重和 > 1 时才归一化防溢出。行高取诸列在各自宽度下的最大高度。
private struct WeightedHStack: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let widths = columnWidths(totalWidth: proposal.width ?? 0, subviews: subviews)
        var height: CGFloat = 0
        for (sub, w) in zip(subviews, widths) {
            height = max(height, sub.sizeThatFits(ProposedViewSize(width: w, height: nil)).height)
        }
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let widths = columnWidths(totalWidth: bounds.width, subviews: subviews)
        var x = bounds.minX
        for (sub, w) in zip(subviews, widths) {
            sub.place(
                at: CGPoint(x: x, y: bounds.minY),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: w, height: bounds.height)
            )
            x += w
        }
    }

    private func columnWidths(totalWidth: CGFloat, subviews: Subviews) -> [CGFloat] {
        let weights = subviews.map { $0[ColumnWeightKey.self] }
        var fixed = [CGFloat](repeating: 0, count: subviews.count)
        var fixedTotal: CGFloat = 0
        for index in subviews.indices where weights[index] <= 0 {
            let w = subviews[index].sizeThatFits(.unspecified).width
            fixed[index] = w
            fixedTotal += w
        }
        let content = max(totalWidth - fixedTotal, 0)
        let weightSum = weights.filter { $0 > 0 }.reduce(0, +)
        // 绝对占比:权重和 ≤ 1 按原占比(删列后右侧列左移补位,右侧留空);> 1 才归一化防溢出。
        let divisor = max(weightSum, 1)
        return subviews.indices.map { index in
            weights[index] <= 0 ? fixed[index] : content * weights[index] / divisor
        }
    }
}

private struct ColumnWeightKey: LayoutValueKey {
    static let defaultValue: CGFloat = 1
}

/// 列间竖向分隔:独占一条固定宽度间隔列,居中画 1pt 线;悬停时浮出 ✕ 按钮删除该分割(合并相邻两列)。
private struct ColumnDividerHandle: View {
    let onDelete: (() -> Void)?
    @State private var hovering = false

    var body: some View {
        ZStack {
            Rectangle().fill(Color.primary.opacity(0.18)).frame(width: 1)
            if hovering, let onDelete {
                DeleteBadge(action: onDelete)
            }
        }
        .frame(width: ColumnLayout.gutter)
        .frame(maxHeight: .infinity)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }
}

/// 行间横向分隔:1pt 线;悬停时浮出 ✕ 按钮删除该分割(把下一行并入上一行)。
private struct RowDividerHandle: View {
    let onDelete: (() -> Void)?
    @State private var hovering = false

    var body: some View {
        ZStack {
            Rectangle().fill(Color.primary.opacity(0.18)).frame(height: 1)
            if hovering, let onDelete {
                DeleteBadge(action: onDelete)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 13)
        .contentShape(Rectangle())
        .padding(.horizontal, 8)
        .onHover { hovering = $0 }
    }
}

/// 分隔线悬停删除按钮。
private struct DeleteBadge: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 12))
                .symbolRenderingMode(.palette)
                .foregroundStyle(Color.white, Color.secondary)
        }
        .buttonStyle(.plain)
        .help("删除该分隔")
    }
}

/// 自适应高度、可上报焦点与光标(字符偏移 + 横向占比)的 NSTextView 包装。SwiftUI 的 TextEditor
/// 无法暴露光标位置,而"在光标处插入分隔符"需要它,故下沉到 AppKit。
struct SectionTextView: NSViewRepresentable {
    @Binding var text: String
    var font: NSFont
    var textColor: NSColor
    var onFocus: () -> Void
    var onCaret: (Int, Double) -> Void

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

    /// 按列宽测高:文本随列变窄而换行,行高据此增长,横向分隔线才会下移而非被压在下层之上。
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: AutoGrowingTextView, context: Context) -> CGSize? {
        guard let width = proposal.width, width.isFinite, width > 0 else { return nil }
        return CGSize(width: width, height: nsView.measuredHeight(forWidth: width))
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
            parent.onCaret(charOffset, Self.caretXFraction(in: tv, at: location))
        }

        /// 竖向分割时给模型的左列宽度占比(0…1)。取光标前一字形右缘 x 作为左列目标宽度,并补偿切分新增的
        /// 间隔列(`gutter`)与安全余量:分母用"列宽 − gutter"(切分后两列实际可分配的宽度),使左列恰好容下
        /// 光标前文本、分隔线落在光标处而不把该段文字挤换行。
        @MainActor
        static func caretXFraction(in tv: NSTextView, at location: Int) -> Double {
            guard let layoutManager = tv.layoutManager, let container = tv.textContainer else { return 0.5 }
            let width = max(tv.bounds.width - tv.textContainerInset.width * 2, 1)
            let caretX: CGFloat
            if location <= 0 {
                caretX = 0
            } else {
                let glyph = layoutManager.glyphIndexForCharacter(at: location - 1)
                caretX = layoutManager.boundingRect(forGlyphRange: NSRange(location: glyph, length: 1), in: container).maxX
            }
            let usable = max(width - ColumnLayout.gutter, 1)
            return Double(min(max((caretX + ColumnLayout.splitSafetyMargin) / usable, 0), 1))
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

    /// 给定可用宽度下的换行高度(side-effect free,供 SwiftUI 的 sizeThatFits 在列变窄时取得正确行高)。
    func measuredHeight(forWidth width: CGFloat) -> CGFloat {
        let usable = max(width - textContainerInset.width * 2, 1)
        let content = string.isEmpty ? " " : string
        let attributes: [NSAttributedString.Key: Any] = [.font: font ?? NSFont.systemFont(ofSize: 14)]
        let bounding = (content as NSString).boundingRect(
            with: NSSize(width: usable, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes
        )
        let minHeight = (font?.pointSize ?? 14) + 10
        return max(ceil(bounding.height) + textContainerInset.height * 2 + 2, minHeight)
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
