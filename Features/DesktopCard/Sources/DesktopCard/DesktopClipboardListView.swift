import ICopyCore
import SwiftUI

/// 剪贴板卡片内容:桌面化的历史只读列表。每行上报可复制区域;复制由覆盖层在锁定态单击触发,
/// 行本身不自带单击复制(与"仅锁定态复制"规则一致)。刻意用紧凑行而非完整 ClipboardItemRow,
/// 因为桌面卡片不需要其悬浮详情层/操作按钮,且交互走覆盖层而非行内手势。
struct DesktopClipboardListView: View {
    @ObservedObject var viewModel: DesktopCardViewModel
    let appearance: StickyCardAppearance
    /// 解锁态点击行复制后回调(用于显示"已复制");锁定态复制由覆盖层处理。
    let onCopied: () -> Void

    var body: some View {
        Group {
            if viewModel.items.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(viewModel.items) { item in
                            row(item)
                        }
                    }
                    .padding(8)
                }
                .scrollContentBackground(.hidden)
            }
        }
    }

    private func row(_ item: ClipboardItem) -> some View {
        Text(rowText(item))
            .font(appearance.swiftUIFont)
            .foregroundStyle(appearance.swiftUITextColor)
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 7)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.28))
            )
            .contentShape(Rectangle())
            .reportCopyRegion(.clipboardItem(item.id))
            .onTapGesture {
                // 解锁态:SwiftUI 直接复制(快速复制)。锁定态卡片沉桌面收不到事件,由覆盖层复制。
                guard !viewModel.card.isLocked else { return }
                if viewModel.copyItem(id: item.id) { onCopied() }
            }
    }

    private func rowText(_ item: ClipboardItem) -> String {
        let value = item.displayTitle
        return value.isEmpty ? "空文本" : value
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "clipboard")
                .font(.system(size: 26))
            Text("暂无剪切板历史")
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundStyle(appearance.swiftUITextColor.opacity(0.7))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
    }
}
