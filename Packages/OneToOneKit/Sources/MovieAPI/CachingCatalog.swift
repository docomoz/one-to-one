import Core
import Foundation

/// Кинопоиск с памятью: всё, что пришло, остаётся на телефоне, и подбор работает без сети
/// и когда кончились 200 запросов в день. Раз в день догружает страницу топа и новинки года.
public actor CachingCatalog: MovieCatalog {
    private let remote: any MovieCatalog & MovieFeed
    private let file: CatalogCacheFile
    private let base: [Movie]
    private let now: @Sendable () -> Date
    private var cache: CatalogCache

    public init(remote: some MovieCatalog & MovieFeed, file: CatalogCacheFile, base: [Movie],
                now: @escaping @Sendable () -> Date = { .now }) {
        self.remote = remote
        self.file = file
        self.base = base
        self.now = now
        cache = file.load()
    }

    public func search(_ query: String) async throws -> [Movie] {
        remember(try await remote.search(query))
    }

    public func recommendations(for id: Int) async throws -> [Movie] {
        remember(try await remote.recommendations(for: id))
    }

    public func discover(genres: [String]) async throws -> [Movie] {
        remember(try await remote.discover(genres: genres))
    }

    public func localMovies(genres: [String]) async -> [Movie] {
        cache.movies(genres: genres, base: base)
    }

    /// Не чаще раза в день: 2 запроса — следующая страница топа и новинки года.
    /// Если не пришло ничего (нет сети, лимит), день не засчитываем и попробуем в следующий раз.
    /// Пришло хоть что-то — день засчитан: иначе каждое открытие колоды тратило бы ещё 2 запроса.
    public func refillIfNeeded() async {
        let today = DayKey(now())
        guard cache.lastRefill != today else { return }
        // Пустая база (скрипт ещё не запускали) — начинаем с самого популярного, с первой страницы.
        let page = cache.nextTopPage ?? base.count / 50 + 1
        let year = Calendar.current.component(.year, from: now())

        async let top = try? remote.top(page: page)
        async let fresh = try? remote.newReleases(year: year)
        let (topMovies, freshMovies) = await (top, fresh)

        if let topMovies {
            cache.add(topMovies, at: now())
            // Топ кончился — начинаем сначала: там могли появиться новые фильмы.
            cache.nextTopPage = topMovies.isEmpty ? 1 : page + 1
        }
        if let freshMovies { cache.add(freshMovies, at: now()) }
        if topMovies != nil || freshMovies != nil { cache.lastRefill = today }
        file.save(cache)
    }

    private func remember(_ movies: [Movie]) -> [Movie] {
        cache.add(movies, at: now())
        file.save(cache)
        return movies
    }
}
