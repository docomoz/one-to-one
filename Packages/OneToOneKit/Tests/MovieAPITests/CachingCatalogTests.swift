import Foundation
import Testing
import Core
@testable import MovieAPI

private func movie(_ id: Int, _ genres: [String] = ["комедия"]) -> Movie {
    Movie(id: id, title: "Фильм \(id)", year: 2026, genres: genres, overview: "", posterURL: nil)
}

/// Кинопоиск понарошку: отвечает заданными фильмами, считает запросы, может «упасть».
private final class FakeRemote: MovieCatalog, MovieFeed, @unchecked Sendable {
    private let lock = NSLock()
    private var _failing = false
    private var _topPages: [Int] = []
    private var _years: [Int] = []
    var topResult = [movie(100)]
    var failing: Bool {
        get { lock.withLock { _failing } }
        set { lock.withLock { _failing = newValue } }
    }
    var topPages: [Int] { lock.withLock { _topPages } }
    var years: [Int] { lock.withLock { _years } }

    private func check() throws { if failing { throw KinopoiskError.unauthorized } }

    func search(_ query: String) async throws -> [Movie] { try check(); return [movie(1)] }
    func recommendations(for id: Int) async throws -> [Movie] { try check(); return [movie(2)] }
    func discover(genres: [String]) async throws -> [Movie] { try check(); return [movie(3)] }
    func top(page: Int) async throws -> [Movie] {
        lock.withLock { _topPages.append(page) }
        try check()
        return topResult
    }
    func newReleases(year: Int) async throws -> [Movie] {
        lock.withLock { _years.append(year) }
        try check()
        return [movie(200)]
    }
}

/// Часы, которые тест двигает сам.
private final class Clock: @unchecked Sendable {
    private let lock = NSLock()
    private var _now = DateComponents(calendar: .current, year: 2026, month: 10, day: 10, hour: 12).date!
    var now: Date { lock.withLock { _now } }
    func nextDay() { lock.withLock { _now = _now.addingTimeInterval(24 * 3600) } }
}

private func tempFile() -> CatalogCacheFile {
    CatalogCacheFile(url: FileManager.default.temporaryDirectory.appending(path: "caching-\(UUID().uuidString).json"))
}

private func catalog(_ remote: FakeRemote, file: CatalogCacheFile = tempFile(), clock: Clock = Clock(),
                     base: [Movie] = []) -> CachingCatalog {
    CachingCatalog(remote: remote, file: file, base: base, now: { clock.now })
}

@Test func searchResultsGoToCache() async throws {
    let catalog = catalog(FakeRemote())

    #expect(try await catalog.search("амели").map(\.id) == [1])
    #expect(await catalog.localMovies(genres: ["комедия"]).map(\.id) == [1])
}

@Test func recommendationsAndDiscoverGoToCache() async throws {
    let catalog = catalog(FakeRemote())

    _ = try await catalog.recommendations(for: 5)
    _ = try await catalog.discover(genres: ["комедия"])

    #expect(await catalog.localMovies(genres: ["комедия"]).map(\.id) == [2, 3])
}

@Test func failedRequestThrowsAndKeepsCache() async throws {
    let remote = FakeRemote()
    let catalog = catalog(remote)
    _ = try await catalog.search("амели")
    remote.failing = true

    await #expect(throws: KinopoiskError.self) { try await catalog.discover(genres: ["комедия"]) }
    #expect(await catalog.localMovies(genres: ["комедия"]).map(\.id) == [1])
}

@Test func refillOncePerDay() async {
    let remote = FakeRemote()
    let clock = Clock()
    let catalog = catalog(remote, clock: clock)

    await catalog.refillIfNeeded()
    await catalog.refillIfNeeded()
    #expect(remote.topPages == [4])
    #expect(remote.years == [2026])
    #expect(await catalog.localMovies(genres: ["комедия"]).map(\.id) == [100, 200])

    clock.nextDay()
    await catalog.refillIfNeeded()
    clock.nextDay()
    await catalog.refillIfNeeded()
    #expect(remote.topPages == [4, 5, 6])
}

@Test func refillFailureKeepsDate() async {
    let remote = FakeRemote()
    remote.failing = true
    let file = tempFile()
    let catalog = catalog(remote, file: file)

    await catalog.refillIfNeeded()
    #expect(file.load().lastRefill == nil)
    #expect(file.load().nextTopPage == 4)

    remote.failing = false
    await catalog.refillIfNeeded()
    #expect(remote.topPages == [4, 4])
    #expect(file.load().nextTopPage == 5)
    #expect(file.load().lastRefill != nil)
}

@Test func emptyTopPageWrapsToFirst() async {
    let remote = FakeRemote()
    remote.topResult = []
    let file = tempFile()

    await catalog(remote, file: file).refillIfNeeded()

    #expect(file.load().nextTopPage == 1)
}

@Test func cacheSurvivesRestart() async throws {
    let file = tempFile()
    _ = try await catalog(FakeRemote(), file: file).search("амели")

    let restarted = catalog(FakeRemote(), file: file)

    #expect(await restarted.localMovies(genres: ["комедия"]).map(\.id) == [1])
}

@Test func localMoviesIncludeBase() async {
    let catalog = catalog(FakeRemote(), base: [movie(9), movie(10, ["драма"])])

    #expect(await catalog.localMovies(genres: ["комедия"]).map(\.id) == [9])
}

/// Обычный каталог без кэша: локальных фильмов нет, догружать нечего.
private struct PlainCatalog: MovieCatalog {
    func search(_ query: String) async throws -> [Movie] { [] }
    func recommendations(for id: Int) async throws -> [Movie] { [] }
    func discover(genres: [String]) async throws -> [Movie] { [] }
}

@Test func defaultLocalMoviesEmpty() async {
    await PlainCatalog().refillIfNeeded()
    #expect(await PlainCatalog().localMovies(genres: ["комедия"]).isEmpty)
}
