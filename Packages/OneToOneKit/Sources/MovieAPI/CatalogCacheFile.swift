import Foundation

/// Кэш каталога в файле на телефоне. Это не данные пары, поэтому он отдельно от `AppData` и в iCloud не едет.
public final class CatalogCacheFile: Sendable {
    let url: URL

    public init(url: URL) {
        self.url = url
    }

    /// Application Support / MovieCatalogCache.json.
    public static var defaultURL: URL {
        URL.applicationSupportDirectory.appending(path: "MovieCatalogCache.json")
    }

    /// Нет файла или он испорчен — начинаем с пустого кэша: он необязателен.
    public func load() -> CatalogCache {
        guard let data = try? Data(contentsOf: url) else { return CatalogCache() }
        return (try? JSONDecoder().decode(CatalogCache.self, from: data)) ?? CatalogCache()
    }

    /// Ошибку записи молча пропускаем: без кэша подбор всё равно работает.
    public func save(_ cache: CatalogCache) {
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? JSONEncoder().encode(cache).write(to: url, options: .atomic)
    }
}
