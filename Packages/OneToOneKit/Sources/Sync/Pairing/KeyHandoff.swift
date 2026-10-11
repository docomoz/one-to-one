import CryptoKit
import Foundation

/// Почему передача ключа остановилась.
public enum KeyHandoffError: Error, Equatable, Sendable {
    /// Срок запроса вышел.
    case expired
    /// Запрос отклонили: коды не совпали или человек отказался.
    case rejected
    /// Раскрытый ключ не совпал с обязательством: сервер подменил ключ.
    case commitmentMismatch
    /// Ключ второго телефона поменялся после показа кода: сервер подменил ключ.
    case keyChanged
    /// Шаг не по порядку: например, отдать ключ до проверки или ответить на уже отвеченный запрос.
    case unexpectedStatus
    /// Ключ не той длины или завёрнутый ключ не открылся.
    case invalidKey
    /// На запрос ответил другой телефон с ключом (второй телефон партнёра, гонка ответов) или сервер подменил наш ответ
    /// до показа кода. Запрос не наш: молча отходим, ключ не отдаём и запросу не отказываем.
    case answeredElsewhere
}

/// Передача ключа пары через `keyRequests` с обязательством (`docs/crypto.md`, «Перебор ключей сервером»):
/// `waiting` → `answered` → `revealed` → `delivered` или `rejected`.
/// Телефон без ключа сначала публикует только SHA-256 своего открытого ключа, а сам ключ раскрывает, когда второй
/// телефон уже ответил своим. Так сервер выбирает подмену, не зная ключа, и подобрать совпадающий код не может.
public enum KeyHandoff {
    /// Сколько живёт запрос: столько есть у партнёров, чтобы открыть приложение и сверить код.
    public static let lifetime: TimeInterval = 15 * 60

    /// Обязательство: SHA-256 открытого ключа, 32 байта.
    public static func commitment(for publicKey: Data) -> Data {
        Data(SHA256.hash(data: publicKey))
    }

    /// Запрос, на который телефону с ключом пора ответить: ждёт ответа и не просрочен. Самый новый, если их несколько.
    /// `excluding` — свои запросы этого телефона: на них он не отвечает.
    public static func pendingRequest(in requests: [KeyRequest], now: Date, excluding: Set<String> = []) -> KeyRequest? {
        requests
            .filter { $0.status == .waiting && !$0.isExpired(at: now) && !excluding.contains($0.id) }
            .max { $0.expiresAt < $1.expiresAt }
    }

    static let publicKeySize = 32
}

/// Телефон без ключа пары: вошёл по приглашению (или новый телефон, #86).
public struct KeyHandoffRequester: Sendable {
    private let pair: KeyExchangePair
    /// Ключ второго телефона, по которому посчитан код. Ключ из строки потом сверяется с ним.
    private var responderPublicKey: Data?
    private var confirmed = false

    public init(pair: KeyExchangePair = KeyExchangePair()) {
        self.pair = pair
    }

    /// Что публикуем при создании запроса вместо открытого ключа.
    public var commitment: Data { KeyHandoff.commitment(for: pair.publicKey) }

    /// Код для сверки; есть после раскрытия ключа.
    public var verificationCode: String? {
        responderPublicKey.map { KeyExchange.verificationCode(pair.publicKey, $0) }
    }

    /// Раскрыть свой ключ, если второй телефон уже ответил. `nil` — ещё не ответил или раскрытие уже на сервере.
    /// Если раскрытие не дошло до сервера (потерялся ответ), повторный вызов вернёт его же: отправить ещё раз.
    public mutating func reveal(after request: KeyRequest, now: Date) throws(KeyHandoffError) -> KeyRequestUpdate? {
        if request.status == .rejected { throw .rejected }
        if let responderPublicKey {
            guard request.responderPublicKey == responderPublicKey else { throw .keyChanged }
            return request.status == .answered ? .reveal(requesterPublicKey: pair.publicKey) : nil
        }
        // Никто не ответил вовремя (или ответили, но срок вышел): ключ не раскрываем, просим заново.
        if request.isExpired(at: now) { throw .expired }
        guard request.status == .answered, let responderKey = request.responderPublicKey else { return nil }
        guard responderKey.count == KeyHandoff.publicKeySize else { throw .invalidKey }
        responderPublicKey = responderKey
        return .reveal(requesterPublicKey: pair.publicKey)
    }

    /// Человек сверил код и подтвердил. Без этого ключ из строки не берём.
    public mutating func confirm() {
        confirmed = true
    }

    /// Ключ пары, если второй телефон его отдал, а этот подтвердил тот же код. `nil` — ещё ждём.
    public func receive(_ request: KeyRequest, now: Date) throws(KeyHandoffError) -> CoupleKey? {
        if request.status == .rejected { throw .rejected }
        guard let responderPublicKey else { return nil }
        // Ключ второго телефона в строке должен остаться тем, по которому считали код.
        guard request.responderPublicKey == responderPublicKey else { throw .keyChanged }
        guard request.status == .delivered, let wrapped = request.wrappedKey else {
            if request.isExpired(at: now) { throw .expired }
            return nil
        }
        guard confirmed else { return nil }
        do {
            return try KeyExchange.unwrap(wrapped, with: pair, from: responderPublicKey)
        } catch {
            throw .invalidKey
        }
    }
}

/// Телефон с ключом пары: отдаёт его партнёру (или новому телефону, #86).
public struct KeyHandoffResponder: Sendable {
    private enum Phase: Sendable {
        case idle
        case answered(commitment: Data)
        case verified(requesterPublicKey: Data)
        case rejected
    }

    private let key: CoupleKey
    private let pair: KeyExchangePair
    private var phase = Phase.idle

    public init(key: CoupleKey, pair: KeyExchangePair = KeyExchangePair()) {
        self.key = key
        self.pair = pair
    }

    /// Свой открытый ключ: им отвечаем, в том числе повторно, если ответ не дошёл до сервера.
    public var publicKey: Data { pair.publicKey }

    /// В строке наш ответ. Нет — на запрос ответил другой телефон (или ответ ещё не дошёл до сервера).
    public func owns(_ request: KeyRequest) -> Bool {
        request.responderPublicKey == pair.publicKey
    }

    /// Ответить своим открытым ключом и запомнить обязательство.
    public mutating func answer(_ request: KeyRequest, now: Date) throws(KeyHandoffError) -> KeyRequestUpdate {
        guard request.status == .waiting else { throw .unexpectedStatus }
        if request.isExpired(at: now) { throw .expired }
        guard request.requesterKeyCommitment.count == 32 else { throw .invalidKey }
        phase = .answered(commitment: request.requesterKeyCommitment)
        return .answer(responderPublicKey: pair.publicKey)
    }

    /// Проверить раскрытый ключ по обязательству и посчитать код. `nil` — ключ ещё не раскрыт, ждём.
    public mutating func verify(_ request: KeyRequest, now: Date) throws(KeyHandoffError) -> String? {
        if request.status == .rejected { throw .rejected }
        switch phase {
        case .answered(let commitment):
            // Наш ответ ещё не дошёл до сервера: ждём (приложение отправит `answer` ещё раз).
            if request.status == .waiting, request.responderPublicKey == nil {
                if request.isExpired(at: now) { throw .expired }
                return nil
            }
            // Ответ в строке не наш: другой телефон с ключом ответил позже и перезаписал (или сервер подменил).
            // Кода мы ещё не показывали, поэтому это не атака на сверку: отходим, ключ не отдаём.
            guard owns(request) else {
                phase = .rejected
                throw .answeredElsewhere
            }
            guard request.status == .revealed, let revealed = request.requesterPublicKey else {
                if request.isExpired(at: now) { throw .expired }
                return nil
            }
            guard revealed.count == KeyHandoff.publicKeySize,
                  KeyHandoff.commitment(for: revealed) == commitment
            else {
                phase = .rejected
                throw .commitmentMismatch
            }
            phase = .verified(requesterPublicKey: revealed)
            return KeyExchange.verificationCode(pair.publicKey, revealed)
        case .verified(let revealed):
            // Код уже показан: чужой ключ в строке теперь — подмена, а не гонка двух телефонов.
            guard owns(request) else {
                phase = .rejected
                throw .keyChanged
            }
            return KeyExchange.verificationCode(pair.publicKey, revealed)
        case .idle:
            throw .unexpectedStatus
        case .rejected:
            throw .rejected
        }
    }

    /// Человек подтвердил код: завёрнутый ключ для проверенного ключа второго телефона.
    public func deliver() throws(KeyHandoffError) -> KeyRequestUpdate {
        switch phase {
        case .verified(let requesterPublicKey):
            do {
                return .deliver(wrappedKey: try KeyExchange.wrap(key, from: pair, to: requesterPublicKey))
            } catch {
                throw .invalidKey
            }
        case .rejected:
            throw .rejected
        case .idle, .answered:
            throw .unexpectedStatus
        }
    }

    /// Отказ: коды не совпали или человек передумал. После этого ключ не отдаётся.
    public mutating func reject() -> KeyRequestUpdate {
        phase = .rejected
        return .reject
    }
}
