import AppKit
import ICopyCore
import SwiftUI

/// 手动卡片内容:按 `viewModel.rows` 分组渲染——行内横向并排(竖向分隔占独立间隔列,按 `columnWeight`
/// 分配文本列宽),行间纵向堆叠(横向分隔)。分隔线悬停浮出 ✕ 可删除;竖向分隔另有 ⇔ 按钮可按住左右
/// 拖动调整分隔位置(均仅解锁态)。解锁态每个分区一个
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
                        onResizeColumn: canDelete ? { viewModel.resizeColumn(leftID: $0, rightID: $1, leftWeight: $2) } : nil,
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
    let onResizeColumn: ((StickyCardSection.ID, StickyCardSection.ID, Double) -> Void)?
    @ViewBuilder let cell: (StickyCardSection) -> Cell

    /// 行布局宽度(不含外侧 padding);仅供渲染期计算每单位权重对应像素。
    @State private var rowWidth: CGFloat = 0

    var body: some View {
        let gutterCount = max(sections.count - 1, 0)
        let contentWidth = max(rowWidth - ColumnLayout.gutter * CGFloat(gutterCount), 1)
        let divisor = max(sections.map(\.columnWeight).reduce(0, +), 1)
        let pixelsPerWeight = contentWidth / CGFloat(divisor)

        WeightedHStack {
            ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                cell(section)
                    .layoutValue(key: ColumnWeightKey.self, value: CGFloat(section.columnWeight))
                if section.id != sections.last?.id {
                    let nextID = sections[index + 1].id
                    let rightWeight = sections[index + 1].columnWeight
                    ColumnDividerHandle(
                        leftWeight: section.columnWeight,
                        rightWeight: rightWeight,
                        pixelsPerWeight: pixelsPerWeight,
                        onDelete: onDeleteColumn.map { delete in { delete(nextID) } },
                        onResize: onResizeColumn.map { resize in { newLeftWeight in
                            resize(section.id, nextID, newLeftWeight)
                        }}
                    )
                    .layoutValue(key: ColumnWeightKey.self, value: 0)
                }
            }
        }
        .onGeometryChange(for: CGFloat.self, of: { $0.size.width }, action: { rowWidth = $0 })
        .padding(.horizontal, ColumnLayout.rowInset)
    }
}

/// 列布局常量(分割补偿、间隔列宽度、行外边距共用,保持视图排布与权重切分一致)。
private enum ColumnLayout {
    /// 竖向分隔间隔列宽度(独占,内含居中分隔线 + 两侧留白)。
    static let gutter: CGFloat = 13
    /// 每行左右外边距(文本列之间不再各自加内边距,仅靠间隔列分隔)。
    static let rowInset: CGFloat = 8
    /// 拖动竖向分隔时每列保留的最小像素宽度。
    static let minColumnWidth: CGFloat = 8
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

/// 列间竖向分隔:独占一条固定宽度间隔列,居中画 1pt 线;悬停时浮出 ⇔ 移动按钮(按住左右拖调整分隔位置)
/// 与其下方的 ✕ 按钮(删除该分割)。拖动期间**只动浮层不改模型**:线与按钮随光标用 `.offset` 平移(纯
/// 渲染变换,不触发重排,故无反馈瞬移);松手才把新的左列权重一次性提交给 `onResize`,由其改权重重排。
private struct ColumnDividerHandle: View {
    let leftWeight: Double
    let rightWeight: Double
    let pixelsPerWeight: CGFloat
    let onDelete: (() -> Void)?
    /// 松手提交:参数为新的左列权重;nil 时不显示移动按钮。
    let onResize: ((Double) -> Void)?
    @State private var hovering = false
    @State private var dragging = false
    /// 拖动中浮层相对静止位的横向偏移(pt);仅渲染期使用,不入布局。
    @State private var dragTranslation: CGFloat = 0

    var body: some View {
        ZStack {
            Rectangle()
                .fill(dragging ? Color.accentColor.opacity(0.9) : Color.primary.opacity(0.18))
                .frame(width: 1)
                .offset(x: dragTranslation)
            if hovering || dragging {
                VStack(spacing: 4) {
                    if let onResize {
                        MoveBadge(
                            leftWeight: leftWeight,
                            rightWeight: rightWeight,
                            pixelsPerWeight: pixelsPerWeight,
                            onBegan: {
                                dragging = true
                                dragTranslation = 0
                            },
                            onChanged: { dragTranslation = $0 },
                            onEnded: { newLeftWeight in
                                dragging = false
                                dragTranslation = 0
                                onResize(newLeftWeight)
                            }
                        )
                    }
                    if let onDelete {
                        DeleteBadge(action: onDelete)
                    }
                }
                .offset(x: dragTranslation)
            }
        }
        .frame(width: ColumnLayout.gutter)
        .frame(maxHeight: .infinity)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }
}

/// 分隔线移动按钮:按住左右拖动以调整分隔位置。拖动下沉到 AppKit 把手——SwiftUI DragGesture 的局部
/// 坐标系会随分隔线自身移动而漂移(导致横跳),且纯手势不拦截 `isMovableByWindowBackground` 的窗口拖动。
private struct MoveBadge: View {
    let leftWeight: Double
    let rightWeight: Double
    let pixelsPerWeight: CGFloat
    let onBegan: () -> Void
    let onChanged: (CGFloat) -> Void
    let onEnded: (Double) -> Void

    var body: some View {
        Image(systemName: "arrow.left.and.right.circle.fill")
            .font(.system(size: 12))
            .symbolRenderingMode(.palette)
            .foregroundStyle(Color.white, Color.secondary)
            .overlay(
                HorizontalDragHandle(
                    leftWeight: leftWeight,
                    rightWeight: rightWeight,
                    pixelsPerWeight: pixelsPerWeight,
                    onBegan: onBegan,
                    onChanged: onChanged,
                    onEnded: onEnded
                )
            )
            .help("按住左右拖动,调整分隔位置")
    }
}

/// 透明 AppKit 拖动把手:吃掉鼠标按下(窗口不跟随拖动),以窗口坐标系上报自按下点起的横向位移——
/// 该坐标系不随分隔线移动而漂移,拖动稳定。
private struct HorizontalDragHandle: NSViewRepresentable {
    var leftWeight: Double
    var rightWeight: Double
    var pixelsPerWeight: CGFloat
    var onBegan: () -> Void
    var onChanged: (CGFloat) -> Void
    var onEnded: (Double) -> Void

    func makeNSView(context: Context) -> DragHandleNSView {
        let view = DragHandleNSView()
        view.leftWeight = leftWeight
        view.rightWeight = rightWeight
        view.pixelsPerWeight = pixelsPerWeight
        view.onBegan = onBegan
        view.onChanged = onChanged
        view.onEnded = onEnded
        return view
    }

    func updateNSView(_ view: DragHandleNSView, context: Context) {
        view.leftWeight = leftWeight
        view.rightWeight = rightWeight
        view.pixelsPerWeight = pixelsPerWeight
        view.onBegan = onBegan
        view.onChanged = onChanged
        view.onEnded = onEnded
    }
}

final class DragHandleNSView: NSView {
    var leftWeight: Double = 0
    var rightWeight: Double = 0
    var pixelsPerWeight: CGFloat = 0
    var onBegan: (() -> Void)?
    var onChanged: ((CGFloat) -> Void)?
    var onEnded: ((Double) -> Void)?
    private var startX: CGFloat?
    private var baseLeftWeight: Double = 0
    private var basePixelsPerWeight: CGFloat = 0
    private var dragBounds: ClosedRange<CGFloat> = 0...0

    override var mouseDownCanMoveWindow: Bool { false }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .resizeLeftRight)
    }

    /// 以窗口坐标上报自按下点起的横向位移(该坐标系不随分隔线移动而漂移)。用常规响应链方法而非
    /// `trackEvents` 同步循环:拖动期间只动浮层(`.offset` 渲染变换),本视图不重排、不重定位,故响应链
    /// 投递的 mouseDragged 稳定到达;且每个事件回到 run loop,SwiftUI 才会刷新浮层偏移(嵌套
    /// `.eventTracking` 循环会卡住渲染事务,导致浮层只在松手后才跳一下——表现为按住变蓝却不跟手)。
    override func mouseDown(with event: NSEvent) {
        guard pixelsPerWeight > 0 else { return }
        startX = event.locationInWindow.x
        baseLeftWeight = leftWeight
        basePixelsPerWeight = pixelsPerWeight
        let lo = -(CGFloat(leftWeight) * basePixelsPerWeight - ColumnLayout.minColumnWidth)
        let hi = CGFloat(rightWeight) * basePixelsPerWeight - ColumnLayout.minColumnWidth
        if lo <= hi {
            dragBounds = lo...hi
        } else {
            dragBounds = 0...0
        }
        onBegan?()
    }

    override func mouseDragged(with event: NSEvent) {
        guard let startX else { return }
        onChanged?(clampedTranslation(event.locationInWindow.x - startX))
    }

    override func mouseUp(with event: NSEvent) {
        guard let startX else { return }
        self.startX = nil
        let translation = clampedTranslation(event.locationInWindow.x - startX)
        guard basePixelsPerWeight > 0 else { return }
        onEnded?(baseLeftWeight + Double(translation / basePixelsPerWeight))
    }

    private func clampedTranslation(_ translation: CGFloat) -> CGFloat {
        min(max(translation, dragBounds.lowerBound), dragBounds.upperBound)
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

/// 自适应高度的 NSTextView 包装:编辑中的文本框在选区变化时同源上报焦点与光标(字符偏移 + 横向占比)。
/// SwiftUI 的 TextEditor 无法暴露光标位置,而"在光标处插入分隔符"需要它,故下沉到 AppKit。
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
            guard tv.window?.firstResponder === tv else { return }
            let nsString = tv.string as NSString
            let location = min(tv.selectedRange().location, nsString.length)
            let charOffset = nsString.substring(to: location).count
            parent.onFocus()
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
