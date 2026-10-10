import Core

/// Источник новых фильмов для каталога на телефоне: топ по страницам и новинки года.
public protocol MovieFeed: Sendable {
    func top(page: Int) async throws -> [Movie]
    func newReleases(year: Int) async throws -> [Movie]
}
