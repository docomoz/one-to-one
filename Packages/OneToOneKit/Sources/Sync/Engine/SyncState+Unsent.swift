import Core

extension SyncState {
    /// Есть ли на телефоне то, чего нет на сервере: правки в очереди или записи `local`, о которых движок
    /// ещё не знает (сделаны до первой синхронизации). Это пропадёт, если стереть данные телефона.
    public func hasUnsentChanges(in local: AppData) -> Bool {
        guard outbox.isEmpty else { return true }
        // Сравниваем записи после одного и того же разбора и кодирования: байты с сервера (например, от более новой
        // версии приложения у партнёра) могут отличаться от наших при тех же данных.
        let synced = SyncRecordMapper.apply(known.compactMapValues(\.payload), to: local)
        return SyncRecordMapper.payloads(from: synced) != SyncRecordMapper.payloads(from: local)
    }
}
