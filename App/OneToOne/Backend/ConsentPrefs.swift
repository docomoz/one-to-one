import Foundation

/// Как согласие лежит в настройках аккаунта Appwrite: версия текста, дата (ISO 8601) и обе галочки
/// экрана согласия — обычные данные и особая категория (docs/legal/consent.md).
enum ConsentPrefs {
    static let versionKey = "consentVersion"
    static let dateKey = "consentDate"
    static let personalDataKey = "consentPersonalData"
    static let specialCategoryKey = "consentSpecialCategory"

    /// Принятая версия; `nil`, если нет версии или хоть одной из двух галочек.
    /// Сервер может вернуть число и как 1, и как 1.0.
    static func version(in prefs: [String: Any]) -> Int? {
        guard prefs[personalDataKey] as? Bool == true, prefs[specialCategoryKey] as? Bool == true else { return nil }
        switch prefs[versionKey] {
        case let value as Int: return value
        case let value as Double: return Int(value)
        default: return nil
        }
    }

    /// Настройки целиком: сервер заменяет их полностью, поэтому остальные ключи переносим.
    /// Сохраняем, только когда отмечены обе галочки, поэтому обе записываем как `true`.
    static func merged(_ prefs: [String: Any], version: Int, date: Date) -> [String: Any] {
        var result = prefs
        result[versionKey] = version
        result[dateKey] = date.formatted(.iso8601)
        result[personalDataKey] = true
        result[specialCategoryKey] = true
        return result
    }
}
