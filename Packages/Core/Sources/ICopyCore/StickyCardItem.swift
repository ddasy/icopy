import CoreGraphics
import Foundation

public enum StickyCardContentMode: String, Codable, Equatable, Hashable, Sendable, CaseIterable {
    case manual      // 手动便签:分隔符切分的独立分区
    case clipboard   // 桌面化的剪贴板历史只读视图
    case translation // 原文→译文的自动翻译卡片
}

public enum StickyCardLockState: String, Codable, Equatable, Hashable, Sendable {
    case unlocked    // 可编辑、可移动、可缩放的浮动窗口
    case locked      // 只读、嵌入桌面,单击复制

    public var isLocked: Bool { self == .locked }

    public mutating func toggle() {
        self = (self == .locked) ? .unlocked : .locked
    }
}

/// 手动卡片中一个可独立复制的分区。稳定 id 在编辑过程中保持不变,供锁定态单击复制按 id 寻址。
/// `startsNewRow` 为 true 时另起一行(横向分隔);为 false 时并入上一分区所在行的右侧(竖向分隔)。
/// `columnWeight` 为同一行内的相对宽度权重(竖向分隔在光标处切分时按比例分配,使分隔线落在光标位置)。
/// `title` 为自定义标题文本(持久保留,即便"显示原文"也不清空,供下次自定义时回填);`showsTitle` 为
/// 是否处于折叠态:折叠时显示单行标题、隐藏原文,但复制仍写原文,标题绝不入剪贴板。
public struct StickyCardSection: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id: UUID
    public var text: String
    public var startsNewRow: Bool
    public var columnWeight: Double
    public var title: String
    public var showsTitle: Bool

    public init(id: UUID = UUID(), text: String = "", startsNewRow: Bool = true, columnWeight: Double = 1, title: String = "", showsTitle: Bool = false) {
        self.id = id
        self.text = text
        self.startsNewRow = startsNewRow
        self.columnWeight = columnWeight
        self.title = title
        self.showsTitle = showsTitle
    }

    public var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 当前是否折叠展示标题(已开启折叠且标题去空白后非空)。
    public var isTitleFolded: Bool {
        showsTitle && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 折叠后展示的文本:折叠态取标题(单行),否则取原文。
    public var displayText: String {
        isTitleFolded ? title : text
    }

    /// 锁定态单击时实际写入剪贴板的文本(去除首尾空白);恒为原文,与标题无关。
    public var copyableText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private enum CodingKeys: String, CodingKey {
        case id, text, startsNewRow, columnWeight, title, showsTitle
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        // 旧数据无这些字段:默认另起一行、等宽、无标题、未折叠,保持既有纵向布局不变。
        startsNewRow = try container.decodeIfPresent(Bool.self, forKey: .startsNewRow) ?? true
        columnWeight = try container.decodeIfPresent(Double.self, forKey: .columnWeight) ?? 1
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        showsTitle = try container.decodeIfPresent(Bool.self, forKey: .showsTitle) ?? false
    }
}

/// 剪贴板卡片到既有剪贴板历史的链接(不复制数据,渲染时投影实时集合)。
public struct StickyCardClipboardSource: Codable, Equatable, Hashable, Sendable {
    public enum Scope: String, Codable, Sendable { case history, favorites, all }

    public var scope: Scope
    public var limit: Int?

    public init(scope: Scope = .history, limit: Int? = nil) {
        self.scope = scope
        self.limit = limit
    }

    /// 纯函数投影:读取实时集合,返回应渲染的行。
    public func resolve(from collection: ClipboardCollection) -> [ClipboardItem] {
        let base: [ClipboardItem]
        switch scope {
        case .history: base = collection.history
        case .favorites: base = collection.favorites
        case .all: base = collection.items
        }
        guard let limit, limit >= 0 else { return base }
        return Array(base.prefix(limit))
    }
}

public enum TranslationLanguage: String, Codable, Equatable, Hashable, Sendable {
    case english
    case chinese
}

public enum TranslationStatus: Codable, Equatable, Hashable, Sendable {
    case idle
    case translating
    case done
    case failed(String)
}

public struct StickyCardTranslation: Codable, Equatable, Hashable, Sendable {
    public var sourceText: String
    public var translatedText: String
    public var status: TranslationStatus
    public var isWindowLocked: Bool

    public init(
        sourceText: String = "",
        translatedText: String = "",
        status: TranslationStatus = .idle,
        isWindowLocked: Bool = false
    ) {
        self.sourceText = sourceText
        self.translatedText = translatedText
        self.status = status
        self.isWindowLocked = isWindowLocked
    }

    private enum CodingKeys: String, CodingKey {
        case sourceText
        case translatedText
        case status
        case isWindowLocked
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sourceText = try container.decode(String.self, forKey: .sourceText)
        translatedText = try container.decode(String.self, forKey: .translatedText)
        status = try container.decode(TranslationStatus.self, forKey: .status)
        isWindowLocked = try container.decodeIfPresent(Bool.self, forKey: .isWindowLocked) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sourceText, forKey: .sourceText)
        try container.encode(translatedText, forKey: .translatedText)
        try container.encode(status, forKey: .status)
        try container.encode(isWindowLocked, forKey: .isWindowLocked)
    }
}

public struct StickyCardItem: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id: UUID
    public var contentMode: StickyCardContentMode
    public var lockState: StickyCardLockState
    public var frame: CGRect
    public var appearance: StickyCardAppearance
    public var sections: [StickyCardSection]                 // 仅 manual;clipboard 为空
    public var clipboardSource: StickyCardClipboardSource?   // 仅 clipboard;manual 为 nil
    public var translation: StickyCardTranslation?           // 仅 translation 非 nil
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        contentMode: StickyCardContentMode = .manual,
        lockState: StickyCardLockState = .unlocked,
        frame: CGRect = StickyCardItem.defaultFrame,
        appearance: StickyCardAppearance = .default,
        sections: [StickyCardSection] = [StickyCardSection()],
        clipboardSource: StickyCardClipboardSource? = nil,
        translation: StickyCardTranslation? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.contentMode = contentMode
        self.lockState = lockState
        self.frame = frame
        self.appearance = appearance
        self.sections = sections
        self.clipboardSource = clipboardSource
        self.translation = translation
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// 新卡片默认尺寸与原点(原点由调用方按层叠规则偏移)。
    public static let defaultFrame = CGRect(x: 120, y: 120, width: 280, height: 360)

    /// 仅用于导出/迁移的分隔符,绝不作为存储格式。
    public static let dividerSentinel = "\n\u{2015}\u{2015}\u{2015}\n"

    public var isLocked: Bool { lockState.isLocked }
    public var isManual: Bool { contentMode == .manual }
    public var isClipboard: Bool { contentMode == .clipboard }
    public var isTranslation: Bool { contentMode == .translation }

    public static func detectTarget(for text: String) -> TranslationLanguage {
        let cjk = text.unicodeScalars.filter { (0x4E00...0x9FFF).contains($0.value) }.count
        let letters = text.unicodeScalars.filter { CharacterSet.letters.contains($0) }.count
        let total = max(letters, 1)
        return Double(cjk) / Double(total) >= 0.3 ? .english : .chinese
    }

    // MARK: - 手动内容业务规则(留在 Core,不下放到视图)

    public mutating func setText(_ text: String, sectionID: StickyCardSection.ID, now: Date = Date()) {
        guard let index = sections.firstIndex(where: { $0.id == sectionID }) else { return }
        sections[index].text = text
        updatedAt = now
    }

    /// 设置自定义标题并进入折叠态(非空时)。标题文本始终保留,供"显示原文"后再次自定义时回填。
    public mutating func setTitle(_ title: String, sectionID: StickyCardSection.ID, now: Date = Date()) {
        guard let index = sections.firstIndex(where: { $0.id == sectionID }) else { return }
        sections[index].title = title
        sections[index].showsTitle = !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        updatedAt = now
    }

    /// 退出折叠态显示原文,但保留标题文本(下次自定义时回填);原文不动。
    public mutating func showOriginal(sectionID: StickyCardSection.ID, now: Date = Date()) {
        guard let index = sections.firstIndex(where: { $0.id == sectionID }) else { return }
        sections[index].showsTitle = false
        updatedAt = now
    }

    /// 在 `sectionID` 内的字符(grapheme)偏移处插入分隔符:偏移前文本留在原分区,
    /// 偏移后文本移入紧随其后的新分区。返回新分区 id(调用方可聚焦它)。
    @discardableResult
    public mutating func insertDivider(
        inSectionID sectionID: StickyCardSection.ID,
        atOffset offset: Int,
        now: Date = Date()
    ) -> StickyCardSection.ID? {
        guard let index = sections.firstIndex(where: { $0.id == sectionID }) else { return nil }
        let text = sections[index].text
        let clamped = max(0, min(offset, text.count))
        let splitIndex = text.index(text.startIndex, offsetBy: clamped)
        let head = String(text[text.startIndex..<splitIndex])
        let tail = String(text[splitIndex...])

        sections[index].text = head
        let newSection = StickyCardSection(text: tail)
        sections.insert(newSection, at: index + 1)
        updatedAt = now
        return newSection.id
    }

    /// 与 `insertDivider` 相同的切分,但尾部文本并入当前分区所在行的右侧(竖向分隔)。返回新分区 id。
    /// `widthFraction` 为光标在该分区当前宽度内的横向占比(0…1):按它把原分区的列宽权重切成左右两份,
    /// 使分隔线落在光标处;夹紧到 [0.12, 0.88] 避免任一列塌缩。
    @discardableResult
    public mutating func insertVerticalDivider(
        inSectionID sectionID: StickyCardSection.ID,
        atOffset offset: Int,
        widthFraction: Double = 0.5,
        now: Date = Date()
    ) -> StickyCardSection.ID? {
        guard let index = sections.firstIndex(where: { $0.id == sectionID }) else { return nil }
        let text = sections[index].text
        let clamped = max(0, min(offset, text.count))
        let splitIndex = text.index(text.startIndex, offsetBy: clamped)
        let head = String(text[text.startIndex..<splitIndex])
        let tail = String(text[splitIndex...])

        let fraction = min(max(widthFraction, 0.12), 0.88)
        let totalWeight = sections[index].columnWeight

        sections[index].text = head
        sections[index].columnWeight = totalWeight * fraction
        let newSection = StickyCardSection(
            text: tail,
            startsNewRow: false,
            columnWeight: totalWeight * (1 - fraction)
        )
        sections.insert(newSection, at: index + 1)
        updatedAt = now
        return newSection.id
    }

    /// 按 `startsNewRow` 把分区分组成行:每行内是横向并排的列(竖向分隔),行间是横向分隔。
    public var rows: [[StickyCardSection]] {
        var result: [[StickyCardSection]] = []
        for section in sections {
            if section.startsNewRow || result.isEmpty {
                result.append([section])
            } else {
                result[result.count - 1].append(section)
            }
        }
        return result
    }

    /// 删除一个分区(连同其文本整块移除,不与相邻分区合并)。删竖向分隔时由"分隔线右侧那一列"调用:
    /// 不把空出的宽度权重重分给任何列——其余列保持各自的绝对占比,因此该列右侧的列与分隔线整体左移补位
    /// (如一行三条分隔线删第二条,第三条移到第二条原位)。被删者若是行首且其后仍有同行列,则把下一列提升
    /// 为新行首,保持该行独立。删后若某行只剩单列,则该列恢复满宽。至少保留一个分区。
    @discardableResult
    public mutating func deleteSection(id: StickyCardSection.ID, now: Date = Date()) -> Bool {
        guard let index = sections.firstIndex(where: { $0.id == id }) else { return false }
        if sections[index].startsNewRow, index + 1 < sections.count, !sections[index + 1].startsNewRow {
            sections[index + 1].startsNewRow = true
        }
        sections.remove(at: index)
        if sections.isEmpty { sections = [StickyCardSection()] }
        if var first = sections.first, !first.startsNewRow {
            first.startsNewRow = true
            sections[0] = first
        }
        normalizeSingleColumnRows()
        updatedAt = now
        return true
    }

    /// 拖动竖向分隔线:在相邻两列(`leftID` 在前、`rightID` 紧随其后)之间重新分配宽度——把左列权重设为
    /// `leftWeight`,右列取两列权重之和的剩余部分。两列权重之和不变(不影响同行其他列与右侧留空),并各自
    /// 夹紧到两列总权重的 0.1%…99.9%,仅保证权重严格 > 0;实用最小宽度由视图侧负责。
    @discardableResult
    public mutating func resizeColumn(
        leftID: StickyCardSection.ID,
        rightID: StickyCardSection.ID,
        leftWeight: Double,
        now: Date = Date()
    ) -> Bool {
        guard let li = sections.firstIndex(where: { $0.id == leftID }),
              let ri = sections.firstIndex(where: { $0.id == rightID }), ri == li + 1 else { return false }
        let total = sections[li].columnWeight + sections[ri].columnWeight
        let minW = total * 0.001
        let clamped = max(minW, min(total - minW, leftWeight))
        sections[li].columnWeight = clamped
        sections[ri].columnWeight = total - clamped
        updatedAt = now
        return true
    }

    /// 单列行恒为满宽(权重 1);多列行保留各自的绝对占比(删列后不重分布,使其后列左移补位)。
    private mutating func normalizeSingleColumnRows() {
        var i = 0
        while i < sections.count {
            var j = i + 1
            while j < sections.count, !sections[j].startsNewRow { j += 1 }
            if j - i == 1 { sections[i].columnWeight = 1 }
            i = j
        }
    }

    /// 删除从 `id`(某行首列)起的一整行,含其所有横向列。删横向分隔时由"分隔线下方那一行的首列"调用,
    /// 整行(及其文本)被移除,不与上一行合并。至少保留一个分区。
    @discardableResult
    public mutating func deleteRow(startingAtSectionID id: StickyCardSection.ID, now: Date = Date()) -> Bool {
        guard let start = sections.firstIndex(where: { $0.id == id }) else { return false }
        var end = start + 1
        while end < sections.count, !sections[end].startsNewRow { end += 1 }
        sections.removeSubrange(start..<end)
        if sections.isEmpty { sections = [StickyCardSection()] }
        if var first = sections.first, !first.startsNewRow {
            first.startsNewRow = true
            sections[0] = first
        }
        normalizeSingleColumnRows()
        updatedAt = now
        return true
    }

    /// 把各分区拼回单一字符串(导出/迁移用),分隔符默认为 `dividerSentinel`。
    public func flattenedText(separator: String = StickyCardItem.dividerSentinel) -> String {
        sections.map(\.text).joined(separator: separator)
    }

    public mutating func setLock(_ state: StickyCardLockState, now: Date = Date()) {
        lockState = state
        updatedAt = now
    }

    public mutating func setFrame(_ frame: CGRect, now: Date = Date()) {
        self.frame = frame
        updatedAt = now
    }

    public mutating func setAppearance(_ appearance: StickyCardAppearance, now: Date = Date()) {
        self.appearance = appearance
        updatedAt = now
    }
}
