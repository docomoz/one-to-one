import Core
import Foundation
import MovieAPI
import Testing
@testable import OneToOne

private let amelie = Movie(id: 1, title: "Амели", year: 2001, genres: ["комедия"], overview: "", posterURL: nil)

/// Отвечает заранее заданным и считает запросы.
private final class StubCatalog: MovieCatalog, @unchecked Sendable {
    var result: Result<[Movie], Error> = .success([amelie])
    private(set) var queries: [String] = []

    func search(_ query: String) async throws -> [Movie] {
        queries.append(query)
        return try result.get()
    }
    func recommendations(for id: Int) async throws -> [Movie] { [] }
    func discover(genres: [String]) async throws -> [Movie] { [] }
}

@MainActor
@Test func searchShowsResults() async {
    let catalog = StubCatalog()
    let search = MovieSearch(catalog: catalog, delay: .zero)

    await search.run(" Амели ")

    #expect(search.results == [amelie])
    #expect(search.errorMessage == nil)
    #expect(catalog.queries == ["Амели"])
}

@MainActor
@Test func shortQueryDoesNotSpendRequest() async {
    let catalog = StubCatalog()
    let search = MovieSearch(catalog: catalog, delay: .zero)

    await search.run("А")

    #expect(search.results.isEmpty)
    #expect(catalog.queries.isEmpty)
}

@MainActor
@Test func failedSearchShowsMessage() async {
    let catalog = StubCatalog()
    catalog.result = .failure(KinopoiskError.forbidden)
    let search = MovieSearch(catalog: catalog, delay: .zero)

    await search.run("Амели")

    #expect(search.results.isEmpty)
    #expect(search.errorMessage == MovieSearchError.message(for: KinopoiskError.forbidden))
}

@MainActor
@Test func cancelledSearchKeepsNewerState() async {
    let catalog = StubCatalog()
    let search = MovieSearch(catalog: catalog, delay: .zero)

    let stale = Task { @MainActor in
        withUnsafeCurrentTask { $0?.cancel() }
        await search.run("Амели")
    }
    await stale.value

    #expect(search.results.isEmpty)
    #expect(!search.isLoading)
}
