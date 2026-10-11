@preconcurrency import Appwrite
import Foundation
import Sync

/// Связь движка синхронизации с таблицей `records` в Appwrite (`Server/appwrite.config.json`).
/// Строка — документ пары: id = `documentID`, `envelope` = base64 конверта. Открытые колонки `updatedAt`
/// и `deleted` — только подсказки: пишем время отправки и всегда `false`, телефоны им не верят.
/// Права строки — только команде пары. Сессию Appwrite SDK хранит общую для всех клиентов (куки по адресу сервера),
/// поэтому здесь работает тот же вход, что в `AppwriteAuthService`.
final class AppwriteTransport: SyncTransport, @unchecked Sendable {
    static let databaseID = "main"
    static let tableID = "records"
    /// Сколько строк отправляем одновременно: первая синхронизация может отправить сотни записей.
    private static let parallelUploads = 4

    // SDK не помечен Sendable, но его клиент безопасно звать из разных задач.
    private let tables: TablesDB

    init(endpoint: String = BackendConfig.endpoint, projectID: String = BackendConfig.projectID) {
        let client = Client()
            .setEndpoint(endpoint)
            .setProject(projectID)
        tables = TablesDB(client)
    }

    func push(_ records: [EncryptedRecord], coupleID: String) async throws {
        let team = Role.team(coupleID)
        let permissions = [Permission.read(team), Permission.update(team), Permission.delete(team)]
        try await withThrowingTaskGroup(of: Void.self) { group in
            for (index, record) in records.enumerated() {
                if index >= Self.parallelUploads { try await group.next() }
                group.addTask {
                    _ = try await self.tables.upsertRow(
                        databaseId: Self.databaseID,
                        tableId: Self.tableID,
                        rowId: record.documentID,
                        data: [
                            "coupleId": coupleID,
                            "envelope": record.envelope.base64EncodedString(),
                            "updatedAt": RecordsPuller.string(from: Date()),
                            "deleted": false,
                        ],
                        permissions: permissions
                    )
                }
            }
            try await group.waitForAll()
        }
    }

    func pull(coupleID: String, after cursor: String?) async throws -> (records: [EncryptedRecord], cursor: String?) {
        try await RecordsPuller.pull(after: cursor) { query in
            let list = try await tables.listRows(
                databaseId: Self.databaseID,
                tableId: Self.tableID,
                queries: Self.queries(for: query, coupleID: coupleID),
                total: false
            )
            return list.rows.map { row in
                // Битый base64 — пустой конверт: движок его пропустит, а курсор уйдёт дальше.
                let envelope = (row.data["envelope"]?.value as? String).flatMap { Data(base64Encoded: $0) }
                return RecordRow(id: row.id, updatedAt: row.updatedAt, envelope: envelope ?? Data())
            }
        }
    }

    /// Запросы одной страницы. Следующая страница — строго после последней строки по значениям
    /// (`$updatedAt`, затем `$id`), см. `RecordsPuller`.
    static func queries(for query: RecordsPageQuery, coupleID: String) -> [String] {
        var queries = [Query.equal("coupleId", value: coupleID)]
        if let after = query.after {
            queries.append(Query.or([
                Query.greaterThan("$updatedAt", value: after.updatedAt),
                Query.and([
                    Query.equal("$updatedAt", value: after.updatedAt),
                    Query.greaterThan("$id", value: after.id),
                ]),
            ]))
        } else if let since = query.since {
            queries.append(Query.greaterThanEqual("$updatedAt", value: since))
        }
        queries += [Query.orderAsc("$updatedAt"), Query.orderAsc("$id"), Query.limit(query.limit)]
        return queries
    }
}
