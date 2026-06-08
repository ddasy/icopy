import Foundation
import ICopyClipboard
import ICopyCore
import ICopyStorage

@MainActor
public final class ClipboardViewModel: ObservableObject {
    @Published public private(set) var collection: ClipboardCollection
    @Published public var selectedScope: ClipboardScope = .favorites
    @Published public private(set) var errorMessage: String?

    private let store: ClipboardStore
    private let pasteboardWriter: PasteboardWriting
    private let monitor: ClipboardMonitor

    public init(
        store: ClipboardStore = JSONClipboardStore(),
        pasteboard: SystemPasteboardClient = SystemPasteboardClient()
    ) {
        self.store = store
        self.pasteboardWriter = pasteboard
        self.monitor = ClipboardMonitor(pasteboard: pasteboard)

        do {
            self.collection = ClipboardCollection(items: try store.load())
        } catch {
            self.collection = ClipboardCollection()
            self.errorMessage = "无法加载剪切板历史。"
        }

        monitor.onTextChange = { [weak self] value in
            self?.record(value)
        }
        monitor.start()
    }

    public var visibleItems: [ClipboardItem] {
        switch selectedScope {
        case .history:
            collection.items
        case .favorites:
            collection.favorites
        }
    }

    public func copy(_ item: ClipboardItem) {
        pasteboardWriter.writeString(item.content)
    }

    public func synchronizeClipboard() {
        monitor.synchronize()
    }

    public func toggleFavorite(_ item: ClipboardItem) {
        collection.toggleFavorite(id: item.id)
        persist()
    }

    public func rename(_ item: ClipboardItem, title: String?) {
        collection.rename(id: item.id, title: title)
        persist()
    }

    public func remove(_ item: ClipboardItem) {
        collection.remove(id: item.id)
        persist()
    }

    public func clearHistory() {
        collection.clearHistoryKeepingFavorites()
        persist()
    }

    private func record(_ value: String) {
        let previousItems = collection.items
        collection.record(value)
        guard collection.items != previousItems else { return }
        persist()
    }

    private func persist() {
        do {
            try store.save(collection.items)
            errorMessage = nil
        } catch {
            errorMessage = "无法保存剪切板历史。"
        }
    }
}

public enum ClipboardScope: String, CaseIterable, Identifiable {
    case history = "历史"
    case favorites = "收藏"

    public var id: String { rawValue }
}
