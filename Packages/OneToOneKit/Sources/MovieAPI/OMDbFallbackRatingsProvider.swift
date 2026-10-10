import Foundation
import Core

/// Рейтинги из каталога Кинопоиска, а пустой IMDb дозаполняет OMDb (omdbapi.com).
/// В OMDb идём только если IMDb пустой, есть `imdbID` и ключ: бесплатных запросов мало.
public struct OMDbFallbackRatingsProvider: RatingsProvider {
    static let baseURL = URL(string: "https://www.omdbapi.com/")!

    private let omdbKey: String
    private let session: URLSession

    public init(omdbKey: String, session: URLSession = .shared) {
        self.omdbKey = omdbKey
        self.session = session
    }

    public func ratings(for movie: Movie) async -> Ratings {
        var ratings = movie.ratings
        guard ratings.imdb == nil, let imdbID = movie.imdbID, !omdbKey.isEmpty else { return ratings }
        ratings.imdb = await imdbRating(for: imdbID)
        return ratings
    }

    /// Рейтинг IMDb из OMDb или `nil` при любой ошибке.
    private func imdbRating(for imdbID: String) async -> Double? {
        var components = URLComponents(url: Self.baseURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "i", value: imdbID),
                                 URLQueryItem(name: "apikey", value: omdbKey)]
        guard let url = components.url,
              let (data, response) = try? await session.data(from: url),
              (response as? HTTPURLResponse).map({ 200..<300 ~= $0.statusCode }) == true,
              let body = try? JSONDecoder().decode(OMDbMovie.self, from: data)
        else { return nil }
        return body.rating
    }
}

/// Ответ OMDb. При ошибке он отвечает 200 с `"Response": "False"`, а рейтинга нет.
struct OMDbMovie: Decodable {
    let imdbRating: String?

    enum CodingKeys: String, CodingKey { case imdbRating }

    /// «N/A», пусто и мусор превращаются в `nil`.
    var rating: Double? {
        guard let value = imdbRating.flatMap(Double.init), value.isFinite, value > 0 else { return nil }
        return value
    }
}
