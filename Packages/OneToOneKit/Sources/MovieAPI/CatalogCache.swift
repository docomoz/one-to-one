import Core
import Foundation

/// Фильмы, которые телефон уже получил от Кинопоиска, и состояние ежедневной догрузки.
public struct CatalogCache: Codable, Equatable, Sendable {
    public struct Entry: Codable, Equatable, Sendable {
        public var movie: Movie
        /// Когда фильм впервые попал в кэш: по нему вытесняем самые давние.
        public var addedAt: Date
    }

    public var entries: [Int: Entry] = [:]
    /// День последней удачной догрузки: догружаем не чаще раза в день.
    public var lastRefill: DayKey?
    /// Какую страницу топа просить следующей. `nil` — первую после базы `movies.json` (в ней по 50 на страницу).
    public var nextTopPage: Int?

    public init() {}

    /// Запоминает фильмы. Знакомый фильм обновляется (свежие рейтинги), но остаётся со старой датой.
    /// Больше `limit` не храним: выкидываем самые давние.
    public mutating func add(_ movies: [Movie], at date: Date, limit: Int = 2000) {
        for movie in movies {
            entries[movie.id] = Entry(movie: movie, addedAt: entries[movie.id]?.addedAt ?? date)
        }
        guard entries.count > limit else { return }
        let oldest = entries.values.sorted { ($0.addedAt, $0.movie.id) < ($1.addedAt, $1.movie.id) }
        for entry in oldest.prefix(entries.count - limit) {
            entries[entry.movie.id] = nil
        }
    }

    /// Фильмы базы и кэша с подходящим жанром, самые высокие по рейтингу Кинопоиска первыми.
    /// Кэш свежее базы, поэтому при одинаковом id берём фильм из кэша.
    public func movies(genres: [String], base: [Movie], limit: Int = 40) -> [Movie] {
        var all = Dictionary(base.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for entry in entries.values { all[entry.movie.id] = entry.movie }
        let wanted = Set(genres)
        return all.values
            .filter { !wanted.isDisjoint(with: $0.genres) }
            .sorted { Self.isHigher($0, $1) }
            .prefix(limit)
            .map { $0 }
    }

    /// По убыванию рейтинга, фильмы без рейтинга в конце; при равенстве — по id, чтобы порядок не прыгал.
    private static func isHigher(_ a: Movie, _ b: Movie) -> Bool {
        switch (a.ratings.kinopoisk, b.ratings.kinopoisk) {
        case let (x?, y?) where x != y: x > y
        case (.some, nil): true
        case (nil, .some): false
        default: a.id < b.id
        }
    }
}
