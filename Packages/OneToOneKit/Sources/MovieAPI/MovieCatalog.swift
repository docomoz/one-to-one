import Core

/// Источник фильмов: поиск, «похожие» и подборка по жанрам.
public protocol MovieCatalog: Sendable {
    func search(_ query: String) async throws -> [Movie]
    func recommendations(for id: Int) async throws -> [Movie]
    func discover(genres: [String]) async throws -> [Movie]
}
