import CoreGraphics
import Foundation
import ICopyCore
import Testing
@testable import ICopyStorage

@Test
func stickyStoreRoundTripsManualAndClipboardCards() throws {
    let fileURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathComponent("desktop-cards.json")
    let store = JSONStickyCardStore(fileURL: fileURL)

    let manual = StickyCardItem(
        contentMode: .manual,
        lockState: .locked,
        frame: CGRect(x: 10, y: 20, width: 280, height: 360),
        sections: [StickyCardSection(text: "alpha"), StickyCardSection(text: "beta")],
        createdAt: Date(timeIntervalSince1970: 1),
        updatedAt: Date(timeIntervalSince1970: 2)
    )
    let clipboard = StickyCardItem(
        contentMode: .clipboard,
        sections: [],
        clipboardSource: StickyCardClipboardSource(scope: .history, limit: 5),
        createdAt: Date(timeIntervalSince1970: 3),
        updatedAt: Date(timeIntervalSince1970: 4)
    )

    try store.save([manual, clipboard])
    let loaded = try store.load()

    #expect(loaded == [manual, clipboard])
}

@Test
func stickyStoreReturnsEmptyForMissingFile() throws {
    let fileURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathComponent("missing.json")

    let loaded = try JSONStickyCardStore(fileURL: fileURL).load()

    #expect(loaded.isEmpty)
}

@Test
func stickyStoreReturnsEmptyForTruncatedFile() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let fileURL = directory.appendingPathComponent("desktop-cards.json")
    try Data().write(to: fileURL) // 0 字节截断写

    let loaded = try JSONStickyCardStore(fileURL: fileURL).load()

    #expect(loaded.isEmpty)
}
