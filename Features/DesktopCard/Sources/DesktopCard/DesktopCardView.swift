import ICopyCore
import SwiftUI

/// 单张桌面卡片的顶层视图(编排:头部工具栏 + 内容)。解锁态显示头部按钮(锁定/分割/设置/关闭);
/// 锁定态隐藏头部(卡片嵌入桌面不可交互,这些操作由 App 层覆盖层控制条提供),内容上报可复制区域。
public struct DesktopCardView: View {
    @StateObject private var viewModel: DesktopCardViewModel
    private let onOpenSettings: () -> Void
    private let onClose: () -> Void
    private let onRegionsChanged: ([CardCopyableRegion]) -> Void
    private let onCopied: () -> Void

    @State private var focusedSectionID: StickyCardSection.ID?
    @State private var caretCharOffset: Int = 0

    public init(
        viewModel: DesktopCardViewModel,
        onOpenSettings: @escaping () -> Void = {},
        onClose: @escaping () -> Void = {},
        onRegionsChanged: @escaping ([CardCopyableRegion]) -> Void = { _ in },
        onCopied: @escaping () -> Void = {}
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onOpenSettings = onOpenSettings
        self.onClose = onClose
        self.onRegionsChanged = onRegionsChanged
        self.onCopied = onCopied
    }

    private var appearance: StickyCardAppearance { viewModel.card.appearance }

    public var body: some View {
        VStack(spacing: 0) {
            if !viewModel.card.isLocked {
                header
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                Divider().opacity(0.4)
            }
            content
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .opacity(appearance.opacity)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.14))
                .opacity(appearance.opacity)
        )
        .padding(10) // 透明边距:供 App 层边缘拖拽缩放,且配合下方近透明层防穿透
        .background(Color.black.opacity(0.001))
        .onPreferenceChange(CardCopyableRegionsKey.self) { regions in
            // 仅锁定态需要区域;解锁态清空,避免覆盖层误命中。
            onRegionsChanged(viewModel.card.isLocked ? regions : [])
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.card.isClipboard {
            DesktopClipboardListView(viewModel: viewModel, appearance: appearance, onCopied: onCopied)
        } else {
            ManualSectionsView(
                viewModel: viewModel,
                appearance: appearance,
                focusedSectionID: $focusedSectionID,
                caretCharOffset: $caretCharOffset
            )
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button(action: viewModel.toggleLock) {
                Image(systemName: "lock.open")
            }
            .buttonStyle(.plain)
            .help("锁定卡片")

            if viewModel.card.isManual {
                Button(action: insertDivider) {
                    Image(systemName: "text.insert")
                }
                .buttonStyle(.plain)
                .help("在光标处插入分隔符")
            }

            Spacer()

            Button(action: onOpenSettings) {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.plain)
            .help("卡片设置")

            Button(action: onClose) {
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
            .help("关闭卡片")
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(.secondary)
    }

    private func insertDivider() {
        guard let sectionID = focusedSectionID ?? viewModel.sections.last?.id else { return }
        let offset = focusedSectionID == nil ? (viewModel.sections.last?.text.count ?? 0) : caretCharOffset
        if let newID = viewModel.insertDivider(inSectionID: sectionID, atGraphemeOffset: offset) {
            focusedSectionID = newID
            caretCharOffset = 0
        }
    }
}
