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

/// Каталог, который считает запросы: у Кинопоиска всего 200 в день.
private final class CountingCatalog: MovieCatalog, @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    var requests: Int { lock.withLock { count } }

    func search(_ query: String) async throws -> [Movie] { [] }
    func recommendations(for id: Int) async throws -> [Movie] { lock.withLock { count += 1 }; return [] }
    func discover(genres: [String]) async throws -> [Movie] {
        lock.withLock { count += 1 }
        return [Movie(id: 2, title: "Брат", year: 1997, genres: ["комедия"], overview: "", posterURL: nil)]
    }
}

@MainActor
@Test func deckAsksCatalogOncePerPick() async throws {
    let (model, _) = model(me: man)
    let catalog = CountingCatalog()
    let session = try #require(model.startPick(mood: .laugh))

    _ = await model.deck(for: session, catalog: catalog)
    let afterFirst = catalog.requests
    model.swipe(.no, movie: film, in: session)
    let again = await model.deck(for: session, catalog: catalog)

    #expect(afterFirst > 0)
    #expect(catalog.requests == afterFirst)
    #expect(again.map(\.id) == [2])
}

/// Каталог без сети в первый раз и с сетью потом.
private final class OfflineThenOnlineCatalog: MovieCatalog, @unchecked Sendable {
    private let lock = NSLock()
    private var online = false
    func goOnline() { lock.withLock { online = true } }

    func search(_ query: String) async throws -> [Movie] { [] }
    func recommendations(for id: Int) async throws -> [Movie] { [] }
    func discover(genres: [String]) async throws -> [Movie] {
        guard lock.withLock({ online }) else { throw URLError(.notConnectedToInternet) }
        return [Movie(id: 2, title: "Брат", year: 1997, genres: ["комедия"], overview: "", posterURL: nil)]
    }
}

@MainActor
@Test func deckRetriesAfterNoNetwork() async throws {
    let (model, _) = model(me: man)
    let catalog = OfflineThenOnlineCatalog()
    let session = try #require(model.startPick(mood: .laugh))

    #expect(await model.deck(for: session, catalog: catalog).isEmpty)
    catalog.goOnline()

    #expect(await model.deck(for: session, catalog: catalog).map(\.id) == [2])
}

/// Каталог с фильмами на телефоне: в сети отдаёт комедию 2, на телефоне всегда есть комедия 7.
private final class LocalAwareCatalog: MovieCatalog, @unchecked Sendable {
    private let lock = NSLock()
    private var _online: Bool
    init(online: Bool) { _online = online }
    func goOnline() { lock.withLock { _online = true } }

    func search(_ query: String) async throws -> [Movie] { [] }
    func recommendations(for id: Int) async throws -> [Movie] { [] }
    func discover(genres: [String]) async throws -> [Movie] {
        guard lock.withLock({ _online }) else { throw URLError(.notConnectedToInternet) }
        return [Movie(id: 2, title: "Брат", year: 1997, genres: ["комедия"], overview: "", posterURL: nil)]
    }
    func localMovies(genres: [String]) async -> [Movie] {
        [Movie(id: 7, title: "Паддингтон", year: 2014, genres: ["комедия"], overview: "", posterURL: nil)]
    }
}

@MainActor
@Test func deckAddsLocalMoviesOffline() async throws {
    let (model, _) = model(me: man)
    let session = try #require(model.startPick(mood: .laugh))

    #expect(await model.deck(for: session, catalog: LocalAwareCatalog(online: false)).map(\.id) == [7])
}

@MainActor
@Test func deckLocalAfterNetwork() async throws {
    let (model, _) = model(me: man)
    let session = try #require(model.startPick(mood: .laugh))

    #expect(await model.deck(for: session, catalog: LocalAwareCatalog(online: true)).map(\.id) == [2, 7])
}

@MainActor
@Test func localMoviesNotCachedAsRecommendations() async throws {
    let (model, _) = model(me: man)
    let catalog = LocalAwareCatalog(online: false)
    let session = try #require(model.startPick(mood: .laugh))
    _ = await model.deck(for: session, catalog: catalog)

    catalog.goOnline()

    #expect(await model.deck(for: session, catalog: catalog).map(\.id) == [2, 7])
}
