import CoreGraphics
import Foundation

/// 桌面卡片集合聚合:增删改、按 id 查找、重排序(z-order),可直接持久化为 [StickyCardItem]。
public struct StickyCardCollection: Equatable, Sendable, Codable {
    public private(set) var cards: [StickyCardItem]

    public init(cards: [StickyCardItem] = []) {
        self.cards = cards
    }

    public subscript(id: StickyCardItem.ID) -> StickyCardItem? {
        cards.first { $0.id == id }
    }

    /// 新建卡片并按内容模式建立不变量:manual → 一个空分区且无来源;clipboard → 无分区且带 .history 来源。
    @discardableResult
    public mutating func newCard(
        mode: StickyCardContentMode,
        frame: CGRect = StickyCardItem.defaultFrame,
        now: Date = Date()
    ) -> StickyCardItem {
        let card: StickyCardItem
        switch mode {
        case .manual:
            card = StickyCardItem(
                contentMode: .manual,
                frame: frame,
                sections: [StickyCardSection()],
                clipboardSource: nil,
                createdAt: now,
                updatedAt: now
            )
        case .clipboard:
            card = StickyCardItem(
                contentMode: .clipboard,
                frame: frame,
                sections: [],
                clipboardSource: StickyCardClipboardSource(scope: .history),
                createdAt: now,
                updatedAt: now
            )
        }
        cards.append(card)
        return card
    }

    public mutating func add(_ card: StickyCardItem) {
        cards.append(card)
    }

    public mutating func remove(id: StickyCardItem.ID) {
        cards.removeAll { $0.id == id }
    }

    public mutating func update(_ card: StickyCardItem) {
        guard let index = cards.firstIndex(where: { $0.id == card.id }) else { return }
        cards[index] = card
    }

    /// 原地修改某卡片,避免调用方读改写三步。
    public mutating func mutate(id: StickyCardItem.ID, _ body: (inout StickyCardItem) -> Void) {
        guard let index = cards.firstIndex(where: { $0.id == id }) else { return }
        body(&cards[index])
    }

    /// 把卡片移到数组末尾(置顶 z-order)。
    public mutating func bringToFront(id: StickyCardItem.ID) {
        guard let index = cards.firstIndex(where: { $0.id == id }) else { return }
        let card = cards.remove(at: index)
        cards.append(card)
    }
}
