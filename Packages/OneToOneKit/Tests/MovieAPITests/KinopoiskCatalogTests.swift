import Foundation
import Testing
import Core
@testable import MovieAPI

struct KinopoiskCatalogTests {
    private func catalog(status: Int = 200, fixture: String? = nil,
                         body: Data = Data()) throws -> (KinopoiskCatalog, StubURLProtocol.Stub) {
        let (session, stub) = try StubURLProtocol.session(status: status, fixture: fixture, body: body)
        return (KinopoiskCatalog(apiKey: "test-key", session: session), stub)
    }

    private func query(_ stub: StubURLProtocol.Stub) throws -> [URLQueryItem] {
        let url = try #require(stub.lastURL)
        return URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
    }

    @Test func parsesSearch() async throws {
        let (catalog, _) = try catalog(fixture: "search")
        let movies = try await catalog.search("матрица")

        let matrix = try #require(movies.first)
        #expect(matrix.id == 301)
        #expect(matrix.title == "Матрица")
        #expect(matrix.year == 1999)
        #expect(matrix.genres == ["фантастика", "боевик"])
        #expect(matrix.overview.hasPrefix("Хакер Нео"))
        #expect(matrix.posterURL?.absoluteString.hasSuffix("600x900") == true)
        #expect(matrix.ratings == Ratings(imdb: 8.7, kinopoisk: 8.501))
        #expect(matrix.imdbID == "tt0133093")
    }

    @Test func searchSkipsSeriesAndKeepsAnime() async throws {
        let (catalog, _) = try catalog(fixture: "search")
        let movies = try await catalog.search("матрица")
        #expect(movies.map(\.id) == [301, 299, 12345])
    }

    @Test func searchHandlesMissingFields() async throws {
        let (catalog, _) = try catalog(fixture: "search")
        let movies = try await catalog.search("матрица")

        let edge = try #require(movies.last)
        #expect(edge.title == "Edge Case")  // нет русского названия, берём оригинальное
        #expect(edge.overview == "Полное описание вместо короткого")
        #expect(edge.posterURL == nil)
        #expect(edge.year == nil)
        #expect(edge.imdbID == nil)
        #expect(edge.ratings == Ratings())  // 0 у Кинопоиска значит «нет рейтинга»
    }

    @Test func searchSendsQuery() async throws {
        let (catalog, stub) = try catalog(fixture: "search")
        _ = try await catalog.search("матрица")

        let url = try #require(stub.lastURL)
        #expect(url.host() == "api.poiskkino.dev")
        #expect(url.path() == "/v1.5/movie/search")
        #expect(try query(stub).contains(URLQueryItem(name: "query", value: "матрица")))
    }

    @Test func searchEncodesPlus() async throws {
        let (catalog, stub) = try catalog(fixture: "search")
        _ = try await catalog.search("1+1")

        let url = try #require(stub.lastURL)
        #expect(url.absoluteString.contains("query=1%2B1"))  // голый «+» сервер прочтёт как пробел
    }

    @Test func sendsAPIKeyHeader() async throws {
        let (catalog, stub) = try catalog(fixture: "search")
        _ = try await catalog.search("матрица")
        #expect(stub.requests.last?.value(forHTTPHeaderField: "X-API-KEY") == "test-key")
    }

    /// Зависший Кинопоиск не держит колоду минуту: без ответа за 10 секунд колода строится из списков.
    @Test func requestsTimeOutQuickly() async throws {
        let (catalog, stub) = try catalog(fixture: "search")
        _ = try await catalog.search("матрица")
        #expect(stub.requests.last?.timeoutInterval == 10)
    }

    @Test(arguments: [
        (401, KinopoiskError.unauthorized),
        (403, KinopoiskError.forbidden),
        (500, KinopoiskError.http(status: 500)),
    ])
    func throwsOnHTTPError(status: Int, expected: KinopoiskError) async throws {
        let (catalog, _) = try catalog(status: status)
        await #expect(throws: expected) { try await catalog.search("матрица") }
    }

    @Test func throwsOnUnreadableResponse() async throws {
        let (catalog, _) = try catalog(body: Data("<html>не JSON</html>".utf8))
        await #expect(throws: KinopoiskError.badResponse) { try await catalog.search("матрица") }
    }

    @Test func recommendationsFromSimilarMovies() async throws {
        let (catalog, stub) = try catalog(fixture: "similar")
        let movies = try await catalog.recommendations(for: 301)

        #expect(stub.lastURL?.path() == "/v1.5/movie")
        let query = try query(stub)
        #expect(query.contains(URLQueryItem(name: "id", value: "301")))
        #expect(query.contains(URLQueryItem(name: "selectFields", value: "similarMovies")))
        #expect(movies.map(\.title) == ["Начало", "Эквилибриум", "Тринадцатый этаж"])  // без сериала
        let inception = try #require(movies.first)
        #expect(inception.id == 447301)
        #expect(inception.year == 2010)
        #expect(inception.ratings.kinopoisk == 8.673)
        #expect(inception.posterURL != nil)
    }

    @Test func discoverSendsGenres() async throws {
        let (catalog, stub) = try catalog(fixture: "discover")
        _ = try await catalog.discover(genres: ["комедия", "мультфильм"])

        #expect(stub.lastURL?.path() == "/v1.5/movie")
        let query = try query(stub)
        #expect(query.filter { $0.name == "genres.name" }.map(\.value) == ["комедия", "мультфильм"])
        #expect(query.filter { $0.name == "type" }.map(\.value) == ["movie", "cartoon", "anime"])
        #expect(query.contains(URLQueryItem(name: "isSeries", value: "false")))
        #expect(query.contains(URLQueryItem(name: "rating.kp", value: "6-10")))
        #expect(query.contains(URLQueryItem(name: "sortField", value: "votes.kp")))
        #expect(query.contains(URLQueryItem(name: "sortType", value: "-1")))
        #expect(query.contains { $0.name == "selectFields" && $0.value == "rating" })
    }

    @Test func brokenEntryDoesNotSpoilPage() async throws {
        let (catalog, _) = try catalog(fixture: "discover")
        let movies = try await catalog.discover(genres: ["драма"])

        #expect(movies.map(\.title) == ["Зверополис", "Субстанция", "Странный жанр"])  // без записи без id
        #expect(movies.last?.genres == ["драма"])  // жанр без названия пропущен
    }

    @Test func topSendsPageAndSort() async throws {
        let (catalog, stub) = try catalog(fixture: "discover")
        let movies = try await catalog.top(page: 4)

        #expect(stub.lastURL?.path() == "/v1.5/movie")
        let query = try query(stub)
        #expect(query.contains(URLQueryItem(name: "page", value: "4")))
        #expect(query.contains(URLQueryItem(name: "limit", value: "50")))
        #expect(query.contains(URLQueryItem(name: "sortField", value: "votes.kp")))
        #expect(query.contains(URLQueryItem(name: "sortType", value: "-1")))
        #expect(query.contains(URLQueryItem(name: "isSeries", value: "false")))
        #expect(query.filter { $0.name == "type" }.map(\.value) == ["movie", "cartoon", "anime"])
        #expect(!query.contains { $0.name == "genres.name" })
        #expect(movies.count == 3)
    }

    @Test func newReleasesSendsYear() async throws {
        let (catalog, stub) = try catalog(fixture: "discover")
        _ = try await catalog.newReleases(year: 2026)

        let query = try query(stub)
        #expect(query.contains(URLQueryItem(name: "year", value: "2026")))
        #expect(query.contains(URLQueryItem(name: "sortField", value: "votes.kp")))
        #expect(query.contains { $0.name == "selectFields" && $0.value == "rating" })
    }
}
