import Core
import Foundation
import Observation
import OSLog

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

    init(store: Store) {
        self.store = store
        do {
            data = try store.load()
        } catch {
            Self.log.error("Не удалось загрузить данные: \(error)")
            data = AppData()
        }
    }

    /// Меняет данные и сразу сохраняет: `model.update { $0.meID = me.id }`.
    func update(_ change: (inout AppData) -> Void) {
        change(&data)
        do {
            try store.save(data)
        } catch {
            Self.log.error("Не удалось сохранить данные: \(error)")
        }
    }

    private static let log = Logger(subsystem: "com.docomoz.onetoone", category: "AppModel")
}
