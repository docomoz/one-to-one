import Foundation
import Testing
import Core
@testable import MovieAPI

/// Каталог, который отвечает заранее заданными фильмами и запоминает, что у него спросили.
private final class FakeCatalog: MovieCatalog, @unchecked Sendable {
    var similar: [Int: [Movie]] = [:]
    var discovered: [Movie] = []
    var failing = false
    private let lock = NSLock()
    private var _asked: [Int] = []
    var asked: [Int] { lock.withLock { _asked } }

    func search(_ query: String) async throws -> [Movie] { [] }
    func recommendations(for id: Int) async throws -> [Movie] {
        lock.withLock { _asked.append(id) }
        if failing { throw URLError(.notConnectedToInternet) }
        return similar[id] ?? []
    }
    func discover(genres: [String]) async throws -> [Movie] {
        if failing { throw URLError(.notConnectedToInternet) }
        return discovered
    }
    private var _refills = 0
    var refills: Int { lock.withLock { _refills } }
    func refillIfNeeded() async { lock.withLock { _refills += 1 } }
}

private func movie(_ id: Int, _ genres: [String] = ["комедия"]) -> Movie {
    Movie(id: id, title: "Фильм \(id)", year: 2020, genres: genres, overview: "", posterURL: nil)
}

@Test func recommendationsComeFromSeedsThenDiscover() async {
    let catalog = FakeCatalog()
    catalog.similar = [1: [movie(10)], 2: [movie(20)]]
    catalog.discovered = [movie(30)]

    let movies = await DeckLoader.recommendations(seeds: [1, 2], mood: .laugh, catalog: catalog)

    #expect(movies.map(\.id) == [10, 20, 30])
    #expect(Set(catalog.asked) == [1, 2])
}

@Test func networkDownGivesNoRecommendations() async {
    let catalog = FakeCatalog()
    catalog.failing = true

    let movies = await DeckLoader.recommendations(seeds: [1], mood: .laugh, catalog: catalog)

    #expect(movies.isEmpty)
}

@Test func oneFailedRequestKeepsTheRest() async throws {
    let (session, _) = try StubURLProtocol.session(body: Data("сломано".utf8),
                                                    routes: ["genres.name": "discover"])
    let kinopoisk = KinopoiskCatalog(apiKey: "test-key", session: session)

    let movies = await DeckLoader.recommendations(seeds: [301], mood: .laugh, catalog: kinopoisk)

    // «Похожие» пришли битыми, а подборка по жанрам из образца ответа дошла.
    #expect(!movies.isEmpty)
}

@Test func deckFromSavedKinopoiskResponses() async throws {
    let (session, stub) = try StubURLProtocol.session(routes: ["similarMovies": "similar",
                                                              "genres.name": "discover"])
    let kinopoisk = KinopoiskCatalog(apiKey: "test-key", session: session)

    let movies = await DeckLoader.recommendations(seeds: [301], mood: .light, catalog: kinopoisk)

    #expect(movies.prefix(3).map(\.title) == ["Начало", "Эквилибриум", "Тринадцатый этаж"])
    #expect(movies.contains { $0.title == "Зверополис" })
    #expect(stub.requests.count == 2)
}

@Test func refillRequestedWithRecommendations() async {
    let catalog = FakeCatalog()

    _ = await DeckLoader.recommendations(seeds: [1], mood: .laugh, catalog: catalog)

    #expect(catalog.refills == 1)
}
