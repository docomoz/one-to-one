import Core
import MovieAPI

/// Каталог для превью: без сети и без расхода запросов.
struct PreviewCatalog: MovieCatalog {
    static let movies = [
        Movie(id: 1, title: "Амели", year: 2001, genres: ["комедия", "мелодрама"], overview: "", posterURL: nil),
        Movie(id: 2, title: "Брат", year: 1997, genres: ["драма", "криминал"], overview: "", posterURL: nil),
    ]

    func search(_ query: String) async throws -> [Movie] { Self.movies }
    func recommendations(for id: Int) async throws -> [Movie] { [] }
    func discover(genres: [String]) async throws -> [Movie] { [] }
}
