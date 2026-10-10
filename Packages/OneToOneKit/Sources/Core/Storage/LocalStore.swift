import Foundation

/// Хранит `AppData` JSON-файлом на телефоне.
public final class LocalStore: Store {
    private let fileURL: URL

    /// По умолчанию папка Application Support приложения. В тестах передаём временную.
    public init(directory: URL = .applicationSupportDirectory) {
        fileURL = directory.appending(path: "AppData.json")
    }

    /// Файла ещё нет (первый запуск) — возвращает пустые данные.
    public func load() throws -> AppData {
        guard FileManager.default.fileExists(atPath: fileURL.path(percentEncoded: false)) else {
            return AppData()
        }
        return try JSONDecoder().decode(AppData.self, from: Data(contentsOf: fileURL))
    }

    public func save(_ data: AppData) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        // atomic: пишем во временный файл и подменяем, чтобы сбой посреди записи не испортил данные.
        try JSONEncoder().encode(data).write(to: fileURL, options: .atomic)
    }
}
