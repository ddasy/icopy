import Foundation
import ICopyCore

public protocol StickyCardStore: Sendable {
    func load() throws -> [StickyCardItem]
    func save(_ cards: [StickyCardItem]) throws
}
