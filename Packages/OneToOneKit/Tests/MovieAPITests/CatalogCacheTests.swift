import Foundation
import Testing
import Core
@testable import MovieAPI

private func movie(_ id: Int, _ genres: [String] = ["комедия"], kp: Double? = nil) -> Movie {
    Movie(id: id, title: "Фильм \(id)", year: 2020, genres: genres, overview: "", posterURL: nil,
          ratings: Ratings(kinopoisk: kp))
}

private func at(_ seconds: Double) -> Date { Date(timeIntervalSince1970: seconds) }

private func tempURL() -> URL {
    FileManager.default.temporaryDirectory.appending(path: "catalog-\(UUID().uuidString).json")
}

@Test func baseLoadsBundledFile() throws {
    // В репозитории база может быть пустой, пока не запустили скрипт: главное — файл есть и читается.
    let url = try #require(BaseCatalog.bundledURL)
    #expect(BaseCatalog.load(from: url) == (try JSONDecoder().decode([Movie].self, from: Data(contentsOf: url))))
}

@Test func baseLoadsMovies() throws {
    let url = tempURL()
    try JSONEncoder().encode([movie(1), movie(2)]).write(to: url)

    #expect(BaseCatalog.load(from: url).map(\.id) == [1, 2])
}

@Test func baseMissingFileIsEmpty() {
    #expect(BaseCatalog.load(from: tempURL()).isEmpty)
    #expect(BaseCatalog.load(from: nil).isEmpty)
}

@Test func addReplacesWithoutDuplicates() {
    var cache = CatalogCache()
    cache.add([movie(1, kp: 7)], at: at(10))
    cache.add([movie(1, kp: 8)], at: at(20))

    #expect(cache.entries.count == 1)
    #expect(cache.entries[1]?.movie.ratings.kinopoisk == 8)
    #expect(cache.entries[1]?.addedAt == at(10))
}

@Test func addEvictsOldest() {
    var cache = CatalogCache()
    cache.add([movie(1)], at: at(10), limit: 2)
    cache.add([movie(2)], at: at(20), limit: 2)
    cache.add([movie(3)], at: at(30), limit: 2)

    #expect(Set(cache.entries.keys) == [2, 3])
}

@Test func moviesFilterByGenreAndSortByRating() {
    var cache = CatalogCache()
    cache.add([movie(1, kp: 7), movie(2, kp: nil), movie(3, kp: 8), movie(4, ["драма"], kp: 9)], at: at(10))

    #expect(cache.movies(genres: ["комедия"], base: []).map(\.id) == [3, 1, 2])
}

@Test func moviesRespectLimit() {
    var cache = CatalogCache()
    cache.add((1...50).map { movie($0, kp: Double($0) / 10) }, at: at(10))

    #expect(cache.movies(genres: ["комедия"], base: []).count == 40)
    #expect(cache.movies(genres: ["комедия"], base: [], limit: 3).map(\.id) == [50, 49, 48])
}

@Test func cacheOverridesBase() {
    var cache = CatalogCache()
    cache.add([movie(1, kp: 9)], at: at(10))

    let movies = cache.movies(genres: ["комедия"], base: [movie(1, kp: 5), movie(2, kp: 6)])

    #expect(movies.map(\.id) == [1, 2])
    #expect(movies.first?.ratings.kinopoisk == 9)
}

@Test func emptyBaseUsesCacheOnly() {
    var cache = CatalogCache()
    cache.add([movie(1)], at: at(10))

    #expect(cache.movies(genres: ["комедия"], base: []).map(\.id) == [1])
    #expect(CatalogCache().movies(genres: ["комедия"], base: []).isEmpty)
}

@Test func cacheFileRoundTrip() {
    let file = CatalogCacheFile(url: tempURL())
    var cache = CatalogCache()
    cache.add([movie(1)], at: at(10))
    cache.lastRefill = DayKey(year: 2026, month: 10, day: 10)
    cache.nextTopPage = 7

    file.save(cache)

    #expect(file.load() == cache)
}

@Test func unreadableCacheStartsEmpty() throws {
    let url = tempURL()
    try Data("мусор".utf8).write(to: url)

    #expect(CatalogCacheFile(url: url).load() == CatalogCache())
    #expect(CatalogCacheFile(url: tempURL()).load() == CatalogCache())
}
