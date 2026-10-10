import Foundation
import MovieAPI
import SwiftUI

extension EnvironmentValues {
    /// Каталог фильмов. В превью и тестах подменяем, чтобы не тратить 200 бесплатных запросов в день.
    @Entry var movieCatalog: any MovieCatalog = KinopoiskCatalog(
        apiKey: Bundle.main.object(forInfoDictionaryKey: "KinopoiskAPIKey") as? String ?? "")
}
