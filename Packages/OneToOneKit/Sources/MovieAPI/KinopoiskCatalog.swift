import Foundation
import Core

/// Каталог фильмов Кинопоиска (poiskkino.dev). Рейтинги Кинопоиска и IMDb приходят сразу с фильмом.
/// Бесплатно 200 запросов в день, поэтому просим только нужные поля.
public struct KinopoiskCatalog: MovieCatalog {
    static let baseURL = URL(string: "https://api.poiskkino.dev/v1.5")!
    /// Подходит для «посмотреть вечером»: фильмы, мультфильмы и полнометражное аниме, но не сериалы.
    static let types = ["movie", "cartoon", "anime"]
    static let fields = ["id", "name", "alternativeName", "enName", "year", "type", "isSeries",
                         "shortDescription", "description", "rating", "poster", "genres", "externalId"]

    private let apiKey: String
    private let session: URLSession

    public init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    public func search(_ query: String) async throws -> [Movie] {
        let page: KinopoiskPage = try await get("movie/search", [
            ("query", query),
            ("limit", "20"),
        ])
        return Self.movies(page.docs.items)
    }

    public func recommendations(for id: Int) async throws -> [Movie] {
        let page: KinopoiskPage = try await get("movie", [
            ("id", String(id)),
            ("selectFields", "id"),
            ("selectFields", "similarMovies"),
        ])
        return Self.movies(page.docs.items.first?.similarMovies?.items ?? [])
    }

    public func discover(genres: [String]) async throws -> [Movie] {
        var query = genres.map { ("genres.name", $0) }
        query += Self.types.map { ("type", $0) }
        query += [
            ("isSeries", "false"),
            ("rating.kp", "6-10"),
            ("sortField", "votes.kp"),
            ("sortType", "-1"),
            ("limit", "40"),
        ]
        query += Self.fields.map { ("selectFields", $0) }
        let page: KinopoiskPage = try await get("movie", query)
        return Self.movies(page.docs.items)
    }

    /// Убирает сериалы и записи без названия.
    static func movies(_ items: [KinopoiskMovie]) -> [Movie] {
        items
            .filter { $0.isSeries != true && $0.type.map(types.contains) != false }
            .compactMap(\.movie)
    }

    private func get<T: Decodable>(_ path: String, _ query: [(String, String)]) async throws -> T {
        var components = URLComponents(url: Self.baseURL.appending(path: path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { components.percentEncodedQueryItems = query.map(Self.encoded) }
        var request = URLRequest(url: components.url!)
        request.setValue(apiKey, forHTTPHeaderField: "X-API-KEY")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        switch status {
        case 200..<300:
            do { return try JSONDecoder().decode(T.self, from: data) } catch { throw KinopoiskError.badResponse }
        case 401: throw KinopoiskError.unauthorized
        case 403: throw KinopoiskError.forbidden
        default: throw KinopoiskError.http(status: status)
        }
    }

    /// Кодирует параметр строго: обычное кодирование оставляет «+», а сервер читает его как пробел.
    private static func encoded(_ item: (String, String)) -> URLQueryItem {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "+&=")
        let encode = { (s: String) in s.addingPercentEncoding(withAllowedCharacters: allowed) ?? s }
        return URLQueryItem(name: encode(item.0), value: encode(item.1))
    }
}
