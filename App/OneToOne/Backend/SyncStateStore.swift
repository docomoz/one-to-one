import Foundation
import OSLog
import Sync

/// Где лежит состояние синхронизации (`SyncState`): на телефоне — файл, в тестах и превью — память.
protocol SyncStateStoring: Sendable {
    /// Состояние этой пары. Нет, не читается или оно другой пары — пустое: движок заберёт всё заново.
    func load(coupleID: String) -> SyncState
    func save(_ state: SyncState, coupleID: String) throws
    /// Стереть состояние: записи пары в нём открытым текстом, после выхода из пары или аккаунта им не место на телефоне.
    func delete()
}

/// `SyncState.json` в Application Support, рядом с `AppData.json`. Вместе с состоянием лежит id пары:
/// курсор и известные записи одной пары к другой не подходят.
final class SyncStateStore: SyncStateStoring {
    private let fileURL: URL

    init(directory: URL = .applicationSupportDirectory) {
        fileURL = directory.appending(path: "SyncState.json")
    }

    func load(coupleID: String) -> SyncState {
        guard FileManager.default.fileExists(atPath: fileURL.path(percentEncoded: false)) else { return SyncState() }
        do {
            let file = try JSONDecoder().decode(StoredState.self, from: Data(contentsOf: fileURL))
            return file.coupleID == coupleID ? file.state : SyncState()
        } catch {
            // Записи не теряются: они в `AppData.json`, движок отправит их как ни разу не синхронизированные.
            Self.log.error("Не удалось прочитать состояние синхронизации, начинаем заново: \(error)")
            return SyncState()
        }
    }

    func save(_ state: SyncState, coupleID: String) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try JSONEncoder().encode(StoredState(coupleID: coupleID, state: state)).write(to: fileURL, options: .atomic)
    }

    func delete() {
        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch CocoaError.fileNoSuchFile {
            // Уже нет.
        } catch {
            Self.log.error("Не удалось стереть состояние синхронизации: \(error)")
        }
    }

    private struct StoredState: Codable {
        let coupleID: String
        let state: SyncState
    }

    private static let log = Logger(subsystem: "com.docomoz.onetoone", category: "Sync")
}

/// Состояние синхронизации в памяти: для тестов и превью.
final class InMemorySyncStateStore: SyncStateStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var stored: (coupleID: String, state: SyncState)?

    func load(coupleID: String) -> SyncState {
        lock.withLock { stored?.coupleID == coupleID ? stored!.state : SyncState() }
    }

    func save(_ state: SyncState, coupleID: String) {
        lock.withLock { stored = (coupleID, state) }
    }

    func delete() {
        lock.withLock { stored = nil }
    }
}
