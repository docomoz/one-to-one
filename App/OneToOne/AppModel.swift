import Core
import Foundation
import Observation
import OSLog
import Sync

/// Держит все данные приложения и сохраняет их после каждого изменения.
@Observable @MainActor
final class AppModel {
    private(set) var data: AppData
    @ObservationIgnored private let store: Store
    /// Рекомендации Кинопоиска по подборам: просим их один раз на подбор, лимит 200 запросов в день.
    @ObservationIgnored var recommendationsByPick: [UUID: [Movie]] = [:]
    /// «Похожие» на фильмы с 👎 и для каких именно фильмов их получили. Новый 👎 — новый запрос,
    /// иначе берём запомненные: колоду открывают много раз, а лимит 200 запросов в день.
    @ObservationIgnored var dislikeFilter: (dislikes: [Int], similar: Set<Int>)?

    // Синхронизация с партнёром (`AppModel+Sync`). Пока пары на сервере нет, `syncEngine` пуст и ничего не уходит.
    @ObservationIgnored let syncStateStore: any SyncStateStoring
    @ObservationIgnored var syncEngine: SyncEngine?
    @ObservationIgnored var syncCoupleID: String?
    /// Последняя задача, которая передаёт правку движку: правки уходят строго по очереди.
    @ObservationIgnored var pendingSyncChange: Task<Void, Never>?
    /// Отложенная синхронизация после правки: несколько быстрых правок уходят одним запросом.
    @ObservationIgnored var scheduledSync: Task<Void, Never>?
    /// Через сколько после правки синхронизировать. `nil` — не синхронизировать после правки (тесты).
    @ObservationIgnored var autoSyncDelay: Duration? = .seconds(2)
    /// Для экранов: идёт ли синхронизация, когда прошла и чем закончилась последняя.
    var syncStatus = SyncStatus()

    init(store: Store, syncStateStore: any SyncStateStoring = InMemorySyncStateStore()) {
        self.store = store
        self.syncStateStore = syncStateStore
        do {
            data = try store.load()
        } catch {
            Self.log.error("Не удалось загрузить данные: \(error)")
            data = AppData()
        }
    }

    /// Меняет данные, сразу сохраняет и ставит правку в очередь партнёру: `model.update { $0.meID = me.id }`.
    func update(_ change: (inout AppData) -> Void) {
        let old = data
        change(&data)
        save()
        queueSyncChange(from: old, to: data)
    }

    /// Подменяет данные целиком (результат синхронизации) и сохраняет. Партнёру это не отправляется.
    func replaceData(_ new: AppData) {
        guard new != data else { return }
        data = new
        save()
    }

    private func save() {
        do {
            try store.save(data)
        } catch {
            Self.log.error("Не удалось сохранить данные: \(error)")
        }
    }

    private static let log = Logger(subsystem: "com.docomoz.onetoone", category: "AppModel")
}
