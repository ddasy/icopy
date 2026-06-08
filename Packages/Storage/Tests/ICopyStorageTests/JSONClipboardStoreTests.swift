import Foundation
import ICopyCore
import Testing
@testable import ICopyStorage

@Test
func jsonStoreRoundTripsItems() throws {
    let fileURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathComponent("items.json")
    let store = JSONClipboardStore(fileURL: fileURL)
    let items = [
        ClipboardItem(content: "hello", createdAt: Date(timeIntervalSince1970: 1), lastCopiedAt: Date(timeIntervalSince1970: 2), isFavorite: true)
    ]

    try store.save(items)
    let loaded = try store.load()

    #expect(loaded == items)
}

@Test
func jsonStoreLoadsItemsWithoutTitle() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let fileURL = directory.appendingPathComponent("items.json")
    try """
    [
      {
        "content": "legacy",
        "createdAt": "1970-01-01T00:00:01Z",
        "id": "00000000-0000-0000-0000-000000000001",
        "isFavorite": false,
        "lastCopiedAt": "1970-01-01T00:00:02Z"
      }
    ]
    """.write(to: fileURL, atomically: true, encoding: .utf8)

    let loaded = try JSONClipboardStore(fileURL: fileURL).load()

    #expect(loaded[0].title == nil)
    #expect(loaded[0].displayTitle == "legacy")
}
