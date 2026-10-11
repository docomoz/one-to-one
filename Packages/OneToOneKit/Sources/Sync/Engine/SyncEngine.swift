import Core
import Foundation

/// Синхронизация записей пары: очередь правок этого телефона, отправка, получение и слияние «поздняя правка побеждает».
/// Сервер видит только `EncryptedRecord`; слияние верит только расшифрованному.
public actor SyncEngine {
    private let coupleID: String
    private let key: CoupleKey
    private let transport: any SyncTransport
    /// Приложение сохраняет его в `SyncState.json` после каждой правки и синхронизации.
    public private(set) var state: SyncState

    public init(coupleID: String, key: CoupleKey, transport: any SyncTransport, state: SyncState) {
        self.coupleID = coupleID
        self.key = key
        self.transport = transport
        self.state = state
    }

    /// Кладёт в outbox то, что изменила правка `old` → `new`, с временем `now`.
    /// Сравниваются байты записей до и после правки, а не с `known`: если приложение ещё не показало результат
    /// синхронизации, записей партнёра нет ни в `old`, ни в `new`, и это не их удаление. Записи незнакомых видов
    /// в данных не бывает вовсе, поэтому надгробие получают только виды, которые этот телефон понимает.
    public func recordLocalChange(from old: AppData, to new: AppData, now: Date) {
        let before = SyncRecordMapper.payloads(from: old)
        let after = SyncRecordMapper.payloads(from: new)
        for (id, payload) in after where before[id] != payload {
            stage(SyncRecord(id: id, updatedAt: now, payload: payload))
        }
        for id in before.keys where after[id] == nil {
            stage(SyncRecord(id: id, updatedAt: now, payload: nil))
        }
    }

    /// Забирает новое с сервера, сливает, отправляет outbox. Возвращает `local` с синхронизируемыми полями
    /// из слитого состояния. Без сети бросает ошибку; outbox и всё, что успели слить, сохраняются.
    /// Если прошлая синхронизация ещё идёт, сначала дожидается её: курсор и outbox общие.
    public func sync(local: AppData) async throws -> AppData {
        while let running { _ = try? await running.value }
        let exchange = Task { try await self.exchange(local: local) }
        running = exchange
        try await exchange.value
        // `apply` заменяет все синхронизируемые поля, поэтому только полный набор. Незнакомые виды он пропустит.
        return SyncRecordMapper.apply(state.known.compactMapValues(\.payload), to: local)
    }

    private var running: Task<Void, any Error>?

    private func exchange(local: AppData) async throws {
        // Сбрасываем здесь, а не после `await` в `sync`: к тому времени, как ожидающие увидят конец задачи,
        // `running` уже пуст, и они не крутятся вхолостую на завершённой задаче.
        defer { running = nil }
        // Сначала забираем: тогда реже перезаписываем на сервере более новую версию партнёра своей старой.
        try await pull()
        adoptNeverSynced(local)
        try await push()
    }

    /// Записи из `local`, о которых движок ничего не знает (ни версии, ни удаления): сделаны до синхронизации
    /// или потерялся `SyncState.json`. Без этого `apply` их бы стёр. Время — самое раннее: любая версия с сервера
    /// новее, поэтому ни правку, ни удаление партнёра они не перебивают.
    private func adoptNeverSynced(_ local: AppData) {
        for (id, payload) in SyncRecordMapper.payloads(from: local) where state.known[id] == nil {
            stage(SyncRecord(id: id, updatedAt: .distantPast, payload: payload))
        }
    }

    /// Правка этого телефона всегда новее версии, которую правили, даже если часы партнёра спешат.
    private func stage(_ record: SyncRecord) {
        var record = record
        if let previous = state.known[record.id], previous.updatedAt >= record.updatedAt {
            record = SyncRecord(id: record.id, updatedAt: previous.updatedAt.addingTimeInterval(0.001),
                                payload: record.payload)
        }
        state.known[record.id] = record
        state.outbox[record.id] = record
    }

    private func pull() async throws {
        while true {
            let page = try await transport.pull(coupleID: coupleID, after: state.cursor)
            for document in page.records { merge(document) }
            // Курсора нет или он не сдвинулся — дальше спрашивать бесполезно, иначе зациклимся на ошибке сервера.
            guard !page.records.isEmpty, let next = page.cursor, next != state.cursor else { return }
            state.cursor = next
        }
    }

    /// Неоткрывшийся документ пропускаем, и курсор уходит дальше. Если когда-нибудь поменяется формат конверта,
    /// обновлённое приложение должно сбросить `cursor` в `nil`: повторное слияние ничего не портит.
    private func merge(_ document: EncryptedRecord) {
        guard let remote = RecordSealer.open(document.envelope, documentID: document.documentID,
                                             coupleID: coupleID, key: key)
        else { return }
        let local = state.known[remote.id]
        let winner = local.map { SyncMerger.winner($0, remote) } ?? remote
        if winner == remote {
            state.known[remote.id] = remote
            // Своя правка проиграла или уже лежит на сервере.
            state.outbox[remote.id] = nil
        } else {
            // На сервере версия старее нашей: сервер подсунул старый конверт или партнёр отправил старую правку
            // поверх новой. Отправляем свою снова, чтобы оба телефона сошлись.
            state.outbox[remote.id] = winner
        }
    }

    private func push() async throws {
        let batch = state.outbox
        guard !batch.isEmpty else { return }
        let documents = try batch.values.sorted { $0.id < $1.id }
            .map { try RecordSealer.seal($0, coupleID: coupleID, key: key) }
        try await transport.push(documents, coupleID: coupleID)
        // Пока ждали сервер, запись могли снова поправить: такую оставляем в очереди.
        for (id, record) in batch where state.outbox[id] == record {
            state.outbox[id] = nil
        }
    }
}
