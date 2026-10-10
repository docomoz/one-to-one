import Foundation
import MovieAPI
import SwiftUI

extension EnvironmentValues {
    /// Каталог фильмов. В превью и тестах подменяем, чтобы не тратить 200 бесплатных запросов в день.
    @Entry var movieCatalog: any MovieCatalog = AppCatalog.shared
}

/// Один каталог на всё приложение: у него память (кэш на телефоне), её нельзя создавать заново.
enum AppCatalog {
    static let shared: any MovieCatalog = CachingCatalog(
        remote: KinopoiskCatalog(apiKey: Bundle.main.object(forInfoDictionaryKey: "KinopoiskAPIKey") as? String ?? ""),
        file: CatalogCacheFile(url: CatalogCacheFile.defaultURL),
        base: BaseCatalog.load())
}
