import Foundation
import Synchronization
import Sync

/// Сервер пары в памяти: один документ на `documentID`, каждая запись получает следующий номер,
/// pull отдаёт всё после курсора-номера. Общий для двух «телефонов» в тесте.
final class FakeSyncServer: Sendable {
    private let storage = Mutex<(clock: Int, documents: [String: (stamp: Int, envelope: Data)])>((0, [:]))

    var documentCount: Int { storage.withLock { $0.documents.count } }

    func push(_ records: [EncryptedRecord]) {
        storage.withLock { storage in
            for record in records {
                storage.clock += 1
                storage.documents[record.documentID] = (storage.clock, record.envelope)
            }
        }
    }

    func pull(after cursor: String?) -> (records: [EncryptedRecord], cursor: String?) {
        let position = cursor.flatMap { Int($0) } ?? 0
        let page = storage.withLock { $0.documents }
            .filter { $0.value.stamp > position }
            .sorted { $0.value.stamp < $1.value.stamp }
        guard let last = page.last else { return ([], cursor) }
        let records = page.map {
            EncryptedRecord(documentID: $0.key, updatedAt: Date(timeIntervalSince1970: Double($0.value.stamp)),
                            envelope: $0.value.envelope)
        }
        return (records, String(last.value.stamp))
    }
}

/// Сеть одного телефона до `FakeSyncServer`: можно выключить и можно задержать забор.
final class FakeSyncTransport: SyncTransport {
    struct Offline: Error {}

    let server: FakeSyncServer
    private let offline = Atomic(false)
    /// Вызывается перед каждым забором: тест может придержать синхронизацию посередине.
    let beforePull: (@Sendable () async -> Void)?

    init(server: FakeSyncServer = FakeSyncServer(), beforePull: (@Sendable () async -> Void)? = nil) {
        self.server = server
        self.beforePull = beforePull
    }

    var isOffline: Bool {
        get { offline.load(ordering: .relaxed) }
        set { offline.store(newValue, ordering: .relaxed) }
    }

    func push(_ records: [EncryptedRecord], coupleID: String) async throws {
        guard !isOffline else { throw Offline() }
        server.push(records)
    }

    func pull(coupleID: String, after cursor: String?) async throws -> (records: [EncryptedRecord], cursor: String?) {
        await beforePull?()
        guard !isOffline else { throw Offline() }
        return server.pull(after: cursor)
    }
}

/// Задвижка для теста: синхронизация ждёт у `wait`, пока тест не откроет.
actor Gate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var arrivals: [CheckedContinuation<Void, Never>] = []
    private var arrived = false

    func wait() async {
        arrived = true
        arrivals.forEach { $0.resume() }
        arrivals = []
        guard !isOpen else { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    /// Ждёт, пока кто-нибудь дойдёт до `wait`.
    func reached() async {
        guard !arrived else { return }
        await withCheckedContinuation { arrivals.append($0) }
    }

    func open() {
        isOpen = true
        waiters.forEach { $0.resume() }
        waiters = []
    }
}
