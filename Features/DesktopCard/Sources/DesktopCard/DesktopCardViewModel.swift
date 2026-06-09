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

    private let pasteboard: PasteboardWriting
    private let translator: TranslationService?
    private let onPersist: (StickyCardItem) -> Void
    private var persistTask: Task<Void, Never>?
    private var translateTask: Task<Void, Never>?
    private var lastTranslatedSource: String = ""
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
        self.translator = translator
        self.onPersist = onPersist
        if let translation = card.translation,
           translation.status == .done,
           !translation.translatedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.lastTranslatedSource = translation.sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // 剪贴板模式:共享集合变化时转发,使桌面列表(及锁定态可复制区域)实时刷新。
        if let clipboard {
            clipboardObservation = clipboard.objectWillChange.sink { [weak self] _ in
                self?.objectWillChange.send()
            }
        }
        scheduleTranslate()
    }

    public var id: StickyCardItem.ID { card.id }

    // MARK: - 手动内容

    public var sections: [StickyCardSection] { card.sections }

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

    public func removeDivider(beforeSectionID sectionID: StickyCardSection.ID) {
        card.removeDivider(beforeSectionID: sectionID)
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
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            translateTask?.cancel()
            card.translation?.translatedText = ""
            card.translation?.status = .idle
            lastTranslatedSource = ""
        }
        persistSoon()
        scheduleTranslate()
    }

    @discardableResult
    public func copyTranslation() -> Bool {
        guard let text = card.translation?.translatedText.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else { return false }
        pasteboard.writeString(text)
        return true
    }

    // MARK: - 状态

    public func toggleLock() {
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
            translateTask?.cancel()
        case .clipboard:
            card.sections = []
            if card.clipboardSource == nil { card.clipboardSource = StickyCardClipboardSource(scope: .history) }
            card.translation = nil
            translateTask?.cancel()
        case .translation:
            card.sections = []
            card.clipboardSource = nil
            if card.translation == nil { card.translation = StickyCardTranslation() }
            scheduleTranslate()
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

    private func scheduleTranslate() {
        translateTask?.cancel()
        guard let translator, let translation = card.translation else { return }
        let source = translation.sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty, source != lastTranslatedSource else { return }
        translateTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }
            await self.runTranslation(source: source, translator: translator)
        }
    }

    private func runTranslation(source: String, translator: TranslationService) async {
        let target = StickyCardItem.detectTarget(for: source)
        card.translation?.status = .translating
        objectWillChange.send()
        do {
            let result = try await translator.translate(source, to: target)
            guard !Task.isCancelled else { return }
            card.translation?.translatedText = result
            card.translation?.status = .done
            lastTranslatedSource = source
            pasteboard.writeString(source)
        } catch {
            guard !Task.isCancelled else { return }
            card.translation?.status = .failed(Self.message(for: error))
        }
        objectWillChange.send()
        persistNow()
    }

    private static func message(for error: Error) -> String {
        if let translationError = error as? TranslationError {
            switch translationError {
            case .emptyInput: return "请输入要翻译的内容"
            case .server(let status, let body): return "LM Studio 返回 \(status): \(body)"
            case .malformedResponse: return "LM Studio 响应格式不正确"
            case .transport(let message): return "连接失败: \(message)"
            }
        }
        return error.localizedDescription
    }
}
