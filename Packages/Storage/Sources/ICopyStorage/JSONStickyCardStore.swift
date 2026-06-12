import Foundation
import ICopyCore

public struct JSONStickyCardStore: StickyCardStore {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(fileURL: URL = Self.defaultFileURL()) {
        self.fileURL = fileURL
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    public func load() throws -> [StickyCardItem] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }

        let data = try Data(contentsOf: fileURL)
        // 卡片文件随拖动/缩放/外观频繁重写;0 字节(截断写)降级为空,避免下次启动抛错抹掉所有卡片。
        guard !data.isEmpty else { return [] }
        return try decoder.decode([StickyCardItem].self, from: data)
    }

    public func save(_ cards: [StickyCardItem]) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try encoder.encode(cards)
        try data.write(to: fileURL, options: [.atomic])
    }

    public static func defaultFileURL() -> URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return baseURL
            .appendingPathComponent("iCopy", isDirectory: true)
            .appendingPathComponent("desktop-cards.json")
    }
}
