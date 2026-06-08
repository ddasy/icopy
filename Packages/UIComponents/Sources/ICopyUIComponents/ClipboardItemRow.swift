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
        let secondary = solid ? AnyShapeStyle(Color(nsColor: .labelColor).opacity(0.74)) : AnyShapeStyle(.secondary)

        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.displayTitle.isEmpty ? "空文本" : item.displayTitle)
                    .lineLimit(1)
                    .font(.system(size: 13, weight: .medium))
                Text(item.lastCopiedAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(secondary)
            }

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
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .contentShape(Rectangle())
        .onTapGesture(perform: onCopy)
        .background(RightClickActionView(action: onRename))
    }
}

private struct RightClickActionView: NSViewRepresentable {
    let action: () -> Void

    func makeNSView(context: Context) -> RightClickView {
        RightClickView(action: action)
    }

    func updateNSView(_ nsView: RightClickView, context: Context) {
        nsView.action = action
    }
}

private final class RightClickView: NSView {
    var action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func rightMouseDown(with event: NSEvent) {
        action()
    }
}
