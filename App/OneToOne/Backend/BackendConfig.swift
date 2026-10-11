import Foundation

/// Где сервер и что показываем при входе. Адрес и id проекта приходят из `Config/App.xcconfig`
/// через Info.plist: так при переезде на свой домен меняется одна строка.
enum BackendConfig {
    static var endpoint: String { infoValue("AppwriteEndpoint") }
    static var projectID: String { infoValue("AppwriteProjectID") }

    /// Политика конфиденциальности и полный текст согласия (docs/legal/). Пока заглушки на нашем сервере:
    /// настоящие страницы появятся в #88.
    static let privacyPolicyURL = URL(string: "https://api.194-87-44-100.sslip.io/privacy")!
    static let consentURL = URL(string: "https://api.194-87-44-100.sslip.io/consent")!

    /// Версия текста согласия. Поменяли текст по существу — увеличь, и все согласятся заново.
    static let consentVersion = 1

    private static func infoValue(_ key: String) -> String {
        Bundle.main.object(forInfoDictionaryKey: key) as? String ?? ""
    }
}
