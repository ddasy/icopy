import Foundation
import ICopyCore

public protocol ClipboardStore: Sendable {
    func load() throws -> [ClipboardItem]
    func save(_ items: [ClipboardItem]) throws
}
