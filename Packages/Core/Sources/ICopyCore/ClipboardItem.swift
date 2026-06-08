import Foundation

public struct ClipboardItem: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id: UUID
    public var title: String?
    public var content: String
    public var createdAt: Date
    public var lastCopiedAt: Date
    public var isFavorite: Bool

    public init(
        id: UUID = UUID(),
        title: String? = nil,
        content: String,
        createdAt: Date = Date(),
        lastCopiedAt: Date = Date(),
        isFavorite: Bool = false
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.createdAt = createdAt
        self.lastCopiedAt = lastCopiedAt
        self.isFavorite = isFavorite
    }

    public var displayTitle: String {
        let normalizedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalizedTitle?.isEmpty == false ? normalizedTitle! : preview
    }

    public var preview: String {
        content
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
