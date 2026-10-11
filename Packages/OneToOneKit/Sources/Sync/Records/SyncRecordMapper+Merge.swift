import Core
import Foundation

extension SyncRecordMapper {
    /// Результат синхронизации поверх данных, которые на экране сейчас. `synced` движок собрал из данных
    /// на момент начала синхронизации (`started`), а пока шёл запрос, на телефоне могли поправить данные
    /// (`current`). Такие правки остаются: движок их уже получил и отправит в следующий раз.
    /// Локальные поля (`meID`, `movieCache`) всегда из `current`.
    public static func merge(synced: AppData, startedFrom started: AppData, into current: AppData) -> AppData {
        var merged = payloads(from: synced)
        let before = payloads(from: started)
        let now = payloads(from: current)
        for id in Set(before.keys).union(now.keys) where before[id] != now[id] {
            merged[id] = now[id]
        }
        return apply(merged, to: current)
    }
}
