import CoreGraphics
import Foundation
import Testing
@testable import ICopyCore

// MARK: - 分隔符切分/合并

@Test
func insertDividerSplitsSectionAtOffset() {
    var card = StickyCardItem(sections: [StickyCardSection(text: "HelloWorld")])
    let firstID = card.sections[0].id

    let newID = card.insertDivider(inSectionID: firstID, atOffset: 5)

    #expect(card.sections.count == 2)
    #expect(card.sections[0].text == "Hello")
    #expect(card.sections[1].text == "World")
    #expect(newID == card.sections[1].id)
    #expect(card.sections[0].id == firstID) // 原分区 id 不变
}

@Test
func insertDividerClampsOutOfRangeOffset() {
    var card = StickyCardItem(sections: [StickyCardSection(text: "abc")])
    let id = card.sections[0].id

    card.insertDivider(inSectionID: id, atOffset: 999)

    #expect(card.sections[0].text == "abc")
    #expect(card.sections[1].text == "")
}

@Test
func insertDividerHandlesUnicodeGraphemeOffsets() {
    var card = StickyCardItem(sections: [StickyCardSection(text: "a👨‍👩‍👧b")])
    let id = card.sections[0].id

    // 偏移 2 = a + 一个家庭 emoji(单个 grapheme)之后
    card.insertDivider(inSectionID: id, atOffset: 2)

    #expect(card.sections[0].text == "a👨‍👩‍👧")
    #expect(card.sections[1].text == "b")
}

@Test
func removeDividerMergesIntoPrevious() {
    var card = StickyCardItem(sections: [
        StickyCardSection(text: "Hello"),
        StickyCardSection(text: "World")
    ])
    let secondID = card.sections[1].id

    card.removeDivider(beforeSectionID: secondID)

    #expect(card.sections.count == 1)
    #expect(card.sections[0].text == "HelloWorld")
}

@Test
func removeDividerOnFirstSectionIsNoop() {
    var card = StickyCardItem(sections: [StickyCardSection(text: "only")])
    let id = card.sections[0].id

    card.removeDivider(beforeSectionID: id)

    #expect(card.sections.count == 1)
}

// MARK: - 集合操作

@Test
func newManualCardHasOneEmptySectionAndNoSource() {
    var collection = StickyCardCollection()
    let card = collection.newCard(mode: .manual)

    #expect(card.isManual)
    #expect(card.sections.count == 1)
    #expect(card.clipboardSource == nil)
    #expect(collection.cards.count == 1)
}

@Test
func newClipboardCardHasNoSectionsAndHistorySource() {
    var collection = StickyCardCollection()
    let card = collection.newCard(mode: .clipboard)

    #expect(card.isClipboard)
    #expect(card.sections.isEmpty)
    #expect(card.clipboardSource?.scope == .history)
    #expect(card.translation == nil)
}

@Test
func newTranslationCardHasTranslationStateOnly() {
    var collection = StickyCardCollection()
    let card = collection.newCard(mode: .translation)

    #expect(card.isTranslation)
    #expect(card.sections.isEmpty)
    #expect(card.clipboardSource == nil)
    #expect(card.translation == StickyCardTranslation())
}

@Test
func bringToFrontReordersToEnd() {
    var collection = StickyCardCollection()
    let a = collection.newCard(mode: .manual)
    _ = collection.newCard(mode: .manual)

    collection.bringToFront(id: a.id)

    #expect(collection.cards.last?.id == a.id)
}

@Test
func removeAndMutateById() {
    var collection = StickyCardCollection()
    let a = collection.newCard(mode: .manual)

    collection.mutate(id: a.id) { $0.setLock(.locked) }
    #expect(collection[a.id]?.isLocked == true)

    collection.remove(id: a.id)
    #expect(collection.cards.isEmpty)
}

// MARK: - 外观与编解码

@Test
func appearanceClampsValues() {
    let a = StickyCardAppearance(opacity: 0.0, fontSize: 1000, textIntensity: 5)
    #expect(a.opacity == 0.1)
    #expect(a.fontSize == 48)
    #expect(a.textIntensity == 1.0)
}

@Test
func appearanceDefaultsToWhiteText() {
    #expect(StickyCardAppearance.default.textColor == .white)
    #expect(StickyCardItem().appearance.textColor == .white)
}

@Test
func cardCodableRoundTripPreservesFrameAndContent() throws {
    let original = StickyCardItem(
        contentMode: .manual,
        lockState: .locked,
        frame: CGRect(x: 12.5, y: 34, width: 280, height: 360),
        appearance: StickyCardAppearance(opacity: 0.6, fontSize: 16, fontWeight: .bold),
        sections: [StickyCardSection(text: "one"), StickyCardSection(text: "two")],
        createdAt: Date(timeIntervalSince1970: 1000), // 整秒,iso8601 无小数秒,可精确往返
        updatedAt: Date(timeIntervalSince1970: 2000)
    )

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    let data = try encoder.encode(original)
    let decoded = try decoder.decode(StickyCardItem.self, from: data)

    #expect(decoded == original)
    #expect(decoded.frame == original.frame)
}

@Test
func cardDecodesStoredJSONWithoutTranslationField() throws {
    let original = StickyCardItem(createdAt: Date(timeIntervalSince1970: 1000), updatedAt: Date(timeIntervalSince1970: 1000))
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(original)
    var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    object.removeValue(forKey: "translation")
    let legacyData = try JSONSerialization.data(withJSONObject: object)

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let decoded = try decoder.decode(StickyCardItem.self, from: legacyData)

    #expect(decoded.translation == nil)
}

@Test
func detectTranslationTargetUsesCJKRatio() {
    #expect(StickyCardItem.detectTarget(for: "你好世界") == .english)
    #expect(StickyCardItem.detectTarget(for: "Hello world") == .chinese)
    #expect(StickyCardItem.detectTarget(for: "你好 abc") == .english)
    #expect(StickyCardItem.detectTarget(for: "hello 你") == .chinese)
    #expect(StickyCardItem.detectTarget(for: "12345!?") == .chinese)
    #expect(StickyCardItem.detectTarget(for: "") == .chinese)
}

@Test
func clipboardSourceResolvesHistoryWithLimit() {
    var clip = ClipboardCollection(maxHistoryCount: 10)
    clip.record("a")
    clip.record("b")
    clip.record("c")

    let source = StickyCardClipboardSource(scope: .history, limit: 2)
    let rows = source.resolve(from: clip)

    #expect(rows.count == 2)
    #expect(rows.map(\.content) == ["c", "b"])
}
