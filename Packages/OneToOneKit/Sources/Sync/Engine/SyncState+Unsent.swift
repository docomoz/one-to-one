import Core

extension SyncState {
    /// Есть ли на телефоне то, чего нет на сервере: правки в очереди или записи `local`, о которых движок
    /// ещё не знает (сделаны до первой синхронизации). Это пропадёт, если стереть данные телефона.
    public func hasUnsentChanges(in local: AppData) -> Bool {
        guard outbox.isEmpty else { return true }
        return SyncRecordMapper.payloads(from: local).contains { id, payload in known[id]?.payload != payload }
    }
}
