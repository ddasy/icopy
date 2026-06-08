import Foundation

public struct ClipboardCollection: Equatable, Sendable {
    public private(set) var items: [ClipboardItem]
    public let maxHistoryCount: Int

    public init(items: [ClipboardItem] = [], maxHistoryCount: Int = 200) {
        self.maxHistoryCount = max(1, maxHistoryCount)
        self.items = Self.trim(items, maxHistoryCount: self.maxHistoryCount)
    }

    public var favorites: [ClipboardItem] {
        items.filter(\.isFavorite)
    }

    public var history: [ClipboardItem] {
        items.filter { !$0.isFavorite }
    }

    public mutating func record(_ content: String, now: Date = Date()) {
        let normalized = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }

        if let index = items.firstIndex(where: { $0.content == normalized }) {
            var existing = items.remove(at: index)
            existing.lastCopiedAt = now
            items.insert(existing, at: 0)
        } else {
            items.insert(ClipboardItem(content: normalized, createdAt: now, lastCopiedAt: now), at: 0)
        }

        items = Self.trim(items, maxHistoryCount: maxHistoryCount)
    }

    public mutating func toggleFavorite(id: ClipboardItem.ID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isFavorite.toggle()
    }

    public mutating func rename(id: ClipboardItem.ID, title: String?) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        let normalizedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        items[index].title = normalizedTitle?.isEmpty == false ? normalizedTitle : nil
        if items[index].title != nil {
            items[index].isFavorite = true
        }
    }

    public mutating func remove(id: ClipboardItem.ID) {
        items.removeAll { $0.id == id }
    }

    public mutating func clearHistoryKeepingFavorites() {
        items = items.filter(\.isFavorite)
    }

    private static func trim(_ items: [ClipboardItem], maxHistoryCount: Int) -> [ClipboardItem] {
        var result: [ClipboardItem] = []
        var historyCount = 0

        for item in items {
            if item.isFavorite {
                result.append(item)
            } else if historyCount < maxHistoryCount {
                result.append(item)
                historyCount += 1
            }
        }

        return result
    }
}
