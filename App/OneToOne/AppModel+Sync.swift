import Core
import Foundation
import OSLog
import Sync

/// Что показать о синхронизации.
struct SyncStatus: Equatable {
    var isSyncing = false
    var lastSuccess: Date?
    /// Текст ошибки последней синхронизации; `nil` — прошла или ещё не было.
    var lastError: String?
}

/// Синхронизация с партнёром: каждая правка ставится в очередь движка, синхронизация идёт после правки,
/// при запуске, при возврате в приложение и раз в минуту (`OneToOneApp`). Без сети всё работает как раньше,
/// правки уходят позже.
extension AppModel {
    /// Запускает синхронизацию этой пары. Состояние движка берётся из `SyncState.json`.
    /// Сам не синхронизирует: следом зовут `syncNow()`.
    func startSync(coupleID: String, key: CoupleKey, transport: any SyncTransport = AppwriteTransport()) {
        stopSync()
        let state = syncStateStore.load(coupleID: coupleID)
        syncEngine = SyncEngine(coupleID: coupleID, key: key, transport: transport, state: state)
        syncCoupleID = coupleID
    }

    /// Больше ничего не отправляет и не забирает. Данные и `SyncState.json` остаются.
    func stopSync() {
        scheduledSync?.cancel()
        scheduledSync = nil
        pendingSyncChange = nil
        syncEngine = nil
        syncCoupleID = nil
        syncStatus = SyncStatus()
    }

    var isSyncStarted: Bool { syncEngine != nil }

    /// Состояние движка: что известно и что ещё не отправлено. `nil` — синхронизация не запущена.
    var syncState: SyncState? {
        get async { await syncEngine?.state }
    }

    /// Забирает правки партнёра, отправляет свои и показывает результат. Ошибка (нет сети, нет входа)
    /// остаётся в `syncStatus`, данные на телефоне не меняются, очередь сохраняется до следующего раза.
    func syncNow() async {
        guard let engine = syncEngine, let coupleID = syncCoupleID else { return }
        // Правки, сделанные до этой синхронизации, должны попасть в неё.
        await syncChangesRecorded()
        let started = data
        syncStatus.isSyncing = true
        do {
            let synced = try await engine.sync(local: started)
            // Пока ждали сервер, синхронизацию могли остановить или переключить на другую пару.
            if syncEngine === engine {
                // Только синхронизируемые поля и только те записи, что не правили во время запроса:
                // иначе результат откатил бы свежие правки и локальные поля (`meID`, `movieCache`).
                replaceData(SyncRecordMapper.merge(synced: synced, startedFrom: started, into: data))
                syncStatus.lastSuccess = Date()
                syncStatus.lastError = nil
            }
        } catch {
            Self.syncLog.error("Синхронизация не удалась: \(error)")
            if syncEngine === engine { syncStatus.lastError = String(describing: error) }
        }
        let state = await engine.state
        // Остановленная или переключённая синхронизация не пишет поверх состояния новой пары.
        guard syncEngine === engine else { return }
        syncStatus.isSyncing = false
        saveSyncState(state, coupleID: coupleID)
    }

    /// Дожидается, пока движок получит все уже сделанные правки.
    func syncChangesRecorded() async {
        await pendingSyncChange?.value
    }

    /// Из `update`: правка `old` → `new` в очередь движка, затем синхронизация чуть позже.
    func queueSyncChange(from old: AppData, to new: AppData) {
        guard let engine = syncEngine, let coupleID = syncCoupleID else { return }
        let now = Date()
        let previous = pendingSyncChange
        // По очереди: если вторая правка той же записи дойдёт до движка раньше первой, победит первая.
        pendingSyncChange = Task {
            await previous?.value
            await engine.recordLocalChange(from: old, to: new, now: now)
            let state = await engine.state
            if syncEngine === engine { saveSyncState(state, coupleID: coupleID) }
        }
        scheduleSync()
    }

    private func scheduleSync() {
        guard let delay = autoSyncDelay else { return }
        scheduledSync?.cancel()
        scheduledSync = Task {
            do { try await Task.sleep(for: delay) } catch { return }
            await syncNow()
        }
    }

    private func saveSyncState(_ state: SyncState, coupleID: String) {
        do {
            try syncStateStore.save(state, coupleID: coupleID)
        } catch {
            Self.syncLog.error("Не удалось сохранить состояние синхронизации: \(error)")
        }
    }

    private static let syncLog = Logger(subsystem: "com.docomoz.onetoone", category: "Sync")
}
