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
public struct StickyCardSection: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id: UUID
    public var text: String

    public init(id: UUID = UUID(), text: String = "") {
        self.id = id
        self.text = text
    }

    public var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 锁定态单击时实际写入剪贴板的文本(去除首尾空白)。
    public var copyableText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
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

    public init(sourceText: String = "", translatedText: String = "", status: TranslationStatus = .idle) {
        self.sourceText = sourceText
        self.translatedText = translatedText
        self.status = status
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

    /// 通过把 `sectionID` 合并进其前一分区,移除它之前的分隔符。
    public mutating func removeDivider(beforeSectionID sectionID: StickyCardSection.ID, now: Date = Date()) {
        guard let index = sections.firstIndex(where: { $0.id == sectionID }), index > 0 else { return }
        sections[index - 1].text += sections[index].text
        sections.remove(at: index)
        updatedAt = now
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
