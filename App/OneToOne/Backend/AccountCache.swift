import Foundation

/// Кто вошёл и какое согласие дал, запомненные на телефоне. Нужны без сети:
/// приложение должно открываться и в самолёте, а не выкидывать на экран входа.
struct AccountCache: @unchecked Sendable {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var userID: String? {
        get { defaults.string(forKey: Keys.userID) }
        nonmutating set { defaults.set(newValue, forKey: Keys.userID) }
    }

    func consentVersion(for userID: String) -> Int? {
        consents[userID]
    }

    func setConsentVersion(_ version: Int, for userID: String) {
        var all = consents
        all[userID] = version
        defaults.set(all, forKey: Keys.consents)
    }

    /// После выхода из аккаунта.
    func clear() {
        defaults.removeObject(forKey: Keys.userID)
        defaults.removeObject(forKey: Keys.consents)
    }

    private var consents: [String: Int] {
        defaults.dictionary(forKey: Keys.consents) as? [String: Int] ?? [:]
    }

    private enum Keys {
        static let userID = "account.userID"
        static let consents = "account.consentVersions"
    }
}
