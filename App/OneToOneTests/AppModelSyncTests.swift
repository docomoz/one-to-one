import Core
import Foundation
import Sync
import Testing
@testable import OneToOne

private let man = Person(id: UUID(uuidString: "00000000-0000-0000-0000-00000000000A")!, name: "Максим", sex: .male)
private let woman = Person(id: UUID(uuidString: "00000000-0000-0000-0000-00000000000B")!, name: "Даша", sex: .female)
private let coupleID = "test-couple"
private let day = DayKey(year: 2026, month: 10, day: 11)

private func sexEntry(by person: Person) -> SexEntry {
    SexEntry(day: day, types: [.vaginal], orgasmsMan: 1, orgasmsWoman: 1, createdBy: person.id)
}

/// Телефон пары с запущенной синхронизацией. Без автосинхронизации: тест сам решает, когда синхронизировать.
@MainActor
private func phone(me: Person, transport: FakeSyncTransport, key: CoupleKey,
                   syncStore: InMemorySyncStateStore = InMemorySyncStateStore()) -> AppModel {
    var data = AppData()
    data.meID = me.id
    let model = AppModel(store: InMemoryStore(data), syncStateStore: syncStore)
    model.autoSyncDelay = nil
    model.startSync(coupleID: coupleID, key: key, transport: transport)
    return model
}

@MainActor
@Test func updateQueuesChange() async throws {
    let syncStore = InMemorySyncStateStore()
    let model = phone(me: man, transport: FakeSyncTransport(), key: CoupleKey(), syncStore: syncStore)
    let entry = sexEntry(by: man)

    model.update { $0.sexEntries.append(entry) }
    await model.syncChangesRecorded()

    let id = "sex:\(entry.id.uuidString)"
    #expect(await model.syncState?.outbox[id]?.payload != nil)
    // Очередь переживает перезапуск: состояние сохранено сразу после правки.
    #expect(syncStore.load(coupleID: coupleID).outbox[id] != nil)
}

@MainActor
@Test func partnerChangeAppearsAfterSync() async throws {
    let server = FakeSyncServer()
    let key = CoupleKey()
    let her = phone(me: woman, transport: FakeSyncTransport(server: server), key: key)
    let him = phone(me: man, transport: FakeSyncTransport(server: server), key: key)
    let entry = sexEntry(by: man)

    him.update { $0.sexEntries.append(entry) }
    await him.syncNow()
    await her.syncNow()

    #expect(her.data.sexEntries == [entry])
    #expect(her.data.meID == woman.id)
    #expect(her.syncStatus.lastError == nil)
    #expect(her.syncStatus.lastSuccess != nil)
}

@MainActor
@Test func syncFailureKeepsLocalData() async throws {
    let transport = FakeSyncTransport()
    transport.isOffline = true
    let model = phone(me: man, transport: transport, key: CoupleKey())
    let entry = sexEntry(by: man)

    model.update { $0.sexEntries.append(entry) }
    await model.syncNow()

    #expect(model.data.sexEntries == [entry])
    #expect(model.syncStatus.lastError != nil)
    #expect(await model.syncState?.outbox.isEmpty == false)

    transport.isOffline = false
    await model.syncNow()

    #expect(model.syncStatus.lastError == nil)
    #expect(await model.syncState?.outbox.isEmpty == true)
    #expect(transport.server.documentCount == 1)
}

/// Пока идёт запрос, человек правит данные: результат синхронизации не откатывает ни правку, ни «кто я».
@MainActor
@Test func editDuringSyncNotRolledBack() async throws {
    let server = FakeSyncServer()
    let key = CoupleKey()
    let him = phone(me: man, transport: FakeSyncTransport(server: server), key: key)
    him.update { $0.sexEntries.append(sexEntry(by: man)) }
    await him.syncNow()
    let gate = Gate()
    let her = phone(me: woman, transport: FakeSyncTransport(server: server, beforePull: { await gate.wait() }), key: key)

    let syncing = Task { await her.syncNow() }
    await gate.reached()
    her.update {
        $0.periodDays.insert(day)
        $0.meID = man.id
    }
    await gate.open()
    await syncing.value

    #expect(her.data.periodDays == [day])
    #expect(her.data.meID == man.id)
    #expect(her.data.sexEntries.count == 1)
}

@MainActor
@Test func withoutStartedSyncNothingQueued() async throws {
    let model = AppModel(store: InMemoryStore(), syncStateStore: InMemorySyncStateStore())

    model.update { $0.periodDays.insert(day) }
    await model.syncNow()

    #expect(await model.syncState == nil)
    #expect(model.syncStatus.lastSuccess == nil)
}
