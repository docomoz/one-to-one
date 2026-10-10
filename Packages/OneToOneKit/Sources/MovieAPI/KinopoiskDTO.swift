import Foundation
import Core

/// Ответ Кинопоиска со списком фильмов (поиск и подборка).
struct KinopoiskPage: Decodable {
    let docs: [KinopoiskMovie]
}

/// Фильм в ответе Кинопоиска. Все поля необязательные: у «похожих» их меньше,
/// а у редких фильмов многое бывает пустым.
struct KinopoiskMovie: Decodable {
    struct Rating: Decodable { let kp: Double?; let imdb: Double? }
    struct Poster: Decodable { let url: String? }
    struct Genre: Decodable { let name: String }
    struct ExternalID: Decodable { let imdb: String? }

    let id: Int
    let name: String?
    let alternativeName: String?
    let enName: String?
    let year: Int?
    let type: String?
    let shortDescription: String?
    let description: String?
    let rating: Rating?
    let poster: Poster?
    let genres: [Genre]?
    let externalId: ExternalID?
    let similarMovies: [KinopoiskMovie]?

    /// Фильм для приложения или `nil`, если у него нет ни одного названия.
    var movie: Movie? {
        guard let title = [name, alternativeName, enName].compactMap(\.nonEmpty).first else { return nil }
        return Movie(
            id: id,
            title: title,
            year: year,
            genres: genres?.map(\.name) ?? [],
            overview: shortDescription.nonEmpty ?? description.nonEmpty ?? "",
            posterURL: poster?.url.nonEmpty.flatMap(URL.init(string:)),
            imdbID: externalId?.imdb.nonEmpty,
            ratings: Ratings(imdb: rating?.imdb.positive, kinopoisk: rating?.kp.positive)
        )
    }
}

private extension Optional<String> {
    var nonEmpty: String? { self?.isEmpty == false ? self : nil }
}

private extension Optional<Double> {
    /// Кинопоиск пишет 0, когда рейтинга нет.
    var positive: Double? { (self ?? 0) > 0 ? self : nil }
}
