import Core
import Foundation

/// Базовый каталог: топ Кинопоиска, который едет вместе с приложением, чтобы подбор работал без сети.
public enum BaseCatalog {
    /// `movies.json` из ресурсов пакета.
    public static var bundledURL: URL? {
        Bundle.module.url(forResource: "movies", withExtension: "json")
    }

    /// Фильмы базы. Нет файла или он испорчен — пусто: подбор тогда живёт на кэше и сети.
    public static func load(from url: URL? = bundledURL) -> [Movie] {
        guard let url, let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([Movie].self, from: data)) ?? []
    }
}
