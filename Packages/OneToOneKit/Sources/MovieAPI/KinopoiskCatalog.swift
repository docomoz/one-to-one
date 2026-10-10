import Foundation
import Core

/// Каталог фильмов Кинопоиска (poiskkino.dev). Рейтинги Кинопоиска и IMDb приходят сразу с фильмом.
/// Бесплатно 200 запросов в день, поэтому просим только нужные поля.
public struct KinopoiskCatalog: MovieCatalog {
    static let baseURL = URL(string: "https://api.poiskkino.dev/v1.5")!
    /// Сериалы и шоу не подходят для «посмотреть вечером», мультфильмы подходят.
    static let types = ["movie", "cartoon"]
    static let fields = ["id", "name", "alternativeName", "enName", "year", "type", "shortDescription",
                         "description", "rating", "poster", "genres", "externalId"]

    private let apiKey: String
    private let session: URLSession

    public init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    public func search(_ query: String) async throws -> [Movie] {
        let page: KinopoiskPage = try await get("movie/search", [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "limit", value: "20"),
        ])
        return page.docs.filter { Self.types.contains($0.type ?? "") }.compactMap(\.movie)
    }

    public func recommendations(for id: Int) async throws -> [Movie] {
        let movie: KinopoiskMovie = try await get("movie/\(id)", [])
        return (movie.similarMovies ?? []).compactMap(\.movie)
    }

    public func discover(genres: [String]) async throws -> [Movie] {
        var query = genres.map { URLQueryItem(name: "genres.name", value: $0) }
        query += Self.types.map { URLQueryItem(name: "type", value: $0) }
        query += [
            URLQueryItem(name: "rating.kp", value: "6-10"),
            URLQueryItem(name: "sortField", value: "votes.kp"),
            URLQueryItem(name: "sortType", value: "-1"),
            URLQueryItem(name: "limit", value: "40"),
        ]
        query += Self.fields.map { URLQueryItem(name: "selectFields", value: $0) }
        let page: KinopoiskPage = try await get("movie", query)
        return page.docs.compactMap(\.movie)
    }

    private func get<T: Decodable>(_ path: String, _ query: [URLQueryItem]) async throws -> T {
        var url = Self.baseURL.appending(path: path)
        if !query.isEmpty { url.append(queryItems: query) }
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-API-KEY")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        switch status {
        case 200..<300: return try JSONDecoder().decode(T.self, from: data)
        case 401: throw KinopoiskError.unauthorized
        case 403: throw KinopoiskError.dailyLimitReached
        default: throw KinopoiskError.http(status: status)
        }
    }
}
