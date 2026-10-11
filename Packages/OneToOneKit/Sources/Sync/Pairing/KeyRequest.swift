import Foundation

/// Шаг передачи ключа пары (колонка `status` таблицы `keyRequests`, `docs/server.md`).
public enum KeyRequestStatus: String, Codable, Sendable, CaseIterable {
    /// Телефон без ключа опубликовал только обязательство.
    case waiting
    /// Телефон с ключом ответил своим открытым ключом.
    case answered
    /// Телефон без ключа раскрыл свой открытый ключ. Оба показывают код.
    case revealed
    /// Коды сверили, завёрнутый ключ лежит в строке.
    case delivered
    /// Коды не совпали, кто-то отказался или раскрытый ключ не совпал с обязательством.
    case rejected
}

/// Строка `keyRequests`, как её видят телефоны: ключи уже из base64 в байтах.
/// Сервер может подменить в ней что угодно, поэтому каждое поле проверяют `KeyHandoffRequester` и `KeyHandoffResponder`.
public struct KeyRequest: Equatable, Sendable {
    public let id: String
    public let coupleID: String
    public let requesterUserID: String
    /// SHA-256 открытого ключа телефона без ключа (`KeyHandoff.commitment`).
    public var requesterKeyCommitment: Data
    public var requesterPublicKey: Data?
    public var responderPublicKey: Data?
    public var wrappedKey: Data?
    public var status: KeyRequestStatus
    public var expiresAt: Date

    public init(id: String, coupleID: String, requesterUserID: String, requesterKeyCommitment: Data,
                requesterPublicKey: Data? = nil, responderPublicKey: Data? = nil, wrappedKey: Data? = nil,
                status: KeyRequestStatus, expiresAt: Date) {
        self.id = id
        self.coupleID = coupleID
        self.requesterUserID = requesterUserID
        self.requesterKeyCommitment = requesterKeyCommitment
        self.requesterPublicKey = requesterPublicKey
        self.responderPublicKey = responderPublicKey
        self.wrappedKey = wrappedKey
        self.status = status
        self.expiresAt = expiresAt
    }

    /// Срок вышел: на такой запрос не отвечают и ключ по нему не раскрывают.
    public func isExpired(at now: Date) -> Bool {
        expiresAt <= now
    }

    /// Строка после записи `update`: так её меняет сервер. Нужна фейкам и тестам.
    public func applying(_ update: KeyRequestUpdate) -> KeyRequest {
        var result = self
        switch update {
        case .answer(let key): result.responderPublicKey = key
        case .reveal(let key): result.requesterPublicKey = key
        case .deliver(let wrapped): result.wrappedKey = wrapped
        case .reject: break
        }
        result.status = update.status
        return result
    }
}

/// Что телефон пишет в строку `keyRequests` на своём шаге.
public enum KeyRequestUpdate: Equatable, Sendable {
    case answer(responderPublicKey: Data)
    case reveal(requesterPublicKey: Data)
    case deliver(wrappedKey: Data)
    case reject

    /// Новый статус строки.
    public var status: KeyRequestStatus {
        switch self {
        case .answer: .answered
        case .reveal: .revealed
        case .deliver: .delivered
        case .reject: .rejected
        }
    }
}
