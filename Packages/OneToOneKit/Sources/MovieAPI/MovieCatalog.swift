import Core

/// Источник фильмов: поиск, «похожие» и подборка по жанрам.
public protocol MovieCatalog: Sendable {
    func search(_ query: String) async throws -> [Movie]
    func recommendations(for id: Int) async throws -> [Movie]
    func discover(genres: [String]) async throws -> [Movie]
    /// Фильмы, которые есть на телефоне без сети, с подходящим жанром.
    func localMovies(genres: [String]) async -> [Movie]
    /// Раз в день пополняет каталог на телефоне.
    func refillIfNeeded() async
}

/// Обычному каталогу хранить на телефоне нечего: это умеет `CachingCatalog`.
extension MovieCatalog {
    public func localMovies(genres: [String]) async -> [Movie] { [] }
    public func refillIfNeeded() async {}
}
