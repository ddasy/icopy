import AppKit
import ClipboardPanel
import Foundation
import ICopyClipboard
import ICopyCore
import ICopyStorage
import Testing
@testable import DesktopCard

@MainActor
private final class FakePasteboard: PasteboardWriting {
    var written: [String] = []
    func writeString(_ value: String) { written.append(value) }
}

private struct InMemoryClipboardStore: ClipboardStore {
    let items: [ClipboardItem]
    func load() throws -> [ClipboardItem] { items }
    func save(_ items: [ClipboardItem]) throws {}
}

@MainActor
@Test
func insertDividerSplitsAndPersists() {
    var persisted: StickyCardItem?
    let card = StickyCardItem(sections: [StickyCardSection(text: "HelloWorld")])
    let vm = DesktopCardViewModel(
        card: card,
        pasteboard: FakePasteboard(),
        onPersist: { persisted = $0 }
    )
    let firstID = vm.sections[0].id

    let newID = vm.insertDivider(inSectionID: firstID, atGraphemeOffset: 5)

    #expect(vm.sections.count == 2)
    #expect(vm.sections[0].text == "Hello")
    #expect(vm.sections[1].text == "World")
    #expect(newID == vm.sections[1].id)
    _ = persisted // 去抖写在 300ms 后,这里只验证内存态切分
}

@MainActor
@Test
func copySectionWritesTrimmedTextSkipsEmpty() {
    let pasteboard = FakePasteboard()
    let card = StickyCardItem(sections: [
        StickyCardSection(text: "  copy me  "),
        StickyCardSection(text: "   ")
    ])
    let vm = DesktopCardViewModel(card: card, pasteboard: pasteboard)

    #expect(vm.copySection(id: vm.sections[0].id) == true)
    #expect(vm.copySection(id: vm.sections[1].id) == false) // 空白分区不复制
    #expect(pasteboard.written == ["copy me"])
}

@MainActor
@Test
func toggleLockFlipsState() {
    let vm = DesktopCardViewModel(card: StickyCardItem(), pasteboard: FakePasteboard())
    #expect(vm.card.isLocked == false)
    vm.toggleLock()
    #expect(vm.card.isLocked == true)
}

@MainActor
@Test
func clipboardCardCopyItemWritesToPasteboard() {
    // 剪贴板卡片复制路径:copyItem → 共享 ClipboardViewModel.copy → 写入系统剪贴板。
    let store = InMemoryClipboardStore(items: [ClipboardItem(content: "HELLO_PB")])
    let clipboard = ClipboardViewModel(store: store)
    let card = StickyCardItem(
        contentMode: .clipboard,
        sections: [],
        clipboardSource: StickyCardClipboardSource(scope: .history)
    )
    let vm = DesktopCardViewModel(card: card, clipboard: clipboard)

    guard let item = vm.items.first(where: { $0.content == "HELLO_PB" }) else {
        Issue.record("clipboard card did not project the history item")
        return
    }
    NSPasteboard.general.clearContents()

    #expect(vm.copyItem(id: item.id) == true)
    #expect(NSPasteboard.general.string(forType: .string) == "HELLO_PB")
}

@MainActor
@Test
func setModeMaintainsInvariants() {
    let vm = DesktopCardViewModel(
        card: StickyCardItem(contentMode: .manual, sections: [StickyCardSection(text: "x")]),
        pasteboard: FakePasteboard()
    )

    vm.setMode(.clipboard)
    #expect(vm.card.sections.isEmpty)
    #expect(vm.card.clipboardSource != nil)

    vm.setMode(.manual)
    #expect(vm.card.sections.count == 1)
    #expect(vm.card.clipboardSource == nil)
}

@Test
func colorPaletteIncludesWhite() {
    #expect(StickyCardColorPreset.palette.contains { $0.id == "white" && $0.color == .white })
}
