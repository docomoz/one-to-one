import Foundation
import Observation

/// Какой экран показать при запуске: вход → согласие → знакомство → вкладки.
enum RootScreen: Equatable {
    case checking, signIn, consent, onboarding, tabs
}

/// Вход по почте и согласие: решает, куда пустить человека, и держит шаги входа и ошибки.
/// Экраны только показывают состояние и зовут методы.
@Observable @MainActor
final class AuthFlow {
    /// Код отправлен: на какую почту, с каким userId подтверждать и когда отправили.
    struct PendingCode: Equatable {
        let email: String
        let userID: String
        let sentAt: Date
    }

    private enum Status { case checking, signedOut, needsConsent, signedIn }

    private(set) var pending: PendingCode?
    private(set) var errorMessage: String?
    private(set) var isWorking = false
    private var status = Status.checking

    /// Сколько ждать перед повторной отправкой кода: письма не мгновенные, а сервер ограничивает частоту.
    static let resendInterval: TimeInterval = 60

    @ObservationIgnored private let auth: any AuthService
    @ObservationIgnored private let consent: any ConsentService
    @ObservationIgnored private let now: () -> Date

    init(auth: any AuthService, consent: any ConsentService, now: @escaping () -> Date = Date.init) {
        self.auth = auth
        self.consent = consent
        self.now = now
    }

    func screen(isPaired: Bool) -> RootScreen {
        switch status {
        case .checking: .checking
        case .signedOut: .signIn
        case .needsConsent: .consent
        case .signedIn: isPaired ? .tabs : .onboarding
        }
    }

    /// При запуске: есть ли сессия и согласие.
    func start() async {
        if await auth.currentUserID() == nil {
            status = .signedOut
        } else {
            await checkConsent()
        }
    }

    func sendCode(to email: String) async {
        let email = Self.normalized(email)
        await perform {
            let userID = try await auth.sendCode(to: email)
            pending = PendingCode(email: email, userID: userID, sentAt: now())
        }
    }

    func resendCode() async {
        guard let pending, resendDelay(at: now()) == 0 else { return }
        await sendCode(to: pending.email)
    }

    /// Секунд до того, как можно отправить код ещё раз; 0 — уже можно.
    func resendDelay(at date: Date) -> Int {
        guard let pending else { return 0 }
        let left = Self.resendInterval - date.timeIntervalSince(pending.sentAt)
        return max(0, Int(left.rounded(.up)))
    }

    func confirm(code: String) async {
        guard let pending else { return }
        await perform {
            try await auth.confirm(userId: pending.userID, code: code)
            await checkConsent()
            self.pending = nil
        }
    }

    /// «Изменить почту» на экране кода.
    func changeEmail() {
        pending = nil
        errorMessage = nil
    }

    /// Две отдельные галочки (docs/legal/consent.md): обычные данные и особая категория.
    /// Дальше пускаем, только когда отмечены обе.
    func giveConsent(personalData: Bool, specialCategory: Bool) async {
        guard Self.canGiveConsent(personalData: personalData, specialCategory: specialCategory) else { return }
        await perform {
            try await consent.saveConsent(version: BackendConfig.consentVersion, date: now())
            status = .signedIn
        }
    }

    func signOut() async {
        await perform {
            try await auth.signOut()
            status = .signedOut
        }
    }

    /// Ошибку убираем, как только человек начал исправлять ввод.
    func clearError() {
        errorMessage = nil
    }

    private func checkConsent() async {
        do {
            let version = try await consent.consentVersion() ?? 0
            status = version >= BackendConfig.consentVersion ? .signedIn : .needsConsent
        } catch AuthError.signedOut {
            status = .signedOut
        } catch {
            // Не смогли узнать (нет сети и согласие не запомнено) — спросим ещё раз, повторное согласие
            // безвредно. Сохранится оно, когда появится сеть.
            errorMessage = (error as? AuthError ?? .network).message
            status = .needsConsent
        }
    }

    /// Запрос к серверу с крутилкой: ошибку превращаем в текст для экрана.
    private func perform(_ action: () async throws -> Void) async {
        guard !isWorking else { return }
        isWorking = true
        errorMessage = nil
        do {
            try await action()
        } catch {
            let error = error as? AuthError ?? .network
            errorMessage = error.message
            // Сессия пропала на сервере: дальше без входа ничего не получится.
            if error == .signedOut {
                pending = nil
                status = .signedOut
            }
        }
        isWorking = false
    }

    // MARK: - Ввод

    nonisolated static func canGiveConsent(personalData: Bool, specialCategory: Bool) -> Bool {
        personalData && specialCategory
    }

    nonisolated static func normalized(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// Похоже ли на почту: что-то@что-то.домен, без пробелов. Точную проверку делает сервер.
    nonisolated static func isPlausibleEmail(_ email: String) -> Bool {
        let email = normalized(email)
        guard !email.contains(where: \.isWhitespace) else { return false }
        let parts = email.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty else { return false }
        let domain = parts[1].split(separator: ".", omittingEmptySubsequences: false)
        return domain.count >= 2 && domain.allSatisfy { !$0.isEmpty }
    }

    /// Только цифры и не больше шести: код вставляют из письма вместе с пробелами.
    nonisolated static func cleanCode(_ text: String) -> String {
        String(text.filter(\.isASCII).filter(\.isNumber).prefix(6))
    }
}
