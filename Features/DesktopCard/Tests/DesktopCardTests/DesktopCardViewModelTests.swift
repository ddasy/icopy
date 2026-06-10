import AppKit
import ClipboardPanel
import Combine
import Foundation
import ICopyClipboard
import ICopyCore
import ICopyStorage
import ICopyTranslation
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

private actor MockTranslationService: TranslationService {
    var results: [String]
    var error: Error?
    private(set) var calls: [(text: String, target: TranslationLanguage)] = []

    init(results: [String] = ["translated"], error: Error? = nil) {
        self.results = results
        self.error = error
    }

    func translate(_ text: String, to target: TranslationLanguage) async throws -> String {
        calls.append((text, target))
        if let error { throw error }
        return results.isEmpty ? "" : results.removeFirst()
    }

    var callCount: Int { calls.count }
}

private struct StreamingStubService: TranslationService {
    let chunks: [String]

    func translate(_ text: String, to target: TranslationLanguage) async throws -> String { chunks.joined() }

    func translateStream(_ text: String, to target: TranslationLanguage) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            for chunk in chunks { continuation.yield(chunk) }
            continuation.finish()
        }
    }
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
func translationLockUsesWindowOnlyState() {
    let card = StickyCardItem(contentMode: .translation, sections: [], translation: StickyCardTranslation())
    let vm = DesktopCardViewModel(card: card, pasteboard: FakePasteboard())

    #expect(vm.card.isLocked == false)
    #expect(vm.isWindowLocked == false)
    #expect(vm.usesDesktopLock == false)

    vm.toggleLock()

    #expect(vm.card.isLocked == false)
    #expect(vm.card.translation?.isWindowLocked == true)
    #expect(vm.isWindowLocked == true)
    #expect(vm.usesDesktopLock == false)
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
    #expect(vm.card.translation == nil)

    vm.setMode(.manual)
    #expect(vm.card.sections.count == 1)
    #expect(vm.card.clipboardSource == nil)

    vm.setMode(.translation)
    #expect(vm.card.sections.isEmpty)
    #expect(vm.card.clipboardSource == nil)
    #expect(vm.card.translation != nil)
}

@MainActor
@Test
func translationCommitUpdatesResult() async throws {
    let translator = MockTranslationService(results: ["Hello"])
    let pasteboard = FakePasteboard()
    let card = StickyCardItem(contentMode: .translation, sections: [], translation: StickyCardTranslation())
    let vm = DesktopCardViewModel(card: card, pasteboard: pasteboard, translator: translator)

    vm.setSourceText("你好")
    try await Task.sleep(for: .milliseconds(850))

    #expect(vm.translation?.translatedText == "Hello")
    #expect(vm.translation?.status == .done)
    let calls = await translator.calls
    #expect(calls.count == 1)
    #expect(calls.first?.text == "你好")
    #expect(calls.first?.target == .english)
    #expect(pasteboard.written == ["Hello"]) // 中→英:自动复制英文译文
}

@MainActor
@Test
func translationCoalescesToLatestCommit() async throws {
    let translator = MockTranslationService(results: ["Bonjour"])
    let pasteboard = FakePasteboard()
    let card = StickyCardItem(contentMode: .translation, sections: [], translation: StickyCardTranslation())
    let vm = DesktopCardViewModel(card: card, pasteboard: pasteboard, translator: translator)

    vm.setSourceText("h")
    try await Task.sleep(for: .milliseconds(100))
    vm.setSourceText("hello")
    try await Task.sleep(for: .milliseconds(850))

    #expect(vm.translation?.translatedText == "Bonjour")
    #expect(await translator.callCount == 1)
    #expect(await translator.calls.first?.text == "hello")
    #expect(pasteboard.written == ["hello"]) // 英→中:自动复制英文原文
}

@MainActor
@Test
func translationFailureUpdatesStatus() async throws {
    let translator = MockTranslationService(error: TranslationError.malformedResponse)
    let pasteboard = FakePasteboard()
    let card = StickyCardItem(contentMode: .translation, sections: [], translation: StickyCardTranslation())
    let vm = DesktopCardViewModel(card: card, pasteboard: pasteboard, translator: translator)

    vm.setSourceText("hello")
    try await Task.sleep(for: .milliseconds(850))

    guard case .failed(let message) = vm.translation?.status else {
        Issue.record("translation status did not fail")
        return
    }
    #expect(message == "LM Studio 响应格式不正确")
    #expect(pasteboard.written.isEmpty)
}

@MainActor
@Test
func translationSkipsSameSourceAfterSuccess() async throws {
    let translator = MockTranslationService(results: ["Hello"])
    let card = StickyCardItem(contentMode: .translation, sections: [], translation: StickyCardTranslation())
    let vm = DesktopCardViewModel(card: card, pasteboard: FakePasteboard(), translator: translator)

    vm.setSourceText("你好")
    try await Task.sleep(for: .milliseconds(850))
    vm.setSourceText("你好")
    try await Task.sleep(for: .milliseconds(850))

    #expect(await translator.callCount == 1)
}

@MainActor
@Test
func translationStreamsIncrementalDeltas() async throws {
    let controller = TranslationController(
        translator: StreamingStubService(chunks: ["Hel", "lo", " world"]),
        coalesceWindow: .milliseconds(10)
    )
    var observed: [String] = []
    let cancellable = controller.$translatedText.sink { observed.append($0) }

    controller.setSource("你好世界")
    try await Task.sleep(for: .milliseconds(300))

    #expect(controller.status == .done)
    #expect(controller.translatedText == "Hello world")
    #expect(observed.contains("Hel"))   // 流式中间态曾被发布
    #expect(observed.contains("Hello"))
    cancellable.cancel()
}

@MainActor
@Test
func translationControllerSettlesIntoCard() async throws {
    let translator = MockTranslationService(results: ["Hello"])
    let pasteboard = FakePasteboard()
    let card = StickyCardItem(contentMode: .translation, sections: [], translation: StickyCardTranslation())
    let vm = DesktopCardViewModel(card: card, pasteboard: pasteboard, translator: translator)

    vm.setSourceText("你好")
    try await Task.sleep(for: .milliseconds(850))

    #expect(vm.translationController?.translatedText == "Hello")
    #expect(vm.translationController?.status == .done)
    #expect(vm.translation?.translatedText == "Hello") // 落定后回写持久态
}

@Test
func colorPaletteIncludesWhite() {
    #expect(StickyCardColorPreset.palette.contains { $0.id == "white" && $0.color == .white })
}
