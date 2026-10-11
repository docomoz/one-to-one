import Core
import Sync

extension AppModel {
    /// Запоминает, с какого дня пара вместе. `nil` убирает дату: плашки годовщины не будет.
    func setTogetherSince(_ day: DayKey?) {
        update { $0.togetherSince = day }
    }

    /// Стирает записи пары с телефона: выход из пары, из аккаунта или удаление аккаунта.
    /// Сначала останавливает синхронизацию: иначе стирание ушло бы партнёру как удаление всех записей,
    /// а следующая пара получила бы записи этой. Пусты синхронизируемые поля, «кто я» и `SyncState.json`
    /// (в нём записи открытым текстом). Кэш фильмов остаётся: в нём ничего личного.
    func wipeCoupleData() {
        stopSync()
        clearSyncedData()
        syncStateStore.delete()
    }

    /// Синхронизируемые поля и «кто я» пусты. Партнёру это не отправляется: `replaceData`, а не `update`.
    func clearSyncedData() {
        var cleared = SyncRecordMapper.apply([:], to: data)
        cleared.meID = nil
        replaceData(cleared)
    }
}
