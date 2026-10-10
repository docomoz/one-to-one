import Foundation

/// Фильм из каталога Кинопоиска.
public struct Movie: Codable, Identifiable, Hashable, Sendable {
    /// Id Кинопоиска.
    public let id: Int
    public let title: String
    public let year: Int?
    public let genres: [String]
    public let overview: String
    public let posterURL: URL?
    public var imdbID: String?
    public var ratings: Ratings

    public init(id: Int, title: String, year: Int?, genres: [String], overview: String,
                posterURL: URL?, imdbID: String? = nil, ratings: Ratings = Ratings()) {
        self.id = id
        self.title = title
        self.year = year
        self.genres = genres
        self.overview = overview
        self.posterURL = posterURL
        self.imdbID = imdbID
        self.ratings = ratings
    }
}

/// Рейтинги фильма. `nil` — рейтинга нет или его не удалось получить.
public struct Ratings: Codable, Hashable, Sendable {
    public var imdb: Double?
    public var kinopoisk: Double?

    public init(imdb: Double? = nil, kinopoisk: Double? = nil) {
        self.imdb = imdb
        self.kinopoisk = kinopoisk
    }
}
