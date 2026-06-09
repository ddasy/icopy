import AppKit
import ClipboardPanel
import DesktopCard
import ICopyCore
import ICopyStorage
import ICopyTranslation

/// 桌面卡片的拥有者:持有卡片集合与存储,创建/关闭/恢复每张卡片的窗口控制器,
/// 共享同一个 ClipboardViewModel(剪贴板卡片的数据源)与同一个"已复制"提示。集合保存去抖。
@MainActor
final class DesktopCardManager {
    private var collection: StickyCardCollection
    private let store: StickyCardStore
    private let clipboard: ClipboardViewModel
    private let translationPreferences: TranslationPreferences
    private let toast = CopiedToastController()
    private var controllers: [StickyCardItem.ID: DesktopCardWindowController] = [:]
    private var saveTask: Task<Void, Never>?

    init(
        clipboard: ClipboardViewModel,
        translationPreferences: TranslationPreferences,
        store: StickyCardStore = JSONStickyCardStore()
    ) {
        self.clipboard = clipboard
        self.translationPreferences = translationPreferences
        self.store = store
        if let cards = try? store.load() {
            self.collection = StickyCardCollection(cards: cards)
        } else {
            self.collection = StickyCardCollection()
        }
    }

    func restorePersistedCards() {
        // 启动恢复不抢焦点;用户点击卡片时再自然激活。
        for card in collection.cards {
            makeController(for: card).show(activate: false)
        }
    }

    @discardableResult
    func createCard(mode: StickyCardContentMode = .manual) -> StickyCardItem.ID {
        let card = collection.newCard(mode: mode, frame: nextFrame())
        saveSoon()
        makeController(for: card).show()
        return card.id
    }

    func closeCard(_ id: StickyCardItem.ID) {
        controllers[id]?.close()
        controllers[id] = nil
        collection.remove(id: id)
        saveSoon()
    }

    var cardCount: Int { collection.cards.count }

    // MARK: - 内部

    @discardableResult
    private func makeController(for card: StickyCardItem) -> DesktopCardWindowController {
        let viewModel = DesktopCardViewModel(
            card: card,
            clipboard: card.isClipboard ? clipboard : nil,
            translator: LMStudioTranslationService(config: translationPreferences.config),
            onPersist: { [weak self] updated in self?.persist(updated) }
        )
        let controller = DesktopCardWindowController(
            viewModel: viewModel,
            toast: toast,
            onCloseRequested: { [weak self] id in self?.closeCard(id) }
        )
        controllers[card.id] = controller
        return controller
    }

    private func persist(_ card: StickyCardItem) {
        collection.update(card)
        saveSoon()
    }

    /// 新卡片原点层叠偏移,约束在主屏可见区域内。
    private func nextFrame() -> CGRect {
        var frame = StickyCardItem.defaultFrame
        let offset = CGFloat(collection.cards.count % 8) * 28
        frame.origin.x += offset
        frame.origin.y += offset
        if let visible = NSScreen.main?.visibleFrame {
            if frame.maxX > visible.maxX { frame.origin.x = visible.maxX - frame.width }
            if frame.maxY > visible.maxY { frame.origin.y = visible.maxY - frame.height }
            frame.origin.x = max(frame.origin.x, visible.minX)
            frame.origin.y = max(frame.origin.y, visible.minY)
        }
        return frame
    }

    private func saveSoon() {
        saveTask?.cancel()
        let snapshot = collection.cards
        saveTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            try? self.store.save(snapshot)
        }
    }
}
