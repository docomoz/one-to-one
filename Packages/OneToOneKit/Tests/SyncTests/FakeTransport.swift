import Foundation
import Synchronization
@testable import Sync

/// Сервер в памяти, общий для двух устройств. Как Appwrite: один документ на `documentID`, у документа время на сервере,
/// pull отдаёт документы по порядку (время, затем id) порциями по `pageSize`.
final class FakeServer: Sendable {
    struct Document: Equatable {
        var updatedAt: Date
        var envelope: Data
    }

    private struct Storage {
        /// id пары → id документа → документ.
        var documents: [String: [String: Document]] = [:]
        var clock: Double = 0
    }

    let pageSize: Int
    /// Все документы получают одно и то же время: проверяем, что курсор не теряет документы с равным временем.
    let frozenClock: Bool
    private let storage = Mutex(Storage())

    init(pageSize: Int = 100, frozenClock: Bool = false) {
        self.pageSize = pageSize
        self.frozenClock = frozenClock
    }

    func push(_ records: [EncryptedRecord], coupleID: String) {
        storage.withLock { storage in
            for record in records {
                // Время ставит сервер, присланное устройством не берём.
                if !frozenClock { storage.clock += 1 }
                let document = Document(updatedAt: Date(timeIntervalSinceReferenceDate: storage.clock),
                                        envelope: record.envelope)
                storage.documents[coupleID, default: [:]][record.documentID] = document
            }
        }
    }

    func pull(coupleID: String, after cursor: String?) -> (records: [EncryptedRecord], cursor: String?) {
        let position = cursor.flatMap(Self.position)
        let page = documents(coupleID: coupleID)
            .map { EncryptedRecord(documentID: $0.key, updatedAt: $0.value.updatedAt, envelope: $0.value.envelope) }
            .sorted { Self.isBefore(($0.updatedAt, $0.documentID), ($1.updatedAt, $1.documentID)) }
            .filter { position == nil || Self.isBefore(position!, ($0.updatedAt, $0.documentID)) }
            .prefix(pageSize)
        guard let last = page.last else { return ([], cursor) }
        return (Array(page), "\(last.updatedAt.timeIntervalSinceReferenceDate)|\(last.documentID)")
    }

    func documents(coupleID: String) -> [String: Document] {
        storage.withLock { $0.documents[coupleID] ?? [:] }
    }

    /// Сервер сам подменяет конверт документа (откат, мусор, удаление) и ставит свежее время.
    func forge(documentID: String, envelope: Data, coupleID: String) {
        push([EncryptedRecord(documentID: documentID, updatedAt: Date(), envelope: envelope)], coupleID: coupleID)
    }

    private static func position(_ cursor: String) -> (Date, String)? {
        let parts = cursor.split(separator: "|", maxSplits: 1)
        guard parts.count == 2, let seconds = Double(parts[0]) else { return nil }
        return (Date(timeIntervalSinceReferenceDate: seconds), String(parts[1]))
    }

    private static func isBefore(_ a: (Date, String), _ b: (Date, String)) -> Bool {
        a.0 != b.0 ? a.0 < b.0 : a.1 < b.1
    }
}

/// Сеть одного устройства до общего `FakeServer`. Можно выключить: тогда push и pull бросают ошибку.
final class FakeTransport: SyncTransport {
    struct Offline: Error {}

    let server: FakeServer
    private let offline = Atomic(false)

    init(server: FakeServer) {
        self.server = server
    }

    var isOffline: Bool {
        get { offline.load(ordering: .relaxed) }
        set { offline.store(newValue, ordering: .relaxed) }
    }

    func push(_ records: [EncryptedRecord], coupleID: String) async throws {
        guard !isOffline else { throw Offline() }
        server.push(records, coupleID: coupleID)
    }

    func pull(coupleID: String, after cursor: String?) async throws -> (records: [EncryptedRecord], cursor: String?) {
        guard !isOffline else { throw Offline() }
        return server.pull(coupleID: coupleID, after: cursor)
    }
}
