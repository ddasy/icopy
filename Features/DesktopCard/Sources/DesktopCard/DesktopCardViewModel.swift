import Combine
import Foundation
import ICopyClipboard
import ICopyCore
import ICopyTranslation
import SwiftUI
import ClipboardPanel

/// 编排单张桌面卡片:绑定 StickyCardItem、应用外观、转发分区/复制操作,
/// 编辑经 Core 业务规则后去抖持久化。剪贴板模式观察共享的 ClipboardViewModel(零复制)。
@MainActor
public final class DesktopCardViewModel: ObservableObject {
    @Published public private(set) var card: StickyCardItem

    /// 仅 .clipboard 卡片非 nil;全应用共享一个,避免重复监听/重复记录。
    public let clipboard: ClipboardViewModel?
    public var translation: StickyCardTranslation? { card.translation }

    /// 翻译管线与活跃状态(注入了 translator 时非 nil);视图的方向行/译文区直接观察它。
    public let translationController: TranslationController?

    private let pasteboard: PasteboardWriting
    private let onPersist: (StickyCardItem) -> Void
    private var persistTask: Task<Void, Never>?
    private var clipboardObservation: AnyCancellable?

    public init(
        card: StickyCardItem,
        pasteboard: PasteboardWriting = SystemPasteboardClient(),
        clipboard: ClipboardViewModel? = nil,
        translator: TranslationService? = nil,
        onPersist: @escaping (StickyCardItem) -> Void = { _ in }
    ) {
        self.card = card
        self.pasteboard = pasteboard
        self.clipboard = clipboard
        self.translationController = translator.map { TranslationController(translator: $0) }
        self.onPersist = onPersist
        if self.card.isTranslation, self.card.isLocked {
            self.card.translation?.isWindowLocked = true
            self.card.lockState = .unlocked
        }

        // 剪贴板模式:共享集合变化时转发,使桌面列表(及锁定态可复制区域)实时刷新。
        if let clipboard {
            clipboardObservation = clipboard.objectWillChange.sink { [weak self] _ in
                self?.objectWillChange.send()
            }
        }

        translationController?.onSettled = { [weak self] source, translated, target, status in
            self?.translationSettled(source: source, translated: translated, target: target, status: status)
        }
        if let translation = self.card.translation {
            translationController?.restore(translation)
        }
    }

    public var id: StickyCardItem.ID { card.id }
    public var usesDesktopLock: Bool { !card.isTranslation && card.isLocked }
    public var isWindowLocked: Bool {
        card.isTranslation ? (card.translation?.isWindowLocked ?? false) : card.isLocked
    }

    // MARK: - 手动内容

    public var sections: [StickyCardSection] { card.sections }

    /// 分区按行分组:每行内横向并排,行间纵向堆叠(供视图渲染横/竖分隔)。
    public var rows: [[StickyCardSection]] { card.rows }

    public func setText(_ text: String, sectionID: StickyCardSection.ID) {
        card.setText(text, sectionID: sectionID)
        persistSoon()
    }

    @discardableResult
    public func insertDivider(inSectionID sectionID: StickyCardSection.ID, atGraphemeOffset offset: Int) -> StickyCardSection.ID? {
        let newID = card.insertDivider(inSectionID: sectionID, atOffset: offset)
        persistSoon()
        return newID
    }

    @discardableResult
    public func insertVerticalDivider(inSectionID sectionID: StickyCardSection.ID, atGraphemeOffset offset: Int, widthFraction: Double) -> StickyCardSection.ID? {
        let newID = card.insertVerticalDivider(inSectionID: sectionID, atOffset: offset, widthFraction: widthFraction)
        persistSoon()
        return newID
    }

    /// 删除竖向分隔右侧那一列(整块移除,不合并)。
    public func deleteSection(id: StickyCardSection.ID) {
        card.deleteSection(id: id)
        persistSoon()
    }

    /// 删除横向分隔下方那一整行(含其所有列)。
    public func deleteRow(startingAtSectionID id: StickyCardSection.ID) {
        card.deleteRow(startingAtSectionID: id)
        persistSoon()
    }

    /// 锁定态单击分区时由覆盖层调用。空白分区不复制(返回 false)。
    @discardableResult
    public func copySection(id: StickyCardSection.ID) -> Bool {
        guard let section = card.sections.first(where: { $0.id == id }), !section.isEmpty else { return false }
        pasteboard.writeString(section.copyableText)
        return true
    }

    // MARK: - 剪贴板模式

    public var items: [ClipboardItem] {
        guard let clipboard, let source = card.clipboardSource else { return [] }
        return source.resolve(from: clipboard.collection)
    }

    /// 锁定态单击行时由覆盖层调用。
    @discardableResult
    public func copyItem(id: ClipboardItem.ID) -> Bool {
        guard let clipboard, let item = items.first(where: { $0.id == id }) else { return false }
        clipboard.copy(item)
        return true
    }

    // MARK: - 翻译模式

    public func setSourceText(_ text: String) {
        guard card.translation != nil else { return }
        card.translation?.sourceText = text
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            card.translation?.translatedText = ""
            card.translation?.status = .idle
        }
        persistSoon()
        translationController?.setSource(text)
    }

    @discardableResult
    public func copyTranslation() -> Bool {
        let live = translationController?.translatedText ?? card.translation?.translatedText ?? ""
        let text = live.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return false }
        pasteboard.writeString(text)
        return true
    }

    /// 翻译尘埃落定:回写卡片持久态;成功时把英文侧文本写入系统剪贴板
    /// (中→英复制英文译文,英→中复制英文原文)。
    private func translationSettled(source: String, translated: String, target: TranslationLanguage, status: TranslationStatus) {
        guard card.translation != nil else { return }
        card.translation?.translatedText = translated
        card.translation?.status = status
        persistNow()
        if status == .done {
            pasteboard.writeString(target == .english ? translated : source)
        }
    }

    // MARK: - 状态

    public func toggleLock() {
        if card.isTranslation {
            if card.translation == nil { card.translation = StickyCardTranslation() }
            card.translation?.isWindowLocked.toggle()
            card.lockState = .unlocked
            card.updatedAt = Date()
            persistNow()
            return
        }
        var state = card.lockState
        state.toggle()
        card.setLock(state)
        persistNow()
    }

    public func setMode(_ mode: StickyCardContentMode) {
        guard mode != card.contentMode else { return }
        card.contentMode = mode
        // 维持不变量:manual 至少一个分区;clipboard 无分区且带来源;translation 有翻译状态。
        switch mode {
        case .manual:
            if card.sections.isEmpty { card.sections = [StickyCardSection()] }
            card.clipboardSource = nil
            card.translation = nil
            translationController?.reset()
        case .clipboard:
            card.sections = []
            if card.clipboardSource == nil { card.clipboardSource = StickyCardClipboardSource(scope: .history) }
            card.translation = nil
            translationController?.reset()
        case .translation:
            card.sections = []
            card.clipboardSource = nil
            card.lockState = .unlocked
            if card.translation == nil { card.translation = StickyCardTranslation() }
            if let translation = card.translation {
                translationController?.restore(translation)
            }
        }
        persistNow()
    }

    /// 由窗口控制器在拖动/缩放提交时调用。
    public func setFrame(_ frame: CGRect) {
        card.setFrame(frame)
        persistSoon()
    }

    public var appearanceBinding: Binding<StickyCardAppearance> {
        Binding(
            get: { self.card.appearance },
            set: { self.card.setAppearance($0); self.persistSoon() }
        )
    }

    public func resetAppearance() {
        card.setAppearance(.default)
        persistNow()
    }

    // MARK: - 持久化(内容/外观/几何去抖 ~300ms;锁定/模式立即写)

    private func persistSoon() {
        persistTask?.cancel()
        let snapshot = card
        persistTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            self.onPersist(snapshot)
        }
    }

    private func persistNow() {
        persistTask?.cancel()
        persistTask = nil
        onPersist(card)
    }

}
