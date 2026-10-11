import Foundation

/// Как согласие лежит в настройках аккаунта Appwrite: `consentVersion` и `consentDate` (ISO 8601).
enum ConsentPrefs {
    static let versionKey = "consentVersion"
    static let dateKey = "consentDate"

    /// Принятая версия. Сервер может вернуть число и как 1, и как 1.0.
    static func version(in prefs: [String: Any]) -> Int? {
        switch prefs[versionKey] {
        case let value as Int: value
        case let value as Double: Int(value)
        default: nil
        }
    }

    /// Настройки целиком: сервер заменяет их полностью, поэтому остальные ключи переносим.
    static func merged(_ prefs: [String: Any], version: Int, date: Date) -> [String: Any] {
        var result = prefs
        result[versionKey] = version
        result[dateKey] = date.formatted(.iso8601)
        return result
    }
}
