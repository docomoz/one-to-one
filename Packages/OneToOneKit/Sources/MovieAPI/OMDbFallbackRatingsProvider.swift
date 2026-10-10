import Foundation
import Core

/// Рейтинги из каталога Кинопоиска, а пустой IMDb дозаполняет OMDb (omdbapi.com).
/// В OMDb идём только если IMDb пустой, есть `imdbID` и ключ, и один фильм спрашиваем
/// один раз за запуск: бесплатных запросов мало.
public struct OMDbFallbackRatingsProvider: RatingsProvider {
    static let baseURL = URL(string: "https://www.omdbapi.com/")!
    /// Рейтинг IMDb только украшение карточки, долго его не ждём.
    static let timeout: TimeInterval = 10

    private let omdbKey: String
    private let session: URLSession
    private let cache = Cache()

    public init(omdbKey: String, session: URLSession = .shared) {
        self.omdbKey = omdbKey
        self.session = session
    }

    public func ratings(for movie: Movie) async -> Ratings {
        var ratings = movie.ratings
        guard ratings.imdb == nil, let imdbID = movie.imdbID, !omdbKey.isEmpty else { return ratings }
        if let cached = await cache[imdbID] {
            ratings.imdb = cached
        } else {
            ratings.imdb = await imdbRating(for: imdbID)
            await cache.set(ratings.imdb, for: imdbID)
        }
        return ratings
    }

    /// Рейтинг IMDb из OMDb или `nil` при любой ошибке.
    private func imdbRating(for imdbID: String) async -> Double? {
        var components = URLComponents(url: Self.baseURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "i", value: imdbID),
                                 URLQueryItem(name: "apikey", value: omdbKey)]
        guard let url = components.url else { return nil }
        let request = URLRequest(url: url, timeoutInterval: Self.timeout)
        guard let (data, response) = try? await session.data(for: request),
              (response as? HTTPURLResponse).map({ 200..<300 ~= $0.statusCode }) == true,
              let body = try? JSONDecoder().decode(OMDbMovie.self, from: data)
        else { return nil }
        return body.rating
    }

    /// Уже полученные ответы OMDb, включая «рейтинга нет», чтобы не спрашивать повторно.
    private actor Cache {
        private var ratings: [String: Double?] = [:]
        subscript(imdbID: String) -> Double?? { ratings[imdbID] }
        func set(_ rating: Double?, for imdbID: String) { ratings[imdbID] = rating }
    }
}

/// Ответ OMDb. При ошибке он отвечает 200 с `"Response": "False"`.
struct OMDbMovie: Decodable {
    let response: String?
    let imdbRating: String?

    enum CodingKeys: String, CodingKey {
        case response = "Response"
        case imdbRating
    }

    /// Рейтинг по шкале 0–10. Ошибка, «N/A», пусто и мусор превращаются в `nil`.
    var rating: Double? {
        guard response != "False",
              let value = imdbRating.flatMap(Double.init), value > 0, value <= 10 else { return nil }
        return value
    }
}
