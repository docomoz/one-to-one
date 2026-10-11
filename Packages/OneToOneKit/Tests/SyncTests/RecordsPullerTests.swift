import Core
import Foundation
import Testing
@testable import Sync

/// Таблица `records` в памяти с теми же правилами запроса, что у Appwrite в `AppwriteTransport`:
/// `$updatedAt >= since`, строго после `after` в порядке (`$updatedAt`, `$id`), не больше `limit`.
private final class FakeRecordsTable: @unchecked Sendable {
    private(set) var rows: [String: RecordRow] = [:]
    private(set) var queries: [RecordsPageQuery] = []
    /// Вызывается после каждой отданной страницы: так «сервер» меняется посреди забора.
    var afterPage: ((Int) -> Void)?

    private var clock = 0.0

    func put(_ id: String, at seconds: Double, envelope: Data = Data()) {
        rows[id] = RecordRow(id: id, updatedAt: stamp(seconds), envelope: envelope)
    }

    /// Как сервер: время ставит сам, каждая запись позже предыдущей.
    func store(_ id: String, envelope: Data) {
        clock += 1
        put(id, at: clock, envelope: envelope)
    }

    func fetch(_ query: RecordsPageQuery) -> [RecordRow] {
        queries.append(query)
        let since = query.since.flatMap(RecordsPuller.date)
        let page = rows.values
            .filter { row in since.map { RecordsPuller.date(row.updatedAt)! >= $0 } ?? true }
            .filter { row in query.after.map { Self.position(of: row) > Self.position($0) } ?? true }
            .sorted { Self.position(of: $0) < Self.position(of: $1) }
            .prefix(query.limit)
        afterPage?(queries.count)
        return Array(page)
    }

    private static func position(of row: RecordRow) -> Position {
        Position(date: RecordsPuller.date(row.updatedAt)!, id: row.id)
    }

    private static func position(_ position: RowPosition) -> Position {
        Position(date: RecordsPuller.date(position.updatedAt)!, id: position.id)
    }

    private struct Position: Comparable {
        let date: Date
        let id: String
        static func < (a: Position, b: Position) -> Bool { a.date != b.date ? a.date < b.date : a.id < b.id }
    }
}

/// Время в формате Appwrite: миллисекунды и `+00:00`.
private func stamp(_ seconds: Double) -> String {
    let date = Date(timeIntervalSince1970: 1_791_700_000 + seconds)
    return RecordsPuller.string(from: date)
}

private func id(_ number: Int) -> String { String(format: "doc%04d", number) }

private func pull(_ table: FakeRecordsTable, after cursor: String?, pageSize: Int = 100)
    async throws -> (records: [EncryptedRecord], cursor: String?) {
    try await RecordsPuller.pull(after: cursor, pageSize: pageSize) { table.fetch($0) }
}

@Test func appwriteTimeParsesAndFormats() throws {
    let date = try #require(RecordsPuller.date("2026-10-11T10:00:00.123+00:00"))
    #expect(RecordsPuller.string(from: date) == "2026-10-11T10:00:00.123+00:00")
    #expect(RecordsPuller.date("2026-10-11T13:00:00.123+03:00") == date)
    let whole = try #require(RecordsPuller.date("2026-10-11T10:00:00+00:00"))
    #expect(abs(date.timeIntervalSince(whole) - 0.123) < 0.0005)
    #expect(RecordsPuller.date("вчера") == nil)
}

@Test func pullReadsAllPagesInOrder() async throws {
    let table = FakeRecordsTable()
    for number in 1...250 { table.put(id(number), at: Double(number)) }

    let page = try await pull(table, after: nil)

    #expect(page.records.map(\.documentID) == (1...250).map(id))
    #expect(page.cursor == stamp(250))
    #expect(table.queries.count == 3)
    #expect(table.queries.allSatisfy { $0.limit == 100 })
}

@Test func emptyTableKeepsCursor() async throws {
    let table = FakeRecordsTable()

    #expect(try await pull(table, after: nil).cursor == nil)
    #expect(try await pull(table, after: stamp(5)).cursor == stamp(5))
}

/// Review Focus 3: курсор не теряет строки с одинаковым `$updatedAt` на границе страниц.
@Test func equalTimestampsNotLost() async throws {
    let table = FakeRecordsTable()
    for number in 1...5 { table.put(id(number), at: 7) }

    let page = try await pull(table, after: nil, pageSize: 2)

    #expect(page.records.map(\.documentID) == (1...5).map(id))
}

/// С `cursorAfter(<id строки>)` правка этой строки посреди забора уносила бы её в конец,
/// и строки между старым и новым местом пропали бы. Курсор по значениям так не теряет.
@Test func rowUpdatedDuringPullDoesNotHideOthers() async throws {
    let table = FakeRecordsTable()
    for number in 1...6 { table.put(id(number), at: Double(number)) }
    table.afterPage = { page in
        if page == 1 { table.put(id(2), at: 100) }
    }

    let page = try await pull(table, after: nil, pageSize: 2)

    #expect(Set(page.records.map(\.documentID)) == Set((1...6).map(id)))
    #expect(page.cursor == stamp(100))
}

/// Строка, сохранённая на сервере позже соседней, но с более ранним `$updatedAt`, приходит
/// при следующем заборе: он начинается на пару секунд раньше курсора.
@Test func nextPullRereadsOverlap() async throws {
    let table = FakeRecordsTable()
    table.put(id(1), at: 10)
    table.put(id(2), at: 11.5)
    let first = try await pull(table, after: nil)
    table.put(id(3), at: 10.5)

    let second = try await pull(table, after: first.cursor)

    #expect(second.records.map(\.documentID).contains(id(3)))
    #expect(second.cursor == stamp(11.5))
    #expect(table.queries.last?.since == stamp(9.5))
}

@Test func envelopeAndTimeReachEngine() async throws {
    let table = FakeRecordsTable()
    table.put(id(1), at: 3, envelope: Data("конверт".utf8))

    let record = try #require(try await pull(table, after: nil).records.first)

    #expect(record.envelope == Data("конверт".utf8))
    #expect(record.updatedAt == RecordsPuller.date(stamp(3)))
}

/// Транспорт поверх таблицы: как `AppwriteTransport`, но без сети.
private struct TableTransport: SyncTransport {
    let table: FakeRecordsTable

    func push(_ records: [EncryptedRecord], coupleID: String) async throws {
        for record in records { table.store(record.documentID, envelope: record.envelope) }
    }

    func pull(coupleID: String, after cursor: String?) async throws -> (records: [EncryptedRecord], cursor: String?) {
        try await RecordsPuller.pull(after: cursor, pageSize: 2) { table.fetch($0) }
    }
}

/// Повторный забор с запасом отдаёт уже виденные строки, а курсор не двигается: движок не зацикливается
/// и получает всё, что отправил партнёр.
@Test func engineWithOverlappingPullsReceivesEverything() async throws {
    let table = FakeRecordsTable()
    let key = CoupleKey()
    let her = SyncEngine(coupleID: "c1", key: key, transport: TableTransport(table: table), state: SyncState())
    let his = SyncEngine(coupleID: "c1", key: key, transport: TableTransport(table: table), state: SyncState())
    let days = (1...5).map { DayKey(year: 2026, month: 10, day: $0) }
    var herData = AppData()
    herData.periodDays = Set(days)
    await her.recordLocalChange(from: AppData(), to: herData, now: Date())
    _ = try await her.sync(local: herData)

    let hisData = try await his.sync(local: AppData())
    let queriesAfterFirstSync = table.queries.count
    _ = try await his.sync(local: hisData)

    #expect(hisData.periodDays == Set(days))
    // Второй раз ничего нового: одна страница с запасом по времени и всё.
    #expect(table.queries.count - queriesAfterFirstSync <= 2)
}
