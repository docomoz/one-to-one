import Core
import Foundation
import Testing
@testable import Sync

private let man = Person(id: UUID(uuidString: "00000000-0000-0000-0000-00000000000A")!, name: "Боря", sex: .male)
private let woman = Person(id: UUID(uuidString: "00000000-0000-0000-0000-00000000000B")!, name: "Аня", sex: .female)
private let coupleID = "6708f1c2a9b3e4d5c6f7"
private let day = DayKey(year: 2026, month: 10, day: 11)

private func at(_ seconds: Double) -> Date { Date(timeIntervalSinceReferenceDate: 813_000_000 + seconds) }

/// Один телефон пары: свой движок, своя сеть до общего сервера и данные, которые видят экраны.
private struct Device {
    let engine: SyncEngine
    let transport: FakeTransport
    var data: AppData

    init(server: FakeServer, key: CoupleKey, me: Person, state: SyncState = SyncState()) {
        transport = FakeTransport(server: server)
        engine = SyncEngine(coupleID: coupleID, key: key, transport: transport, state: state)
        data = AppData()
        data.meID = me.id
    }

    /// Правка на экране: как `AppModel.update`, движку уходят данные до и после.
    mutating func edit(at seconds: Double, _ change: (inout AppData) -> Void) async {
        let old = data
        change(&data)
        await engine.recordLocalChange(from: old, to: data, now: at(seconds))
    }

    mutating func sync() async throws {
        data = try await engine.sync(local: data)
    }
}

/// Два телефона одной пары на одном сервере.
private func pair(_ server: FakeServer = FakeServer()) -> (Device, Device, CoupleKey) {
    let key = CoupleKey()
    return (Device(server: server, key: key, me: woman), Device(server: server, key: key, me: man), key)
}

private func sex(_ id: Int, by person: Person) -> SexEntry {
    SexEntry(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000D\(id)")!, day: day,
             types: [.vaginal], orgasmsMan: 1, orgasmsWoman: 1, createdBy: person.id)
}

private func documentID(_ recordID: String, _ key: CoupleKey) -> String {
    RecordIDHasher.documentID(for: recordID, key: key)
}

// MARK: - Обмен между двумя телефонами

/// Review Focus 2: она отмечает месячные, он без сети записывает секс, потом оба выходят в сеть.
@Test func twoDevicesConcurrentEditsBothSurvive() async throws {
    var (her, his, _) = pair()
    his.transport.isOffline = true

    await her.edit(at: 1) { $0.periodDays.insert(day) }
    await his.edit(at: 2) { $0.sexEntries.append(sex(1, by: man)) }
    try await her.sync()
    await #expect(throws: FakeTransport.Offline.self) { try await his.sync() }
    his.transport.isOffline = false
    try await his.sync()
    try await her.sync()

    for device in [her, his] {
        #expect(device.data.periodDays == [day])
        #expect(device.data.sexEntries == [sex(1, by: man)])
    }
}

@Test func offlineChangeSentLater() async throws {
    var (her, his, _) = pair()
    her.transport.isOffline = true

    await her.edit(at: 1) { $0.herMoods[day] = .wants }
    await #expect(throws: FakeTransport.Offline.self) { try await her.sync() }
    #expect(await her.engine.state.outbox.count == 1)
    #expect(her.data.herMoods[day] == .wants)

    her.transport.isOffline = false
    try await her.sync()
    try await his.sync()

    #expect(await her.engine.state.outbox.isEmpty)
    #expect(his.data.herMoods[day] == .wants)
}

@Test func deletionReachesPartner() async throws {
    var (her, his, _) = pair()
    await his.edit(at: 1) { $0.sexEntries = [sex(1, by: man), sex(2, by: man)] }
    try await his.sync()
    try await her.sync()
    #expect(her.data.sexEntries.count == 2)

    await his.edit(at: 2) { $0.sexEntries.removeAll { $0.id == sex(1, by: man).id } }
    try await his.sync()
    try await her.sync()

    #expect(her.data.sexEntries == [sex(2, by: man)])
    #expect(his.data.sexEntries == [sex(2, by: man)])
}

@Test func laterEditOfSameRecordWinsOnBothDevices() async throws {
    var (her, his, _) = pair()
    await her.edit(at: 1) { $0.herMoods[day] = .wants }
    try await her.sync()
    try await his.sync()

    // Оба правят одну запись без связи; позже правила она.
    her.transport.isOffline = true
    await his.edit(at: 2) { $0.herMoods[day] = .neutral }
    await her.edit(at: 3) { $0.herMoods[day] = .leaveMeAlone }
    try await his.sync()
    her.transport.isOffline = false
    try await her.sync()
    try await his.sync()

    #expect(her.data.herMoods[day] == .leaveMeAlone)
    #expect(his.data.herMoods[day] == .leaveMeAlone)
}

/// Она правила позже, но синхронизировалась раньше: его более старая правка не побеждает.
@Test func olderEditSyncedLaterLoses() async throws {
    var (her, his, _) = pair()
    await his.edit(at: 1) { $0.herMoods[day] = .neutral }
    await her.edit(at: 2) { $0.herMoods[day] = .wants }
    try await her.sync()
    try await his.sync()
    try await her.sync()
    try await his.sync()

    #expect(her.data.herMoods[day] == .wants)
    #expect(his.data.herMoods[day] == .wants)
}

/// Часы партнёра спешат: правка на этом телефоне всё равно новее версии, которую правили.
@Test func localEditBeatsPartnerRecordFromFuture() async throws {
    var (her, his, _) = pair()
    await his.edit(at: 1000) { $0.herMoods[day] = .neutral }
    try await his.sync()
    try await her.sync()

    await her.edit(at: 1) { $0.herMoods[day] = .wants }
    try await her.sync()
    try await his.sync()

    #expect(her.data.herMoods[day] == .wants)
    #expect(his.data.herMoods[day] == .wants)
}

/// Review Focus 3: порции по 2 документа с одинаковым временем на сервере.
@Test func pullDoesNotLoseEqualTimestamps() async throws {
    var (her, his, _) = pair(FakeServer(pageSize: 2, frozenClock: true))
    let days = (0..<5).map { day.adding(days: $0) }

    await her.edit(at: 1) { $0.periodDays = Set(days) }
    try await her.sync()
    try await his.sync()

    #expect(his.data.periodDays == Set(days))
}

// MARK: - Правки только этого телефона

@Test func unchangedDataQueuesNothing() async throws {
    var (her, his, _) = pair()
    await her.edit(at: 1) { $0.periodDays.insert(day) }
    try await her.sync()
    try await his.sync()

    await his.edit(at: 2) { _ in }
    await his.edit(at: 3) { $0.meID = nil }

    #expect(await his.engine.state.outbox.isEmpty)
}

/// Приложение ещё не показало результат синхронизации, а пользователь уже правит старые данные.
/// Записей партнёра в старых данных нет, но это не их удаление.
@Test func editOnStaleDataKeepsPartnerRecords() async throws {
    var (her, his, _) = pair()
    await her.edit(at: 1) { $0.periodDays.insert(day) }
    try await her.sync()

    let stale = his.data
    _ = try await his.engine.sync(local: stale)
    await his.edit(at: 2) { $0.sexEntries.append(sex(1, by: man)) }
    try await his.sync()
    try await her.sync()

    #expect(his.data.periodDays == [day])
    #expect(her.data.periodDays == [day])
    #expect(her.data.sexEntries == [sex(1, by: man)])
}

/// Записи, сделанные до синхронизации (или потерянный `SyncState.json`), не стираются первой синхронизацией,
/// а уходят партнёру. С записями с сервера проигрывают: там они уже слиты.
@Test func neverSyncedLocalDataIsUploadedNotErased() async throws {
    var (her, his, _) = pair()
    await his.edit(at: 1) { $0.herMoods[day] = .neutral }
    try await his.sync()
    her.data.periodDays = [day]
    her.data.herMoods[day] = .wants

    try await her.sync()
    try await his.sync()

    #expect(her.data.periodDays == [day])
    #expect(his.data.periodDays == [day])
    #expect(her.data.herMoods[day] == .neutral)
    #expect(his.data.herMoods[day] == .neutral)
}

/// Удалённую партнёром запись старые данные телефона не воскрешают.
@Test func staleLocalDataDoesNotReviveDeletion() async throws {
    var (her, his, _) = pair()
    await his.edit(at: 1) { $0.periodDays = [day] }
    try await his.sync()
    try await her.sync()
    await his.edit(at: 2) { $0.periodDays = [] }
    try await his.sync()

    try await her.sync()
    try await his.sync()

    #expect(her.data.periodDays.isEmpty)
    #expect(his.data.periodDays.isEmpty)
}

/// Синхронизация после каждой правки, по таймеру и при возврате в приложение может начаться, пока идёт прошлая.
@Test func overlappingSyncsReturnEverything() async throws {
    var (her, his, _) = pair(FakeServer(pageSize: 1))
    await her.edit(at: 1) { $0.periodDays = Set((0..<6).map { day.adding(days: $0) }) }
    try await her.sync()

    let engine = his.engine
    let local = his.data
    async let first = engine.sync(local: local)
    async let second = engine.sync(local: local)
    let results = try await [first, second]

    for result in results { #expect(result.periodDays.count == 6) }
}

/// Транспорт отдал записи без курсора: движок не начинает заново с начала и не зацикливается.
@Test func pageWithoutCursorEndsPull() async throws {
    struct NoCursor: SyncTransport {
        let server: FakeServer
        func push(_ records: [EncryptedRecord], coupleID: String) async throws { server.push(records, coupleID: coupleID) }
        func pull(coupleID: String, after cursor: String?) async throws -> (records: [EncryptedRecord], cursor: String?) {
            (server.pull(coupleID: coupleID, after: cursor).records, nil)
        }
    }
    let server = FakeServer()
    var (her, _, key) = pair(server)
    await her.edit(at: 1) { $0.periodDays = [day] }
    try await her.sync()
    let engine = SyncEngine(coupleID: coupleID, key: key, transport: NoCursor(server: server), state: SyncState())

    let result = try await engine.sync(local: AppData())

    #expect(result.periodDays == [day])
}

@Test func syncKeepsLocalFields() async throws {
    var (her, _, _) = pair()
    her.data.movieCache = [1: Movie(id: 1, title: "Фильм", year: 2000, genres: [], overview: "", posterURL: nil)]
    let local = her.data

    try await her.sync()

    #expect(her.data.meID == woman.id)
    #expect(her.data.movieCache == local.movieCache)
}

// MARK: - Записи новых видов

/// Партнёр на новой версии приложения прислал запись вида, которого мы не знаем.
@Test func unknownKindNeverTombstoned() async throws {
    var (her, his, key) = pair()
    let future = SyncRecord(id: "future:1", updatedAt: at(1), payload: Data("{}".utf8))
    let futureDocument = documentID(future.id, key)
    try his.transport.server.push([sealed(future, key)], coupleID: coupleID)

    try await her.sync()
    await her.edit(at: 2) { $0.periodDays.insert(day) }
    try await her.sync()
    try await his.sync()

    #expect(await her.engine.state.known[future.id] == future)
    #expect(await her.engine.state.outbox.isEmpty)
    let onServer = try #require(his.transport.server.documents(coupleID: coupleID)[futureDocument])
    #expect(RecordSealer.open(onServer.envelope, documentID: futureDocument, coupleID: coupleID, key: key) == future)
}

// MARK: - Сервер, которому не верим

/// Review Focus 6: сервер отдаёт старый конверт документа с новым временем на сервере.
@Test func replayedOldEnvelopeLoses() async throws {
    var (her, his, key) = pair()
    let mood = documentID("herMood:2026-10-11", key)
    await her.edit(at: 1) { $0.herMoods[day] = .wants }
    try await her.sync()
    let old = try #require(her.transport.server.documents(coupleID: coupleID)[mood]).envelope
    await her.edit(at: 2) { $0.herMoods[day] = .leaveMeAlone }
    try await her.sync()
    try await his.sync()

    her.transport.server.forge(documentID: mood, envelope: old, coupleID: coupleID)
    try await his.sync()
    try await her.sync()

    #expect(his.data.herMoods[day] == .leaveMeAlone)
    #expect(her.data.herMoods[day] == .leaveMeAlone)
    // Телефон заметил старьё и отправил новую версию снова: новый телефон пары получит её, а не откат.
    let healed = try #require(her.transport.server.documents(coupleID: coupleID)[mood]).envelope
    let record = RecordSealer.open(healed, documentID: mood, coupleID: coupleID, key: key)
    #expect(record?.payload == Data(#""leaveMeAlone""#.utf8))
}

/// Review Focus 6: сервер «удаляет» документ (пустой конверт) или подменяет конверт мусором или чужим документом.
@Test(arguments: ["empty", "garbage", "otherDocument"])
func forgedDeletionIgnored(forgery: String) async throws {
    var (her, his, key) = pair()
    let entry = sex(1, by: man)
    await his.edit(at: 1) { $0.sexEntries = [entry, sex(2, by: man)] }
    try await his.sync()
    try await her.sync()

    let server = his.transport.server
    let target = documentID(SyncRecordID.sex(entry), key)
    let envelope: Data
    switch forgery {
    case "empty": envelope = Data()
    case "garbage": envelope = Data([0x01]) + Data(repeating: 0xAB, count: 60)
    default:
        let other = documentID(SyncRecordID.sex(sex(2, by: man)), key)
        envelope = try #require(server.documents(coupleID: coupleID)[other]).envelope
    }
    server.forge(documentID: target, envelope: envelope, coupleID: coupleID)
    try await her.sync()
    try await his.sync()

    #expect(her.data.sexEntries.count == 2)
    #expect(his.data.sexEntries.count == 2)
}

/// Запись правильно зашифрована, но лежит не в своём документе: её id даёт другой `documentID`.
@Test func recordInWrongDocumentSkipped() async throws {
    var (her, _, key) = pair()
    let mood = SyncRecord(id: "herMood:2026-10-11", updatedAt: at(1), payload: Data(#""wants""#.utf8))
    let otherDocument = documentID("period:2026-10-11", key)
    let envelope = try RecordSealer.seal(mood, documentID: otherDocument, coupleID: coupleID, key: key)
    her.transport.server.push([EncryptedRecord(documentID: otherDocument, updatedAt: at(1), envelope: envelope)],
                              coupleID: coupleID)

    try await her.sync()

    #expect(her.data.herMoods.isEmpty)
    #expect(await her.engine.state.known.isEmpty)
}

@Test func undecryptableRecordSkipped() async throws {
    var (her, his, _) = pair()
    let stranger = SyncRecord(id: "period:2026-10-12", updatedAt: at(1), payload: Data("{}".utf8))
    her.transport.server.push([try sealed(stranger, CoupleKey())], coupleID: coupleID)
    await his.edit(at: 2) { $0.periodDays.insert(day) }
    try await his.sync()

    try await her.sync()

    #expect(her.data.periodDays == [day])
}

@Test func serverSeesNoPlaintext() async throws {
    var (her, _, _) = pair()
    await her.edit(at: 1) {
        $0.couple = try? Couple.make(man, woman)
        $0.periodDays.insert(day)
        $0.sexEntries.append(sex(1, by: man))
        $0.herMoods[day] = .wants
    }
    try await her.sync()

    let documents = her.transport.server.documents(coupleID: coupleID)
    #expect(documents.count == 4)
    let forbidden = ["period", "sex", "herMood", "couple", "2026", "Аня", "Боря", "wants"].map { Data($0.utf8) }
    for (id, document) in documents {
        // Только hex: ни вида, ни даты в id нет.
        #expect(id.count == 32 && id.allSatisfy(\.isHexDigit))
        for word in forbidden {
            #expect(document.envelope.firstRange(of: word) == nil)
        }
    }
}

/// Формат из `docs/crypto.md`: его должны повторить Android и веб.
@Test func sealedPlaintextFormat() throws {
    let key = CoupleKey()
    let id = documentID("period:2026-10-11", key)
    let time = Date(timeIntervalSinceReferenceDate: 813_000_000.5)
    func plaintext(_ payload: Data?) throws -> String {
        let record = SyncRecord(id: "period:2026-10-11", updatedAt: time, payload: payload)
        let envelope = try RecordSealer.seal(record, documentID: id, coupleID: coupleID, key: key)
        return String(decoding: try RecordCipher.open(envelope, documentID: id, coupleID: coupleID, key: key), as: UTF8.self)
    }

    #expect(try plaintext(Data("{}".utf8)) == #"{"id":"period:2026-10-11","payload":"e30=","updatedAt":813000000.5}"#)
    #expect(try plaintext(nil) == #"{"id":"period:2026-10-11","payload":null,"updatedAt":813000000.5}"#)
}

// MARK: - Состояние между запусками

@Test func savedStateSendsOutboxAfterRestart() async throws {
    let server = FakeServer()
    var (her, his, key) = pair(server)
    her.transport.isOffline = true
    await her.edit(at: 1) { $0.periodDays.insert(day) }
    await #expect(throws: FakeTransport.Offline.self) { try await her.sync() }

    let saved = try JSONEncoder().encode(await her.engine.state)
    var restarted = Device(server: server, key: key, me: woman,
                           state: try JSONDecoder().decode(SyncState.self, from: saved))
    restarted.data = her.data
    try await restarted.sync()
    try await his.sync()

    #expect(his.data.periodDays == [day])
}

private func sealed(_ record: SyncRecord, _ key: CoupleKey) throws -> EncryptedRecord {
    let id = documentID(record.id, key)
    let envelope = try RecordSealer.seal(record, documentID: id, coupleID: coupleID, key: key)
    return EncryptedRecord(documentID: id, updatedAt: at(0), envelope: envelope)
}
