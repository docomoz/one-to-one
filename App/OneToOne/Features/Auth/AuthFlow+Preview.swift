#if DEBUG
import Foundation

/// Вход без сервера для превью и проверки экранов: письма не уходят, подходит любой код, кроме 000000.
struct PreviewAuthService: AuthService, ConsentService {
    /// Уже вошли (сразу экран согласия) или нет (экран почты).
    var signedIn = false

    func sendCode(to email: String) async throws -> String { "preview" }

    func confirm(userId: String, code: String) async throws {
        if code == "000000" { throw AuthError.wrongCode }
    }

    func currentUserID() async -> String? { signedIn ? "preview" : nil }
    func signOut() async throws {}
    func consentVersion() async throws -> Int? { nil }
    func saveConsent(version: Int, date: Date) async throws {}
}

extension AuthFlow {
    static func preview(signedIn: Bool = false) -> AuthFlow {
        let service = PreviewAuthService(signedIn: signedIn)
        return AuthFlow(auth: service, consent: service)
    }

    /// Запуск с `-previewAuth email|code|consent` показывает экраны входа без сервера
    /// (для скриншотов и проверки на симуляторе). Без аргумента — `nil`, вход настоящий.
    static func fromLaunchArguments() -> AuthFlow? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-previewAuth"), index + 1 < arguments.count else { return nil }
        let step = arguments[index + 1]
        let flow = preview(signedIn: step == "consent")
        if step == "code" {
            Task { await flow.sendCode(to: "dasha@example.com") }
        }
        return flow
    }
}
#endif
