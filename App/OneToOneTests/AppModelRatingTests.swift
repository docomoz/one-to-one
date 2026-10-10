import Core
import Foundation
import MovieAPI
import Testing
@testable import OneToOne

private let man = Person(name: "Макс", sex: .male)
private let woman = Person(name: "Даша", sex: .female)
private let disliked = 5

private func comedy(_ id: Int) -> Movie {
    Movie(id: id, title: "Фильм \(id)", year: 2020, genres: ["комедия"], overview: "", posterURL: nil)
}

/// Каталог: подборка по жанрам — комедии 2 и 3, «похожие» на фильм 5 — фильм 2 (или что передали).
/// «Похожие» можно выключить (нет сети), запросы считаются.
private final class SimilarCatalog: MovieCatalog, @unchecked Sendable {
    private let lock = NSLock()
    private var _online: Bool
    private var _asked: [Int] = []
    private let similarToDisliked: [Movie]
    init(online: Bool = true, similarToDisliked: [Movie] = [comedy(2)]) {
        _online = online
        self.similarToDisliked = similarToDisliked
    }
    func goOnline() { lock.withLock { _online = true } }
    var asked: [Int] { lock.withLock { _asked } }

    func search(_ query: String) async throws -> [Movie] { [] }
    func recommendations(for id: Int) async throws -> [Movie] {
        let online = lock.withLock { _asked.append(id); return _online }
        guard online else { throw URLError(.notConnectedToInternet) }
        return id == disliked ? similarToDisliked : []
    }
    func discover(genres: [String]) async throws -> [Movie] { [comedy(2), comedy(3)] }
}

@MainActor
private func model(me: Person?, _ change: (inout AppData) -> Void = { _ in }) -> (AppModel, InMemoryStore) {
    var data = AppData()
    data.couple = try! Couple.make(man, woman)
    data.meID = me?.id
    change(&data)
    let store = InMemoryStore(data)
    return (AppModel(store: store), store)
}

@MainActor
@Test func rateSaves() throws {
    let (model, store) = model(me: man)

    model.rate(movieID: 1, .like)

    #expect(try store.load().ratings.map(\.verdict) == [.like])
    #expect(try store.load().ratings.map(\.personID) == [man.id])
}

@MainActor
@Test func deckDropsSimilarToDisliked() async throws {
    let (model, _) = model(me: man)
    model.rate(movieID: disliked, .dislike)
    let session = try #require(model.startPick(mood: .laugh))

    #expect(await model.deck(for: session, catalog: SimilarCatalog()).map(\.id) == [3])
}

@MainActor
@Test func dislikeFilterAskedOncePerPick() async throws {
    let (model, _) = model(me: man)
    model.rate(movieID: disliked, .dislike)
    let session = try #require(model.startPick(mood: .laugh))
    let catalog = SimilarCatalog()

    _ = await model.deck(for: session, catalog: catalog)
    _ = await model.deck(for: session, catalog: catalog)

    #expect(catalog.asked.filter { $0 == disliked }.count == 1)
}

@MainActor
@Test func dislikeFilterRetriesAfterNoNetwork() async throws {
    let (model, _) = model(me: man)
    model.rate(movieID: disliked, .dislike)
    let session = try #require(model.startPick(mood: .laugh))
    let catalog = SimilarCatalog(online: false)

    #expect(await model.deck(for: session, catalog: catalog).map(\.id) == [2, 3])
    catalog.goOnline()

    #expect(await model.deck(for: session, catalog: catalog).map(\.id) == [3])
}

@MainActor
@Test func movieToRateNextDay() {
    let (model, _) = model(me: man) {
        $0.movieCache[1] = comedy(1)
        $0.markWatched(movieID: 1, at: .now.addingTimeInterval(-2 * 86400))
    }

    #expect(model.movieToRate == comedy(1))
}

@MainActor
@Test func movieToRateWithoutMeIsNil() {
    let (model, _) = model(me: nil) {
        $0.movieCache[1] = comedy(1)
        $0.markWatched(movieID: 1, at: .now.addingTimeInterval(-2 * 86400))
    }

    #expect(model.movieToRate == nil)
}

@MainActor
@Test func dislikeWithoutSimilarAskedOncePerPick() async throws {
    let (model, _) = model(me: man)
    model.rate(movieID: disliked, .dislike)
    let session = try #require(model.startPick(mood: .laugh))
    let catalog = SimilarCatalog(similarToDisliked: [])

    _ = await model.deck(for: session, catalog: catalog)
    _ = await model.deck(for: session, catalog: catalog)

    #expect(catalog.asked.filter { $0 == disliked }.count == 1)
}
