import Foundation
import Testing
@testable import ICopyCore

@Test
func recordMovesDuplicateToFrontWithoutLosingFavorite() {
    var collection = ClipboardCollection(maxHistoryCount: 10)

    collection.record("first", now: Date(timeIntervalSince1970: 1))
    let firstID = collection.items[0].id
    collection.toggleFavorite(id: firstID)
    collection.record("second", now: Date(timeIntervalSince1970: 2))
    collection.record("first", now: Date(timeIntervalSince1970: 3))

    #expect(collection.items.map(\.content) == ["first", "second"])
    #expect(collection.items[0].isFavorite)
}

@Test
func clearHistoryKeepsFavorites() {
    var collection = ClipboardCollection(maxHistoryCount: 10)

    collection.record("favorite")
    let favoriteID = collection.items[0].id
    collection.toggleFavorite(id: favoriteID)
    collection.record("history")
    collection.clearHistoryKeepingFavorites()

    #expect(collection.items.map(\.content) == ["favorite"])
}

@Test
func renameStoresTrimmedTitle() {
    var collection = ClipboardCollection(maxHistoryCount: 10)
    collection.record("long clipboard content")
    let id = collection.items[0].id

    collection.rename(id: id, title: "  short title  ")

    #expect(collection.items[0].title == "short title")
    #expect(collection.items[0].displayTitle == "short title")
}

@Test
func renameWithTitleMarksItemAsFavorite() {
    var collection = ClipboardCollection(maxHistoryCount: 10)
    collection.record("long clipboard content")
    let id = collection.items[0].id

    collection.rename(id: id, title: "saved title")

    #expect(collection.items[0].isFavorite)
    #expect(collection.favorites.map(\.id) == [id])
}
