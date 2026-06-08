import ICopyCore
import ICopyUIComponents
import SwiftUI

public struct ClipboardPanelView: View {
    @StateObject private var viewModel: ClipboardViewModel
    @ObservedObject private var appearance: ClipboardAppearancePreferences
    @State private var itemBeingRenamed: RenameDraft?
    @State private var itemPendingDeletion: ClipboardItem?
    @State private var expandedItemID: ClipboardItem.ID?
    private let openSettings: () -> Void

    public init(
        viewModel: ClipboardViewModel = ClipboardViewModel(),
        appearance: ClipboardAppearancePreferences = ClipboardAppearancePreferences(),
        openSettings: @escaping () -> Void = {}
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.appearance = appearance
        self.openSettings = openSettings
    }

    public var body: some View {
        VStack(spacing: 0) {
            deepened { solid in
                header(solid: solid)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
            Divider().opacity(0.45)
            content
        }
        .opacity(fadeAmount)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .opacity(appearance.panelOpacity)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.14))
                .opacity(appearance.panelOpacity)
        )
        .padding(10)
        .background(Color.black.opacity(0.001))
        .frame(width: 440, height: 560)
        .alert(
            "删除收藏？",
            isPresented: Binding(
                get: { itemPendingDeletion != nil },
                set: { isPresented in
                    if !isPresented {
                        itemPendingDeletion = nil
                    }
                }
            ),
            presenting: itemPendingDeletion
        ) { item in
            Button("删除", role: .destructive) {
                viewModel.remove(item)
                itemPendingDeletion = nil
            }
            Button("取消", role: .cancel) {
                itemPendingDeletion = nil
            }
        } message: { item in
            Text("“\(item.displayTitle)”会从收藏中移除。")
        }
    }

    private func header(solid: Bool) -> some View {
        let secondary = solid ? solidLabel(0.9) : AnyShapeStyle(.secondary)

        return VStack(spacing: 12) {
            HStack(spacing: 10) {
                Text("iCopy")
                    .font(.system(size: 15, weight: .semibold))

                Spacer()

                Button(action: openSettings) {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.plain)
                .foregroundStyle(secondary)
                .help("设置")

                Button(role: .destructive, action: viewModel.clearHistory) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .foregroundStyle(secondary)
                .help("清空历史")
            }

            Picker("", selection: $viewModel.selectedScope) {
                ForEach(ClipboardScope.allCases) { scope in
                    Text(scope.rawValue).tag(scope)
                }
            }
            .pickerStyle(.segmented)

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.visibleItems.isEmpty {
            deepened { solid in
                emptyState(solid: solid)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(viewModel.visibleItems) { item in
                        ClipboardItemRow(
                            item: item,
                            solid: usesSolidListStyle,
                            onCopy: { viewModel.copy(item) },
                            onRename: { itemBeingRenamed = RenameDraft(item: item) },
                            onToggleFavorite: { viewModel.toggleFavorite(item) },
                            onDelete: { requestDelete(item) },
                            onExpansionChange: { expanded in
                                if expanded {
                                    expandedItemID = item.id
                                } else if expandedItemID == item.id {
                                    expandedItemID = nil
                                }
                            }
                        )
                        .zIndex(expandedItemID == item.id ? 1 : 0)
                    }
                }
                .foregroundStyle(listForegroundStyle)
                .padding(10)
            }
            .scrollContentBackground(.hidden)
            .sheet(item: $itemBeingRenamed) { draft in
                RenameSheet(
                    draft: draft,
                    onCancel: { itemBeingRenamed = nil },
                    onSave: { title in
                        viewModel.rename(draft.item, title: title)
                        itemBeingRenamed = nil
                    }
                )
            }
        }
    }

    private func emptyState(solid: Bool) -> some View {
        let secondary = solid ? solidLabel(0.78) : AnyShapeStyle(.secondary)
        return VStack(spacing: 10) {
            Image(systemName: "clipboard")
                .font(.system(size: 32))
                .foregroundStyle(secondary)
            Text(viewModel.selectedScope == .history ? "暂无剪切板历史" : "暂无收藏")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(solid ? solidLabel() : AnyShapeStyle(.primary))
            Text("复制文本后会显示在这里。")
                .font(.caption)
                .foregroundStyle(secondary)
        }
    }

    private func requestDelete(_ item: ClipboardItem) {
        if item.isFavorite {
            itemPendingDeletion = item
        } else {
            viewModel.remove(item)
        }
    }

    private func deepened<V: View>(@ViewBuilder _ render: (Bool) -> V) -> some View {
        render(false)
            .overlay(
                render(true)
                    .foregroundStyle(solidLabel())
                    .allowsHitTesting(false)
                    .opacity(deepenAmount)
            )
    }

    private var fadeAmount: Double {
        min(appearance.textIntensity / ClipboardAppearancePreferences.defaultTextIntensity, 1)
    }

    private var deepenAmount: Double {
        max(
            0,
            (appearance.textIntensity - ClipboardAppearancePreferences.defaultTextIntensity)
            / (1 - ClipboardAppearancePreferences.defaultTextIntensity)
        )
    }

    private var usesSolidListStyle: Bool {
        deepenAmount > 0
    }

    private var listForegroundStyle: AnyShapeStyle {
        usesSolidListStyle ? solidLabel() : AnyShapeStyle(.primary)
    }
}

private func solidLabel(_ opacity: Double = 1) -> AnyShapeStyle {
    AnyShapeStyle(Color(nsColor: .labelColor).opacity(opacity))
}

private struct RenameDraft: Identifiable {
    let item: ClipboardItem

    var id: ClipboardItem.ID { item.id }
    var initialTitle: String { item.title ?? "" }
}

private struct RenameSheet: View {
    let draft: RenameDraft
    let onCancel: () -> Void
    let onSave: (String?) -> Void
    @State private var title: String

    init(draft: RenameDraft, onCancel: @escaping () -> Void, onSave: @escaping (String?) -> Void) {
        self.draft = draft
        self.onCancel = onCancel
        self.onSave = onSave
        _title = State(initialValue: draft.initialTitle)
    }

    var body: some View {
        VStack(spacing: 12) {
            Text("编辑标题")
                .font(.headline)

            TextField("标题为空时显示剪切板内容", text: $title)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("清除标题") {
                    onSave(nil)
                }

                Spacer()

                Button("取消", action: onCancel)
                Button("保存") {
                    onSave(title)
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(18)
        .frame(width: 360)
    }
}
