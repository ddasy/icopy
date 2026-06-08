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
        }
    }

    private var rowContent: some View {
        HStack(spacing: 10) {
            Text(item.displayTitle.isEmpty ? "空文本" : item.displayTitle)
                .lineLimit(1)
                .font(.system(size: 13, weight: .medium))

            Spacer(minLength: 8)

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
