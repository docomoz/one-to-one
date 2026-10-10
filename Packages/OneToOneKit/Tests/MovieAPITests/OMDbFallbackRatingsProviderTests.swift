import Foundation
import Testing
import Core
@testable import MovieAPI

struct OMDbFallbackRatingsProviderTests {
    private func provider(status: Int = 200, fixture: String? = nil)
        throws -> (OMDbFallbackRatingsProvider, StubURLProtocol.Stub) {
        let (session, stub) = try StubURLProtocol.session(status: status, fixture: fixture)
        return (OMDbFallbackRatingsProvider(omdbKey: "test-key", session: session), stub)
    }

    private func movie(imdbID: String? = "tt0133093", ratings: Ratings) -> Movie {
        Movie(id: 301, title: "Матрица", year: 1999, genres: [], overview: "",
              posterURL: nil, imdbID: imdbID, ratings: ratings)
    }

    @Test func catalogRatingsKept() async throws {
        let (provider, stub) = try provider(fixture: "omdb")
        let ratings = await provider.ratings(for: movie(ratings: Ratings(imdb: 8.5, kinopoisk: 8.4)))

        #expect(ratings == Ratings(imdb: 8.5, kinopoisk: 8.4))
        #expect(stub.requests.isEmpty)
    }

    @Test func omdbFillsMissingImdb() async throws {
        let (provider, stub) = try provider(fixture: "omdb")
        let ratings = await provider.ratings(for: movie(ratings: Ratings(kinopoisk: 8.4)))

        #expect(ratings == Ratings(imdb: 8.7, kinopoisk: 8.4))
        let url = try #require(stub.lastURL)
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        #expect(url.host() == "www.omdbapi.com")
        #expect(query.contains(URLQueryItem(name: "i", value: "tt0133093")))
        #expect(query.contains(URLQueryItem(name: "apikey", value: "test-key")))
    }

    @Test func omdbFailsKeepsKinopoisk() async throws {
        let (provider, _) = try provider(status: 500)
        let ratings = await provider.ratings(for: movie(ratings: Ratings(kinopoisk: 8.4)))
        #expect(ratings == Ratings(kinopoisk: 8.4))
    }

    @Test func omdbErrorResponseKeepsKinopoisk() async throws {
        // OMDb сообщает об ошибке со статусом 200 и "Response": "False".
        let (provider, _) = try provider(fixture: "omdb-error")
        let ratings = await provider.ratings(for: movie(ratings: Ratings(kinopoisk: 8.4)))
        #expect(ratings == Ratings(kinopoisk: 8.4))
    }

    @Test func noImdbIDNoRequest() async throws {
        let (provider, stub) = try provider(fixture: "omdb")
        let ratings = await provider.ratings(for: movie(imdbID: nil, ratings: Ratings(kinopoisk: 8.4)))

        #expect(ratings == Ratings(kinopoisk: 8.4))
        #expect(stub.requests.isEmpty)
    }

    @Test func noKeyNoRequest() async throws {
        let (session, stub) = try StubURLProtocol.session(fixture: "omdb")
        let provider = OMDbFallbackRatingsProvider(omdbKey: "", session: session)
        let ratings = await provider.ratings(for: movie(ratings: Ratings(kinopoisk: 8.4)))

        #expect(ratings == Ratings(kinopoisk: 8.4))
        #expect(stub.requests.isEmpty)
    }

    @Test func garbageRatingIsNil() async throws {
        let (provider, _) = try provider(fixture: "omdb-na")
        let ratings = await provider.ratings(for: movie(imdbID: "tt9999999", ratings: Ratings()))
        #expect(ratings == Ratings())
    }
}
