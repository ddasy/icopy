import ICopyCore
import AppKit
import SwiftUI

public struct ClipboardItemRow: View {
    private let item: ClipboardItem
    private let solid: Bool
    private let onCopy: () -> Void
    private let onRename: () -> Void
    private let onToggleFavorite: () -> Void
    private let onDelete: () -> Void
    private let onExpansionChange: (Bool) -> Void
    @State private var isHoverReady = false
    @State private var expandTask: Task<Void, Never>?
    @State private var collapseTask: Task<Void, Never>?
    @State private var mouseEventMonitor: Any?
    @State private var isRowHovered = false
    @State private var isPointerInDetailLayer = false
    @State private var isActionHovered = false
    @State private var detailFrameInScreen: CGRect = .null
    @State private var availableTextWidth: CGFloat = 0
    @State private var collapsedTextWidth: CGFloat = 0

    public init(
        item: ClipboardItem,
        solid: Bool = false,
        onCopy: @escaping () -> Void,
        onRename: @escaping () -> Void,
        onToggleFavorite: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onExpansionChange: @escaping (Bool) -> Void = { _ in }
    ) {
        self.item = item
        self.solid = solid
        self.onCopy = onCopy
        self.onRename = onRename
        self.onToggleFavorite = onToggleFavorite
        self.onDelete = onDelete
        self.onExpansionChange = onExpansionChange
    }

    public var body: some View {
        RightClickableRow(action: onRename) {
            rowContent
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .background(rowBackground)
                .overlay(rowBorder)
                .overlay(alignment: .topLeading) {
                    detailLayer
                }
                .shadow(
                    color: .clear,
                    radius: 10,
                    x: 0,
                    y: 6
                )
                .contentShape(Rectangle())
                .onTapGesture(perform: onCopy)
                .onHover { setRowHover($0) }
                .onDisappear {
                    cancelHoverExpansion()
                    onExpansionChange(false)
                }
                .onChange(of: isExpanded) { _, expanded in
                    onExpansionChange(expanded)
                    if expanded {
                        startMouseTracking()
                        refreshDetailHoverState()
                    } else {
                        stopMouseTracking()
                        isPointerInDetailLayer = false
                        detailFrameInScreen = .null
                    }
                }
                .animation(.easeInOut(duration: 0.12), value: isExpanded)
        }
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(
                Color(nsColor: .controlBackgroundColor)
                    .opacity(solid ? 0.2 : 0.34)
            )
    }

    private var rowBorder: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .strokeBorder(
                Color(nsColor: .separatorColor)
                    .opacity(0)
            )
    }

    @ViewBuilder
    private var detailLayer: some View {
        if isExpanded {
            Text(expandedText)
                .font(Self.rowFont)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .background(detailLayerBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color(nsColor: .separatorColor).opacity(0.65))
                )
                .compositingGroup()
                .zIndex(10)
                .shadow(color: Color.black.opacity(solid ? 0.08 : 0.22), radius: 12, x: 0, y: 7)
                .background(
                    WindowFrameReporter { frame in
                        detailFrameInScreen = frame
                        refreshDetailHoverState()
                    }
                )
        }
    }

    private var detailLayerBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor))
        }
    }

    private var rowContent: some View {
        HStack(alignment: .top, spacing: 10) {
            rowText

            actionButtons
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 10) {
            Button(action: onToggleFavorite) {
                Image(systemName: item.isFavorite ? "star.fill" : "star")
            }
            .buttonStyle(.plain)
            .help(item.isFavorite ? "取消收藏" : "加入收藏")

            Button(action: onCopy) {
                Image(systemName: "doc.on.clipboard")
            }
            .buttonStyle(.plain)
            .help("复制")

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
            .help("删除")
        }
        .contentShape(Rectangle())
        .onHover { setActionHover($0) }
    }

    private var rowText: some View {
        Text(collapsedText)
            .lineLimit(1)
            .font(Self.rowFont)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ZStack {
                    WidthSampler(text: collapsedText, font: Self.measurementFont) { width in
                        collapsedTextWidth = width
                    }
                    GeometryReader { proxy in
                        Color.clear
                            .preference(key: AvailableTextWidthKey.self, value: proxy.size.width)
                    }
                }
            )
            .onPreferenceChange(AvailableTextWidthKey.self) { width in
                availableTextWidth = width
            }
            .onChange(of: collapsedText) { _, _ in
                collapsedTextWidth = Self.measuredWidth(for: collapsedText)
            }
            .onAppear {
                collapsedTextWidth = Self.measuredWidth(for: collapsedText)
            }
            .allowsHitTesting(false)
    }

    private var isExpanded: Bool {
        isHoverReady && (item.hasCustomTitle || isCollapsedTextClipped)
    }

    private func setRowHover(_ isHovering: Bool) {
        isRowHovered = isHovering
        syncHoverExpansion()
    }

    private func setActionHover(_ isHovering: Bool) {
        isActionHovered = isHovering
        syncHoverExpansion()
    }

    /// 行与展开层共同决定悬浮状态:展开层会溢出行的边界,只有当鼠标
    /// 既不在行上、也不在展开层上时才收回,避免移入溢出区域被误判为离开。
    private func syncHoverExpansion() {
        let canExpand = canKeepExpanded

        if canExpand {
            collapseTask?.cancel()
            collapseTask = nil
        } else {
            expandTask?.cancel()
            expandTask = nil
            collapseTask?.cancel()
            collapseTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(180))
                refreshDetailHoverState()
                guard !Task.isCancelled, !canKeepExpanded else { return }
                isHoverReady = false
            }
            return
        }

        guard !isHoverReady else { return }

        expandTask?.cancel()
        expandTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled, canKeepExpanded else { return }
            isHoverReady = true
        }
    }

    private func cancelHoverExpansion() {
        expandTask?.cancel()
        expandTask = nil
        collapseTask?.cancel()
        collapseTask = nil
        stopMouseTracking()
        isRowHovered = false
        isPointerInDetailLayer = false
        isActionHovered = false
        detailFrameInScreen = .null
        isHoverReady = false
    }

    private var canKeepExpanded: Bool {
        (isRowHovered || isPointerInDetailLayer) && !isActionHovered
    }

    private func startMouseTracking() {
        guard mouseEventMonitor == nil else { return }
        mouseEventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
        ) { event in
            refreshDetailHoverState()
            return event
        }
    }

    private func stopMouseTracking() {
        guard let mouseEventMonitor else { return }
        NSEvent.removeMonitor(mouseEventMonitor)
        self.mouseEventMonitor = nil
    }

    private func refreshDetailHoverState() {
        let isInside = isMouseInsideDetailLayer
        guard isPointerInDetailLayer != isInside else { return }
        isPointerInDetailLayer = isInside
        syncHoverExpansion()
    }

    private var isMouseInsideDetailLayer: Bool {
        guard !detailFrameInScreen.isNull, !detailFrameInScreen.isEmpty else { return false }
        return detailFrameInScreen
            .insetBy(dx: -2, dy: -2)
            .contains(NSEvent.mouseLocation)
    }

    private var isCollapsedTextClipped: Bool {
        collapsedTextWidth > 0 && availableTextWidth > 0 && collapsedTextWidth > availableTextWidth + 1
    }

    private var collapsedText: String {
        let value = item.displayTitle
        return value.isEmpty ? "空文本" : value
    }

    private var expandedText: String {
        item.content.isEmpty ? "空文本" : item.content
    }

    private static let rowFont = Font.system(size: 13, weight: .medium)
    private static let measurementFont = NSFont.systemFont(ofSize: 13, weight: .medium)

    private static func measuredWidth(for text: String) -> CGFloat {
        (text as NSString).size(withAttributes: [.font: measurementFont]).width
    }
}

private struct AvailableTextWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct WidthSampler: View {
    let text: String
    let font: NSFont
    let onChange: (CGFloat) -> Void

    var body: some View {
        Color.clear
            .onAppear {
                onChange(measuredWidth)
            }
            .onChange(of: text) { _, _ in
                onChange(measuredWidth)
            }
    }

    private var measuredWidth: CGFloat {
        (text as NSString).size(withAttributes: [.font: font]).width
    }
}

private struct WindowFrameReporter: NSViewRepresentable {
    let onChange: (CGRect) -> Void

    func makeNSView(context: Context) -> FrameReportingView {
        FrameReportingView(onChange: onChange)
    }

    func updateNSView(_ nsView: FrameReportingView, context: Context) {
        nsView.onChange = onChange
        nsView.reportSoon()
    }
}

private final class FrameReportingView: NSView {
    var onChange: (CGRect) -> Void

    init(onChange: @escaping (CGRect) -> Void) {
        self.onChange = onChange
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        reportSoon()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        reportSoon()
    }

    override func setFrameOrigin(_ newOrigin: NSPoint) {
        super.setFrameOrigin(newOrigin)
        reportSoon()
    }

    func reportSoon() {
        DispatchQueue.main.async { [weak self] in
            self?.report()
        }
    }

    private func report() {
        guard let window else {
            onChange(.null)
            return
        }
        onChange(window.convertToScreen(convert(bounds, to: nil)))
    }
}

private struct RightClickableRow<Content: View>: NSViewRepresentable {
    let action: () -> Void
    let content: Content

    init(action: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.action = action
        self.content = content()
    }

    func makeNSView(context: Context) -> RightClickableHostingView<Content> {
        RightClickableHostingView(rootView: content, action: action)
    }

    func updateNSView(_ nsView: RightClickableHostingView<Content>, context: Context) {
        nsView.action = action
        nsView.rootView = content
    }
}

private final class RightClickableHostingView<Content: View>: NSHostingView<Content> {
    var action: () -> Void

    init(rootView: Content, action: @escaping () -> Void) {
        self.action = action
        super.init(rootView: rootView)
    }

    required init(rootView: Content) {
        self.action = {}
        super.init(rootView: rootView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func rightMouseDown(with event: NSEvent) {
        action()
    }
}
