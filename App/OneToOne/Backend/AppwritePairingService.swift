@preconcurrency import Appwrite
import Foundation
import OSLog
import Sync

/// Пара на сервере Appwrite: функции пары (`Server/functions/`) и таблица `keyRequests`.
/// Сессию SDK хранит общую для всех клиентов, поэтому здесь работает тот же вход, что в `AppwriteAuthService`.
final class AppwritePairingService: PairingService, @unchecked Sendable {
    static let shared = AppwritePairingService(endpoint: BackendConfig.endpoint, projectID: BackendConfig.projectID)

    static let databaseID = "main"
    static let tableID = "keyRequests"

    // SDK не помечен Sendable, но его клиент безопасно звать из разных задач.
    private let functions: Functions
    private let tables: TablesDB
    private let teams: Teams
    private let account: Account

    init(endpoint: String, projectID: String) {
        let client = Client()
            .setEndpoint(endpoint)
            .setProject(projectID)
        functions = Functions(client)
        tables = TablesDB(client)
        teams = Teams(client)
        account = Account(client)
    }

    // MARK: - Функции пары

    func createCouple(coupleID: String) async throws -> String {
        try Self.coupleID(in: try await call("create-couple", ["coupleId": coupleID]))
    }

    func createInvite(coupleID: String) async throws -> InviteCode {
        let body = try await call("create-invite", ["coupleId": coupleID])
        guard let code = body["code"] as? String,
              let expiresAt = (body["expiresAt"] as? String).flatMap(RecordsPuller.date)
        else { throw PairingError.server }
        return InviteCode(code: code, expiresAt: expiresAt)
    }

    func acceptInvite(code: String) async throws -> String {
        try Self.coupleID(in: try await call("accept-invite", ["code": code]))
    }

    func leaveCouple(coupleID: String) async throws {
        _ = try await call("leave-couple", ["coupleId": coupleID])
    }

    func memberCount(coupleID: String) async throws -> Int {
        try await appwrite {
            try await teams.listMemberships(teamId: coupleID).memberships.filter(\.confirm).count
        }
    }

    // MARK: - keyRequests

    func createKeyRequest(coupleID: String, commitment: Data, expiresAt: Date) async throws -> KeyRequest {
        try await appwrite {
            let userID = try await account.get().id
            let team = Role.team(coupleID)
            let row = try await tables.createRow(
                databaseId: Self.databaseID,
                tableId: Self.tableID,
                rowId: ID.unique(),
                data: [
                    "coupleId": coupleID,
                    "requesterUserId": userID,
                    "requesterKeyCommitment": commitment.base64EncodedString(),
                    "status": KeyRequestStatus.waiting.rawValue,
                    "expiresAt": RecordsPuller.string(from: expiresAt),
                ],
                // Только паре: читать ответ и писать свой шаг может любой из двоих, больше никто.
                permissions: [Permission.read(team), Permission.update(team), Permission.delete(team)]
            )
            guard let request = Self.keyRequest(id: row.id, data: row.data.mapValues(\.value)) else {
                throw PairingError.server
            }
            return request
        }
    }

    func keyRequest(id: String) async throws -> KeyRequest? {
        do {
            return try await appwrite {
                let row = try await tables.getRow(databaseId: Self.databaseID, tableId: Self.tableID, rowId: id)
                return Self.keyRequest(id: row.id, data: row.data.mapValues(\.value))
            }
        } catch PairingError.notMember {
            return nil
        }
    }

    func keyRequests(coupleID: String) async throws -> [KeyRequest] {
        try await appwrite {
            let list = try await tables.listRows(
                databaseId: Self.databaseID,
                tableId: Self.tableID,
                queries: [Query.equal("coupleId", value: coupleID), Query.limit(100)],
                total: false
            )
            return list.rows.compactMap { Self.keyRequest(id: $0.id, data: $0.data.mapValues(\.value)) }
        }
    }

    func update(_ keyRequest: KeyRequest, with update: KeyRequestUpdate) async throws {
        try await appwrite {
            _ = try await tables.updateRow(databaseId: Self.databaseID, tableId: Self.tableID,
                                           rowId: keyRequest.id, data: Self.fields(for: update))
        }
    }

    // MARK: - Строки и ответы

    /// Строка `keyRequests` → `KeyRequest`. Битая (нет обязательных полей, кривой base64) — `nil`:
    /// такой запрос телефон пропускает.
    static func keyRequest(id: String, data: [String: Any]) -> KeyRequest? {
        func bytes(_ key: String) -> Data?? {
            guard let text = data[key] as? String, !text.isEmpty else { return .some(nil) }
            return Data(base64Encoded: text).map { .some($0) }
        }
        guard let coupleID = data["coupleId"] as? String,
              let requesterUserID = data["requesterUserId"] as? String,
              let commitment = bytes("requesterKeyCommitment") ?? nil,
              let status = (data["status"] as? String).flatMap(KeyRequestStatus.init(rawValue:)),
              let expiresAt = (data["expiresAt"] as? String).flatMap(RecordsPuller.date),
              let requesterPublicKey = bytes("requesterPublicKey"),
              let responderPublicKey = bytes("responderPublicKey"),
              let wrappedKey = bytes("wrappedKey")
        else { return nil }
        return KeyRequest(id: id, coupleID: coupleID, requesterUserID: requesterUserID,
                          requesterKeyCommitment: commitment, requesterPublicKey: requesterPublicKey,
                          responderPublicKey: responderPublicKey, wrappedKey: wrappedKey,
                          status: status, expiresAt: expiresAt)
    }

    /// Что записать в строку на шаге `update`: новое поле и статус.
    static func fields(for update: KeyRequestUpdate) -> [String: String] {
        var fields = ["status": update.status.rawValue]
        switch update {
        case .answer(let key): fields["responderPublicKey"] = key.base64EncodedString()
        case .reveal(let key): fields["requesterPublicKey"] = key.base64EncodedString()
        case .deliver(let wrapped): fields["wrappedKey"] = wrapped.base64EncodedString()
        case .reject: break
        }
        return fields
    }

    private static func coupleID(in body: [String: Any]) throws -> String {
        guard let coupleID = body["coupleId"] as? String, !coupleID.isEmpty else { throw PairingError.server }
        return coupleID
    }

    /// Вызов функции сервера. Ошибку функция возвращает в теле (`{"error": "<код>"}`) с кодом ответа,
    /// сам вызов при этом проходит.
    private func call(_ functionID: String, _ body: [String: String]) async throws -> [String: Any] {
        let execution = try await appwrite {
            let json = String(decoding: try JSONSerialization.data(withJSONObject: body), as: UTF8.self)
            return try await functions.createExecution(functionId: functionID, body: json, async: false)
        }
        let response = (try? JSONSerialization.jsonObject(with: Data(execution.responseBody.utf8))) as? [String: Any]
        guard (200..<300).contains(execution.responseStatusCode) else {
            Self.log.error("Функция \(functionID) ответила \(execution.responseStatusCode)")
            throw PairingError(functionError: response?["error"] as? String, status: execution.responseStatusCode)
        }
        return response ?? [:]
    }

    /// Запрос к Appwrite: ответ с ошибкой → `PairingError`, нет ответа → `.network`.
    private func appwrite<T>(_ action: () async throws -> T) async throws -> T {
        do {
            return try await action()
        } catch let error as PairingError {
            throw error
        } catch let error as AppwriteError {
            Self.log.error("Сервер вернул ошибку \(error.code ?? 0) \(error.type ?? ""): \(error.message)")
            switch error.code {
            case 401: throw PairingError.signedOut
            case 404: throw PairingError.notMember
            default: throw PairingError.server
            }
        } catch {
            Self.log.error("Нет ответа сервера: \(error)")
            throw PairingError.network
        }
    }

    private static let log = Logger(subsystem: "com.docomoz.onetoone", category: "Pairing")
}
