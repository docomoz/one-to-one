import Core
import Foundation

extension Ratings {
    /// «IMDb 7.4 · Кинопоиск 7.8». Пустые рейтинги пропускаем, нет ни одного — `nil`.
    var line: String? {
        let parts = [imdb.map { "IMDb \(Self.format($0))" }, kinopoisk.map { "Кинопоиск \(Self.format($0))" }]
            .compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private static func format(_ value: Double) -> String {
        String(format: "%.1f", value)
    }
}

extension Movie {
    /// «2019 · комедия, драма»: год и до двух жанров, пустое пропускаем.
    var details: String {
        ([year.map(String.init)] + [genres.prefix(2).joined(separator: ", ")])
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }
}
