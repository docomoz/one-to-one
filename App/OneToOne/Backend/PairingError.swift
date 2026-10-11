import Sync

/// Почему не получилось создать пару, пригласить, войти или передать ключ, словами для человека.
enum PairingError: Error, Equatable {
    case inviteNotFound, inviteExpired, coupleFull, alreadyPaired, notMember
    /// Коды не совпали или кто-то нажал «Не совпадает».
    case rejected
    /// Ключ второго телефона подменили: раскрытый не совпал с обещанным или поменялся после кода.
    case keyMismatch
    /// Время на сверку кода вышло.
    case expired
    case signedOut, network, server

    /// Ответ функции сервера с ошибкой: `{"error": "<код>"}` и код ответа.
    init(functionError: String?, status: Int) {
        switch (functionError, status) {
        case ("invite_not_found", _): self = .inviteNotFound
        case ("invite_expired", _): self = .inviteExpired
        case ("couple_full", _): self = .coupleFull
        case ("already_paired", _): self = .alreadyPaired
        case ("not_member", _): self = .notMember
        case ("unauthorized", _), (_, 401): self = .signedOut
        default: self = .server
        }
    }

    /// Остановка передачи ключа → что показать.
    init(_ error: KeyHandoffError) {
        switch error {
        case .expired: self = .expired
        case .rejected: self = .rejected
        // На запрос ответил другой телефон: экран это не показывает (`PairingFlow` отходит молча).
        case .commitmentMismatch, .keyChanged, .invalidKey, .answeredElsewhere: self = .keyMismatch
        case .unexpectedStatus: self = .server
        }
    }

    var message: String {
        switch self {
        case .inviteNotFound: "Приглашение уже использовано или в коде ошибка. Попроси партнёра прислать новый код."
        case .inviteExpired: "Срок приглашения истёк. Попроси партнёра прислать новый код."
        case .coupleFull: "В паре уже двое."
        case .alreadyPaired: "Это твой собственный код, или ты уже в паре с кем-то другим."
        case .notMember: "Этот аккаунт не в паре. Войди с той почтой, с которой создавали пару."
        case .rejected: "Коды не совпали или партнёр отказался. Начните заново."
        case .keyMismatch: "Ключи не сошлись: похоже, кто-то вмешался в соединение. Ключ не передан. Начните заново."
        case .expired: "Время на сверку кода вышло. Начните заново."
        case .signedOut: "Ты вышел(а) из аккаунта. Войди по почте ещё раз."
        case .network: "Нет связи с сервером. Проверь интернет и попробуй ещё раз."
        case .server: "Сервер не смог выполнить запрос. Попробуй ещё раз чуть позже."
        }
    }
}
