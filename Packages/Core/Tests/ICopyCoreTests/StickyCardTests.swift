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
func insertVerticalDividerKeepsTailInSameRow() {
    var card = StickyCardItem(sections: [StickyCardSection(text: "HelloWorld")])
    let firstID = card.sections[0].id

    let newID = card.insertVerticalDivider(inSectionID: firstID, atOffset: 5)

    #expect(card.sections.count == 2)
    #expect(card.sections[0].text == "Hello")
    #expect(card.sections[1].text == "World")
    #expect(card.sections[0].startsNewRow == true)   // 原分区仍是行首
    #expect(card.sections[1].startsNewRow == false)  // 新分区并入同一行右侧
    #expect(card.rows.count == 1)                     // 两列同处一行
    #expect(card.rows[0].map(\.id) == [firstID, newID])
}

@Test
func insertVerticalDividerSplitsWeightAtCursorFraction() {
    var card = StickyCardItem(sections: [StickyCardSection(text: "HelloWorld")])
    let firstID = card.sections[0].id

    card.insertVerticalDivider(inSectionID: firstID, atOffset: 5, widthFraction: 0.3)

    // 原列权重 1 按 0.3 切分:左 0.3、右 0.7,分隔线落在光标处。
    #expect(abs(card.sections[0].columnWeight - 0.3) < 1e-9)
    #expect(abs(card.sections[1].columnWeight - 0.7) < 1e-9)
}

@Test
func insertVerticalDividerClampsExtremeFraction() {
    var card = StickyCardItem(sections: [StickyCardSection(text: "AB")])
    let id = card.sections[0].id

    card.insertVerticalDivider(inSectionID: id, atOffset: 1, widthFraction: 0.0)

    // 夹紧到 0.12,避免任一列塌缩。
    #expect(abs(card.sections[0].columnWeight - 0.12) < 1e-9)
    #expect(abs(card.sections[1].columnWeight - 0.88) < 1e-9)
}

@Test
func rowsGroupHorizontalAndVerticalSplits() {
    var card = StickyCardItem(sections: [StickyCardSection(text: "A")])
    let a = card.sections[0].id
    let b = card.insertDivider(inSectionID: a, atOffset: 1)!          // 横向:另起一行
    card.setText("BC", sectionID: b)
    _ = card.insertVerticalDivider(inSectionID: b, atOffset: 1)       // 竖向:第二行加一列

    #expect(card.rows.count == 2)
    #expect(card.rows[0].count == 1)
    #expect(card.rows[1].count == 2)
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

// MARK: - 自定义标题

@Test
func setTitleFoldsAndShowOriginalRemembersTitle() {
    var card = StickyCardItem(sections: [StickyCardSection(text: "line1\nline2\nline3")])
    let id = card.sections[0].id

    card.setTitle("摘要", sectionID: id)
    #expect(card.sections[0].isTitleFolded)              // 进入折叠态
    #expect(card.sections[0].displayText == "摘要")       // 折叠后只展示标题
    #expect(card.sections[0].copyableText == "line1\nline2\nline3") // 复制仍为原文

    card.showOriginal(sectionID: id)
    #expect(!card.sections[0].isTitleFolded)             // 退出折叠
    #expect(card.sections[0].displayText == "line1\nline2\nline3")
    #expect(card.sections[0].title == "摘要")             // 标题文本保留,供回填

    card.setTitle("", sectionID: id)
    #expect(!card.sections[0].isTitleFolded)             // 空标题不折叠
}

@Test
func deleteSectionRemovesColumnWithoutMergingText() {
    // 竖向分割出两列,删右列:右列文本整块消失,不并入左列;左列接管其宽度权重。
    var card = StickyCardItem(sections: [StickyCardSection(text: "HelloWorld")])
    let leftID = card.sections[0].id
    let rightID = card.insertVerticalDivider(inSectionID: leftID, atOffset: 5, widthFraction: 0.4)!

    let deleted = card.deleteSection(id: rightID)

    #expect(deleted == true)
    #expect(card.sections.count == 1)
    #expect(card.sections[0].text == "Hello")            // 不合并 "World"
    #expect(card.rows.count == 1)
    #expect(abs(card.sections[0].columnWeight - 1.0) < 1e-9) // 左列接管整段宽度(0.4 + 0.6)
}

@Test
func deleteMiddleColumnKeepsOthersAbsoluteWidthShiftingLeft() {
    // 一行三列(三条分隔线场景);删中间列:其余列保留各自绝对占比、不重分布,使右列左移补位。
    var card = StickyCardItem(sections: [
        StickyCardSection(text: "A", startsNewRow: true, columnWeight: 0.3),
        StickyCardSection(text: "B", startsNewRow: false, columnWeight: 0.3),
        StickyCardSection(text: "C", startsNewRow: false, columnWeight: 0.4)
    ])
    let bID = card.sections[1].id

    card.deleteSection(id: bID)

    #expect(card.sections.map(\.text) == ["A", "C"])
    #expect(card.rows.count == 1)
    #expect(abs(card.sections[0].columnWeight - 0.3) < 1e-9)  // A 宽度不变
    #expect(abs(card.sections[1].columnWeight - 0.4) < 1e-9)  // C 宽度不变(整体左移、右侧留空)
}

@Test
func deleteColumnLeavingSingleColumnRestoresFullWidth() {
    // 两列删其一 → 该行只剩单列 → 恢复满宽(权重 1)。
    var card = StickyCardItem(sections: [
        StickyCardSection(text: "L", startsNewRow: true, columnWeight: 0.4),
        StickyCardSection(text: "R", startsNewRow: false, columnWeight: 0.6)
    ])
    let rID = card.sections[1].id

    card.deleteSection(id: rID)

    #expect(card.sections.count == 1)
    #expect(abs(card.sections[0].columnWeight - 1.0) < 1e-9)
}

@Test
func resizeColumnRedistributesWeightBetweenAdjacentColumns() {
    // 拖动分隔:左列设为 0.2,右列取两列总和的剩余(0.3 + 0.7 − 0.2 = 0.8),总和不变。
    var card = StickyCardItem(sections: [
        StickyCardSection(text: "L", startsNewRow: true, columnWeight: 0.3),
        StickyCardSection(text: "R", startsNewRow: false, columnWeight: 0.7)
    ])

    let ok = card.resizeColumn(leftID: card.sections[0].id, rightID: card.sections[1].id, leftWeight: 0.2)

    #expect(ok)
    #expect(abs(card.sections[0].columnWeight - 0.2) < 1e-9)
    #expect(abs(card.sections[1].columnWeight - 0.8) < 1e-9)
}

@Test
func resizeColumnClampsToOneTenthPercentOfPairTotal() {
    // 拖出范围:左列被夹紧到两列总权重的 0.1%…99.9%,任一列权重保持为正且总和不变。
    var card = StickyCardItem(sections: [
        StickyCardSection(text: "L", startsNewRow: true, columnWeight: 0.5),
        StickyCardSection(text: "R", startsNewRow: false, columnWeight: 0.5)
    ])
    let lID = card.sections[0].id
    let rID = card.sections[1].id

    card.resizeColumn(leftID: lID, rightID: rID, leftWeight: -1.0)
    #expect(abs(card.sections[0].columnWeight - 0.001) < 1e-9)
    #expect(abs(card.sections[1].columnWeight - 0.999) < 1e-9)
    #expect(card.sections[0].columnWeight > 0)
    #expect(card.sections[1].columnWeight > 0)
    #expect(abs(card.sections[0].columnWeight + card.sections[1].columnWeight - 1.0) < 1e-9)

    card.resizeColumn(leftID: lID, rightID: rID, leftWeight: 2.0)
    #expect(abs(card.sections[0].columnWeight - 0.999) < 1e-9)
    #expect(abs(card.sections[1].columnWeight - 0.001) < 1e-9)
    #expect(card.sections[0].columnWeight > 0)
    #expect(card.sections[1].columnWeight > 0)
    #expect(abs(card.sections[0].columnWeight + card.sections[1].columnWeight - 1.0) < 1e-9)
}

@Test
func resizeColumnRejectsNonAdjacentColumns() {
    // 非相邻(或顺序颠倒)的两列不接受重分配。
    var card = StickyCardItem(sections: [
        StickyCardSection(text: "A", startsNewRow: true, columnWeight: 0.3),
        StickyCardSection(text: "B", startsNewRow: false, columnWeight: 0.3),
        StickyCardSection(text: "C", startsNewRow: false, columnWeight: 0.4)
    ])

    let nonAdjacent = card.resizeColumn(leftID: card.sections[0].id, rightID: card.sections[2].id, leftWeight: 0.5)
    let reversed = card.resizeColumn(leftID: card.sections[1].id, rightID: card.sections[0].id, leftWeight: 0.5)
    #expect(!nonAdjacent)
    #expect(!reversed)
}

@Test
func deleteRowRemovesEntireRowIncludingColumns() {
    // 第一行单列;第二行竖分成两列。删第二行的横向分隔 → 整行(两列)移除。
    var card = StickyCardItem(sections: [StickyCardSection(text: "row1")])
    let firstID = card.sections[0].id
    let secondID = card.insertDivider(inSectionID: firstID, atOffset: 4)! // 另起一行
    card.setText("AB", sectionID: secondID)
    _ = card.insertVerticalDivider(inSectionID: secondID, atOffset: 1)    // 第二行加一列

    #expect(card.rows.count == 2)
    let deleted = card.deleteRow(startingAtSectionID: secondID)

    #expect(deleted == true)
    #expect(card.rows.count == 1)
    #expect(card.sections.count == 1)
    #expect(card.sections[0].text == "row1")
}

@Test
func deleteUnknownSectionIsNoop() {
    var card = StickyCardItem(sections: [StickyCardSection(text: "only")])
    #expect(card.deleteSection(id: UUID()) == false)
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
func translationDecodesStoredJSONWithoutWindowLockField() throws {
    let original = StickyCardTranslation(sourceText: "hello", translatedText: "你好", status: .done)
    let data = try JSONEncoder().encode(original)
    var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    object.removeValue(forKey: "isWindowLocked")
    let legacyData = try JSONSerialization.data(withJSONObject: object)

    let decoded = try JSONDecoder().decode(StickyCardTranslation.self, from: legacyData)

    #expect(decoded.sourceText == "hello")
    #expect(decoded.translatedText == "你好")
    #expect(decoded.status == .done)
    #expect(decoded.isWindowLocked == false)
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
