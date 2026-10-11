import Foundation

/// Что телефон помнит о своей паре на сервере, кроме ключа (он в Keychain). Не секрет: id пары видит и сервер.
struct PairingDefaults: @unchecked Sendable {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Пара этого телефона. Есть ещё до того, как сервер её создал: id придумывает телефон, чтобы повтор
    /// после потерянного ответа не создал вторую пару.
    var coupleID: String? {
        get { defaults.string(forKey: Keys.coupleID) }
        nonmutating set { defaults.set(newValue, forKey: Keys.coupleID) }
    }

    /// Сервер подтвердил, что пара `coupleID` есть и мы в ней.
    var isCoupleOnServer: Bool {
        get { defaults.bool(forKey: Keys.isCoupleOnServer) }
        nonmutating set { defaults.set(newValue, forKey: Keys.isCoupleOnServer) }
    }

    /// Вошли в пару по коду, но ключ ещё не получили.
    var joiningCoupleID: String? {
        get { defaults.string(forKey: Keys.joiningCoupleID) }
        nonmutating set { defaults.set(newValue, forKey: Keys.joiningCoupleID) }
    }

    /// Свои пары без партнёра, из которых нужно выйти после входа в пару партнёра (повторяем, пока не выйдет).
    var couplesToLeave: [String] {
        get { defaults.stringArray(forKey: Keys.couplesToLeave) ?? [] }
        nonmutating set { defaults.set(newValue, forKey: Keys.couplesToLeave) }
    }

    /// Партнёр уже в паре: приглашать больше некого.
    var partnerJoined: Bool {
        get { defaults.bool(forKey: Keys.partnerJoined) }
        nonmutating set { defaults.set(newValue, forKey: Keys.partnerJoined) }
    }

    /// Чей аккаунт хозяин данных на этом телефоне. Вошёл другой — данные прежнего стираются до показа экранов.
    var ownerUserID: String? {
        get { defaults.string(forKey: Keys.ownerUserID) }
        nonmutating set { defaults.set(newValue, forKey: Keys.ownerUserID) }
    }

    /// Для хозяина уже проверили на сервере, есть ли у него пара (после переустановки id пары на телефоне нет).
    var coupleLookupDone: Bool {
        get { defaults.bool(forKey: Keys.coupleLookupDone) }
        nonmutating set { defaults.set(newValue, forKey: Keys.coupleLookupDone) }
    }

    /// Забыть всё о паре и аккаунте: после выхода из аккаунта, удаления аккаунта или входа другого человека.
    func removeAll() {
        for key in Keys.all { defaults.removeObject(forKey: key) }
    }

    private enum Keys {
        static let coupleID = "pairing.coupleID"
        static let isCoupleOnServer = "pairing.isCoupleOnServer"
        static let joiningCoupleID = "pairing.joiningCoupleID"
        static let couplesToLeave = "pairing.couplesToLeave"
        static let partnerJoined = "pairing.partnerJoined"
        static let ownerUserID = "pairing.ownerUserID"
        static let coupleLookupDone = "pairing.coupleLookupDone"
        static let all = [coupleID, isCoupleOnServer, joiningCoupleID, couplesToLeave, partnerJoined,
                          ownerUserID, coupleLookupDone]
    }
}
