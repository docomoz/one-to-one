import Core
import Foundation
import Testing
@testable import Sync

private func day(_ number: Int) -> DayKey { DayKey(year: 2026, month: 10, day: number) }

// Что пропадёт при выходе из аккаунта: правки в очереди и записи, которых сервер ещё не видел.

@Test func nothingUnsentAfterSync() async throws {
    var data = AppData()
    data.periodDays = [day(1)]
    let engine = SyncEngine(coupleID: "c", key: CoupleKey(), transport: FakeTransport(server: FakeServer()),
                            state: SyncState())
    _ = try await engine.sync(local: data)

    #expect(await !engine.state.hasUnsentChanges(in: data))
}

@Test func queuedEditIsUnsent() async {
    let data = AppData()
    let engine = SyncEngine(coupleID: "c", key: CoupleKey(), transport: FakeTransport(server: FakeServer()),
                            state: SyncState())
    var edited = data
    edited.periodDays = [day(2)]
    await engine.recordLocalChange(from: data, to: edited, now: Date())

    #expect(await engine.state.hasUnsentChanges(in: edited))
}

@Test func recordUnknownToEngineIsUnsent() {
    // Запись сделана до синхронизации: в очереди её нет, но и на сервере тоже.
    var data = AppData()
    data.periodDays = [day(3)]

    #expect(SyncState().hasUnsentChanges(in: data))
    #expect(!SyncState().hasUnsentChanges(in: AppData()))
}
