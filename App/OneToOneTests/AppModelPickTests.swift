import Core
import Foundation
import MovieAPI
import Testing
@testable import OneToOne

private let man = Person(name: "Макс", sex: .male)
private let woman = Person(name: "Даша", sex: .female)
private let film = Movie(id: 1, title: "Амели", year: 2001, genres: ["комедия"], overview: "", posterURL: nil)

/// Каталог без сети: на всё отвечает одним фильмом.
private struct OneMovieCatalog: MovieCatalog {
    func search(_ query: String) async throws -> [Movie] { [] }
    func recommendations(for id: Int) async throws -> [Movie] { [] }
    func discover(genres: [String]) async throws -> [Movie] {
        [Movie(id: 2, title: "Брат", year: 1997, genres: ["комедия"], overview: "", posterURL: nil)]
    }
}

@MainActor
private func model(me: Person) -> (AppModel, InMemoryStore) {
    var data = AppData()
    data.couple = try! Couple.make(man, woman)
    data.meID = me.id
    let store = InMemoryStore(data)
    return (AppModel(store: store), store)
}

@MainActor
@Test func startPickSaves() throws {
    let (model, store) = model(me: man)

    let session = try #require(model.startPick(mood: .laugh))

    #expect(try store.load().sessions == [session])
    #expect(session.startedBy == man.id)
}

@MainActor
@Test func swipeSavesAndReportsMatch() throws {
    let (model, store) = model(me: man)
    let session = try #require(model.startPick(mood: .laugh))
    model.update { $0.swipe(.yes, movie: film, in: session, by: woman.id, at: .now) }

    #expect(model.swipe(.yes, movie: film, in: session))
    #expect(try store.load().swipes.count == 2)
    #expect(model.matches(in: session) == [1])
}

@MainActor
@Test func laterSwipeGoesToMyList() throws {
    let (model, _) = model(me: woman)
    let session = try #require(model.startPick(mood: .laugh))

    model.swipe(.later, movie: film, in: session)

    #expect(model.data.watchlist(of: woman.id).map(\.fromLater) == [true])
}

@MainActor
@Test func markWatchedSavesAndLeavesDeck() async throws {
    let (model, store) = model(me: man)
    model.addToWatchlist(film)
    let session = try #require(model.startPick(mood: .laugh))

    model.markWatched(movieID: 1)

    #expect(try store.load().watched == [1])
    #expect(await model.deck(for: session, catalog: OneMovieCatalog()).map(\.id) == [2])
}

@MainActor
@Test func startPickWithoutMeDoesNothing() throws {
    let store = InMemoryStore()
    let model = AppModel(store: store)

    #expect(model.startPick(mood: .laugh) == nil)
    #expect(try store.load().sessions.isEmpty)
}
