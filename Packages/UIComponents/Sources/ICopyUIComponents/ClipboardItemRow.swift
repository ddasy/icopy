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
    @State private var isHovering = false
    @State private var availableTextWidth: CGFloat = 0
    @State private var collapsedTextWidth: CGFloat = 0

    public init(
        item: ClipboardItem,
        solid: Bool = false,
        onCopy: @escaping () -> Void,
        onRename: @escaping () -> Void,
        onToggleFavorite: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.item = item
        self.solid = solid
        self.onCopy = onCopy
        self.onRename = onRename
        self.onToggleFavorite = onToggleFavorite
        self.onDelete = onDelete
    }

    public var body: some View {
        RightClickableRow(action: onRename) {
            rowContent
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .contentShape(Rectangle())
                .onTapGesture(perform: onCopy)
                .onHover { isHovering = $0 }
                .animation(.easeInOut(duration: 0.12), value: isExpanded)
        }
    }

    private var rowContent: some View {
        HStack(alignment: .top, spacing: 10) {
            rowText

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
    }

    private var rowText: some View {
        Text(isExpanded ? expandedText : collapsedText)
            .lineLimit(isExpanded ? nil : 1)
            .fixedSize(horizontal: false, vertical: isExpanded)
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
        isHovering && (item.hasCustomTitle || isCollapsedTextClipped)
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
