import Foundation
import Sync
import Testing
@testable import OneToOne

/// Запросы к таблице `records`: сервер не проверить без сети, поэтому проверяем, что именно спрашиваем.
private func decoded(_ queries: [String]) throws -> [[String: Any]] {
    try queries.map { try #require(JSONSerialization.jsonObject(with: Data($0.utf8)) as? [String: Any]) }
}

private func methods(_ queries: [[String: Any]]) -> [String] {
    queries.compactMap { $0["method"] as? String }
}

@Test func firstPageAsksWholeCoupleInOrder() throws {
    let query = RecordsPageQuery(since: nil, after: nil, limit: 100)

    let queries = try decoded(AppwriteTransport.queries(for: query, coupleID: "c1"))

    #expect(methods(queries) == ["equal", "orderAsc", "orderAsc", "limit"])
    #expect(queries[0]["attribute"] as? String == "coupleId")
    #expect(queries[0]["values"] as? [String] == ["c1"])
    #expect(queries[1]["attribute"] as? String == "$updatedAt")
    #expect(queries[2]["attribute"] as? String == "$id")
    #expect(queries[3]["values"] as? [Int] == [100])
}

@Test func nextSyncStartsFromCursorWithOverlap() throws {
    let query = RecordsPageQuery(since: "2026-10-11T09:59:58.000+00:00", after: nil, limit: 100)

    let queries = try decoded(AppwriteTransport.queries(for: query, coupleID: "c1"))

    #expect(methods(queries) == ["equal", "greaterThanEqual", "orderAsc", "orderAsc", "limit"])
    #expect(queries[1]["values"] as? [String] == ["2026-10-11T09:59:58.000+00:00"])
}

/// Следующая страница — строго после последней строки по (`$updatedAt`, `$id`), без `cursorAfter`.
@Test func nextPageGoesAfterLastRowByValues() throws {
    let after = RowPosition(updatedAt: "2026-10-11T10:00:00.123+00:00", id: "abc")
    let query = RecordsPageQuery(since: "2026-10-11T09:59:58.000+00:00", after: after, limit: 100)

    let queries = try decoded(AppwriteTransport.queries(for: query, coupleID: "c1"))
    let text = AppwriteTransport.queries(for: query, coupleID: "c1").joined()

    #expect(methods(queries) == ["equal", "or", "orderAsc", "orderAsc", "limit"])
    #expect(!text.contains("cursorAfter"))
    #expect(text.contains("greaterThan") && text.contains("\"$id\"") && text.contains("abc"))
}
