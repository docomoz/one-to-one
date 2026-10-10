// Обновляет базовый каталог `Sources/MovieAPI/Resources/movies.json`: топ-150 Кинопоиска по числу голосов.
// Запуск: cd Packages/OneToOneKit && swift run UpdateMovies
// Ключ — из KINOPOISK_API_KEY или из Config/Secrets.xcconfig. Тратит 3 запроса из 200 в день.
import Core
import Foundation
import MovieAPI

/// Корень пакета: файл лежит в Sources/UpdateMovies/.
let packageDir = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
let output = packageDir.appending(path: "Sources/MovieAPI/Resources/movies.json")
let secrets = packageDir.appending(path: "../../Config/Secrets.xcconfig").standardized

/// Ключ из окружения, иначе строка `KINOPOISK_API_KEY = …` в Secrets.xcconfig.
func apiKey() -> String? {
    if let key = ProcessInfo.processInfo.environment["KINOPOISK_API_KEY"], !key.isEmpty { return key }
    guard let text = try? String(contentsOf: secrets, encoding: .utf8) else { return nil }
    for line in text.split(separator: "\n") {
        let parts = line.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
        if parts.count == 2, parts[0] == "KINOPOISK_API_KEY", !parts[1].isEmpty { return parts[1] }
    }
    return nil
}

guard let key = apiKey() else {
    FileHandle.standardError.write(Data("""
        Нет ключа Кинопоиска. Впиши его в \(secrets.path()) строкой KINOPOISK_API_KEY = …
        или запусти так: KINOPOISK_API_KEY=… swift run UpdateMovies

        """.utf8))
    exit(1)
}

let catalog = KinopoiskCatalog(apiKey: key)
var movies: [Int: Movie] = [:]
do {
    for page in 1...3 {
        for movie in try await catalog.top(page: page) { movies[movie.id] = movie }
    }
} catch {
    // У сетевой ошибки — короткое описание («The request timed out»), у ошибки Кинопоиска — её имя (unauthorized…).
    let reason = (error as? URLError)?.localizedDescription ?? "\(error)"
    FileHandle.standardError.write(Data("Кинопоиск не ответил (\(reason)), movies.json не изменён.\n".utf8))
    exit(1)
}

// По id и с отсортированными ключами — чтобы diff в git был читаемым.
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
try encoder.encode(movies.values.sorted { $0.id < $1.id }).write(to: output, options: .atomic)
print("Записано \(movies.count) фильмов в \(output.path())")
