import Foundation
import Sync

/// Код приглашения в пару: 8 символов, живёт 7 дней (`create-invite`, docs/server.md).
struct InviteCode: Equatable, Sendable {
    let code: String
    let expiresAt: Date
}

/// Пара на сервере: функции `create-couple`, `create-invite`, `accept-invite`, `leave-couple`
/// и таблица `keyRequests` для передачи ключа. Ошибки — `PairingError`.
protocol PairingService: Sendable {
    /// Создаёт пару с этим id (повтор с тем же id безопасен). Возвращает id пары.
    func createCouple(coupleID: String) async throws -> String
    func createInvite(coupleID: String) async throws -> InviteCode
    /// Входит в пару по коду. Возвращает id пары.
    func acceptInvite(code: String) async throws -> String
    func leaveCouple(coupleID: String) async throws
    /// Сколько человек в паре (подтверждённых).
    func memberCount(coupleID: String) async throws -> Int

    /// Новый запрос ключа: в строке только обязательство (`waiting`).
    func createKeyRequest(coupleID: String, commitment: Data, expiresAt: Date) async throws -> KeyRequest
    /// Запрос по id; `nil`, если его уже нет (удалили или срок вышел и его убрали).
    func keyRequest(id: String) async throws -> KeyRequest?
    /// Все запросы ключа пары.
    func keyRequests(coupleID: String) async throws -> [KeyRequest]
    func update(_ request: KeyRequest, with update: KeyRequestUpdate) async throws
}
