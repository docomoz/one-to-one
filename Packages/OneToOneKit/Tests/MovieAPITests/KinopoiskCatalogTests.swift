import Foundation
import Testing
import Core
@testable import MovieAPI

/// Все тесты делят одну подмену сети, поэтому идут по очереди.
@Suite(.serialized) struct KinopoiskCatalogTests {
    private func catalog(status: Int = 200, fixture: String? = nil) throws -> KinopoiskCatalog {
        KinopoiskCatalog(apiKey: "test-key", session: try StubURLProtocol.session(status: status, fixture: fixture))
    }

    private func lastQuery() throws -> [URLQueryItem] {
        let url = try #require(StubURLProtocol.requests.last?.url)
        return URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
    }

    @Test func parsesSearch() async throws {
        let movies = try await catalog(fixture: "search").search("матрица")

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

    @Test func searchSkipsSeriesAndKeepsCartoons() async throws {
        let movies = try await catalog(fixture: "search").search("матрица")
        #expect(movies.map(\.id) == [301, 299, 12345])
    }

    @Test func searchHandlesMissingFields() async throws {
        let movies = try await catalog(fixture: "search").search("матрица")

        let edge = try #require(movies.last)
        #expect(edge.title == "Edge Case")  // нет русского названия, берём оригинальное
        #expect(edge.overview == "Полное описание вместо короткого")
        #expect(edge.posterURL == nil)
        #expect(edge.year == nil)
        #expect(edge.imdbID == nil)
        #expect(edge.ratings == Ratings())  // 0 у Кинопоиска значит «нет рейтинга»
    }

    @Test func searchSendsQuery() async throws {
        _ = try await catalog(fixture: "search").search("матрица")

        let url = try #require(StubURLProtocol.requests.last?.url)
        #expect(url.host() == "api.poiskkino.dev")
        #expect(url.path() == "/v1.5/movie/search")
        #expect(try lastQuery().contains(URLQueryItem(name: "query", value: "матрица")))
    }

    @Test func sendsAPIKeyHeader() async throws {
        _ = try await catalog(fixture: "search").search("матрица")
        #expect(StubURLProtocol.requests.last?.value(forHTTPHeaderField: "X-API-KEY") == "test-key")
    }

    @Test(arguments: [401, 403, 500])
    func throwsOnHTTPError(status: Int) async throws {
        let catalog = try catalog(status: status)
        await #expect(throws: KinopoiskError.self) { try await catalog.search("матрица") }
    }

    @Test func httpErrorsAreDistinguished() async throws {
        await #expect(throws: KinopoiskError.unauthorized) { try await catalog(status: 401).search("x") }
        await #expect(throws: KinopoiskError.dailyLimitReached) { try await catalog(status: 403).search("x") }
        await #expect(throws: KinopoiskError.http(status: 500)) { try await catalog(status: 500).search("x") }
    }

    @Test func recommendationsFromSimilarMovies() async throws {
        let movies = try await catalog(fixture: "movie").recommendations(for: 301)

        #expect(StubURLProtocol.requests.last?.url?.path() == "/v1.5/movie/301")
        #expect(movies.map(\.title) == ["Начало", "Эквилибриум", "Тринадцатый этаж"])
        let inception = try #require(movies.first)
        #expect(inception.id == 447301)
        #expect(inception.year == 2010)
        #expect(inception.ratings.kinopoisk == 8.673)
        #expect(inception.posterURL != nil)
    }

    @Test func discoverSendsGenres() async throws {
        let movies = try await catalog(fixture: "discover").discover(genres: ["комедия", "мультфильм"])

        #expect(StubURLProtocol.requests.last?.url?.path() == "/v1.5/movie")
        let query = try lastQuery()
        #expect(query.filter { $0.name == "genres.name" }.map(\.value) == ["комедия", "мультфильм"])
        #expect(query.filter { $0.name == "type" }.map(\.value) == ["movie", "cartoon"])
        #expect(query.contains(URLQueryItem(name: "rating.kp", value: "6-10")))
        #expect(query.contains(URLQueryItem(name: "sortField", value: "votes.kp")))
        #expect(query.contains(URLQueryItem(name: "sortType", value: "-1")))
        #expect(query.contains { $0.name == "selectFields" && $0.value == "rating" })
        #expect(movies.map(\.title) == ["Зверополис", "Субстанция"])
    }
}
