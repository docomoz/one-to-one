import Foundation

/// Строка таблицы `records`, как её вернул сервер.
public struct RecordRow: Equatable, Sendable {
    /// `$id` — он же `documentID`.
    public let id: String
    /// `$updatedAt` строкой, как прислал сервер: её же отправляем обратно в запросе, чтобы не потерять точность.
    public let updatedAt: String
    /// Конверт (в таблице лежит base64).
    public let envelope: Data

    public init(id: String, updatedAt: String, envelope: Data) {
        self.id = id
        self.updatedAt = updatedAt
        self.envelope = envelope
    }
}

/// Место строки в порядке (`$updatedAt`, `$id`).
public struct RowPosition: Equatable, Sendable {
    public let updatedAt: String
    public let id: String

    public init(updatedAt: String, id: String) {
        self.updatedAt = updatedAt
        self.id = id
    }
}

/// Одна страница: строки пары с `$updatedAt >= since`, строго после `after`, по порядку (`$updatedAt`, `$id`).
public struct RecordsPageQuery: Equatable, Sendable {
    public let since: String?
    public let after: RowPosition?
    public let limit: Int

    public init(since: String?, after: RowPosition?, limit: Int) {
        self.since = since
        self.after = after
        self.limit = limit
    }
}

/// Как забирать изменения из `records` страницами и не терять строки. Сеть — в `fetch`, здесь только порядок.
///
/// Курсор между синхронизациями — `$updatedAt` последней строки. Следующий забор начинается на `overlap` раньше:
/// строка, которую сервер сохранял дольше соседней, может появиться с более ранним временем, чем уже прочитанная.
/// Повторно прочитанные строки движку не вредят. Внутри одного забора страницы идут по значениям
/// (время и id последней строки), а не `cursorAfter(<id>)`: если эту строку поправят посреди забора,
/// она уедет в конец, и `cursorAfter` пропустил бы всё между старым и новым местом.
public enum RecordsPuller {
    public static func pull(
        after cursor: String?,
        pageSize: Int = 100,
        overlap: TimeInterval = 2,
        fetch: (RecordsPageQuery) async throws -> [RecordRow]
    ) async throws -> (records: [EncryptedRecord], cursor: String?) {
        // Непонятный курсор (другой формат) — читаем всё с начала: повтор ничего не портит.
        let since = cursor.flatMap(date).map { string(from: $0.addingTimeInterval(-overlap)) }
        var rows: [RecordRow] = []
        var after: RowPosition?
        while true {
            let page = try await fetch(RecordsPageQuery(since: since, after: after, limit: pageSize))
            rows += page
            guard page.count == pageSize, let last = page.last else { break }
            after = RowPosition(updatedAt: last.updatedAt, id: last.id)
        }
        let records = rows.map {
            EncryptedRecord(documentID: $0.id, updatedAt: date($0.updatedAt) ?? .distantPast, envelope: $0.envelope)
        }
        return (records, rows.last?.updatedAt ?? cursor)
    }

    /// Время Appwrite: `2026-10-11T10:00:00.123+00:00`, миллисекунды могут отсутствовать.
    public static func date(_ string: String) -> Date? {
        withMilliseconds.date(from: string) ?? withoutMilliseconds.date(from: string)
    }

    /// В том же виде, что присылает Appwrite, в UTC.
    public static func string(from date: Date) -> String {
        withMilliseconds.string(from: date).replacingOccurrences(of: "Z", with: "+00:00")
    }

    // ISO8601DateFormatter потокобезопасен, но не помечен Sendable. Создавать его на каждую строку дорого.
    private nonisolated(unsafe) static let withMilliseconds = formatter([.withInternetDateTime, .withFractionalSeconds])
    private nonisolated(unsafe) static let withoutMilliseconds = formatter([.withInternetDateTime])

    private static func formatter(_ options: ISO8601DateFormatter.Options) -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = options
        return formatter
    }
}
