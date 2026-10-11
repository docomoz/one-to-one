import Foundation

/// Кто вошёл и какое согласие дал, запомненные на телефоне. Нужны без сети:
/// приложение должно открываться и в самолёте, а не выкидывать на экран входа.
struct AccountCache: @unchecked Sendable {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Другой человек — согласие прежнего к нему не относится, забываем его.
    var userID: String? {
        get { defaults.string(forKey: Keys.userID) }
        nonmutating set {
            if newValue != userID { defaults.removeObject(forKey: Keys.consentVersion) }
            defaults.set(newValue, forKey: Keys.userID)
        }
    }

    /// Согласие того, кто сейчас вошёл. `nil` — не давал или не знаем.
    var consentVersion: Int? {
        get { defaults.object(forKey: Keys.consentVersion) as? Int }
        nonmutating set { defaults.set(newValue, forKey: Keys.consentVersion) }
    }

    /// После выхода из аккаунта.
    func clear() {
        defaults.removeObject(forKey: Keys.userID)
        defaults.removeObject(forKey: Keys.consentVersion)
    }

    private enum Keys {
        static let userID = "account.userID"
        static let consentVersion = "account.consentVersion"
    }
}
