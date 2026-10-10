import Core
import Foundation
import Testing
@testable import OneToOne

private let film = Movie(id: 1, title: "Амели", year: 2001, genres: ["комедия"], overview: "", posterURL: nil)

@MainActor
@Test func addToWatchlistSavesToMyList() throws {
    let me = UUID()
    var data = AppData()
    data.meID = me
    let store = InMemoryStore(data)
    let model = AppModel(store: store)

    model.addToWatchlist(film)

    let saved = try #require(try store.load().watchlist.first)
    #expect(saved.movie == film)
    #expect(saved.ownerID == me)
    #expect(saved.fromLater == false)
    #expect(model.isInMyWatchlist(movieID: 1))
}

@MainActor
@Test func removeFromWatchlistSaves() throws {
    var data = AppData()
    data.meID = UUID()
    let store = InMemoryStore(data)
    let model = AppModel(store: store)
    model.addToWatchlist(film)

    model.removeFromWatchlist(movieID: 1)

    #expect(try store.load().watchlist.isEmpty)
    #expect(!model.isInMyWatchlist(movieID: 1))
}

@MainActor
@Test func addToWatchlistWithoutMeDoesNothing() throws {
    let store = InMemoryStore()
    let model = AppModel(store: store)

    model.addToWatchlist(film)

    #expect(try store.load().watchlist.isEmpty)
}
