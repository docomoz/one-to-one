@preconcurrency import Appwrite
import Foundation
import OSLog

/// Вход по почте через Appwrite (Email OTP): письмо с кодом → сессия. Сессию SDK хранит сам
/// (куки в UserDefaults), поэтому после перезапуска приложение остаётся в аккаунте.
/// Согласие лежит в настройках аккаунта (`account.updatePrefs`).
final class AppwriteAuthService: AuthService, ConsentService, @unchecked Sendable {
    /// Один на всё приложение, как каталог фильмов.
    static let shared = AppwriteAuthService(endpoint: BackendConfig.endpoint, projectID: BackendConfig.projectID)

    // SDK не помечен Sendable, но его клиент безопасно звать из разных задач.
    private let account: Account
    private let cache: AccountCache

    init(endpoint: String, projectID: String, cache: AccountCache = AccountCache()) {
        let client = Client()
            .setEndpoint(endpoint)
            .setProject(projectID)
        account = Account(client)
        self.cache = cache
    }

    func sendCode(to email: String) async throws -> String {
        do {
            // Новый id: если почта уже есть, сервер вернёт id существующего аккаунта.
            return try await account.createEmailToken(userId: ID.unique(), email: email).userId
        } catch {
            throw Self.authError(error, step: .sendCode)
        }
    }

    func confirm(userId: String, code: String) async throws {
        do {
            let session = try await account.createSession(userId: userId, secret: code)
            cache.userID = session.userId
        } catch {
            throw Self.authError(error, step: .confirm)
        }
    }

    func currentUserID() async -> String? {
        do {
            let user = try await account.get()
            cache.userID = user.id
            return user.id
        } catch let error as AppwriteError where error.code == 401 {
            // Сессии нет или её удалили на сервере.
            Self.log.info("Сессии нет: \(error.message)")
            cache.clear()
            return nil
        } catch {
            // Нет сети или сервер лёг: остаёмся в последнем аккаунте, приложение работает без сети.
            Self.log.error("Сервер не ответил, берём запомненный аккаунт: \(error)")
            return cache.userID
        }
    }

    func signOut() async throws {
        do {
            _ = try await account.deleteSession(sessionId: "current")
        } catch let error as AppwriteError where error.code == 401 {
            // Сессии на сервере уже нет: выходим и на телефоне.
        } catch {
            throw Self.authError(error, step: .other)
        }
        cache.clear()
    }

    func consentVersion() async throws -> Int? {
        do {
            let version = ConsentPrefs.version(in: try await prefs())
            if let userID = cache.userID, let version {
                cache.setConsentVersion(version, for: userID)
            }
            return version
        } catch let error as AppwriteError where error.code == 401 {
            throw Self.authError(error, step: .other)
        } catch {
            // Без сети верим запомненному согласию, иначе человек не откроет приложение в самолёте.
            if let userID = cache.userID, let cached = cache.consentVersion(for: userID) {
                return cached
            }
            throw Self.authError(error, step: .other)
        }
    }

    func saveConsent(version: Int, date: Date) async throws {
        do {
            let prefs = ConsentPrefs.merged(try await prefs(), version: version, date: date)
            _ = try await account.updatePrefs(prefs: prefs)
        } catch {
            throw Self.authError(error, step: .other)
        }
        if let userID = cache.userID {
            cache.setConsentVersion(version, for: userID)
        }
    }

    private func prefs() async throws -> [String: Any] {
        try await account.getPrefs().data.mapValues(\.value)
    }

    /// Ответ сервера с ошибкой → понятная причина; всё остальное (нет ответа) — нет сети.
    private static func authError(_ error: Error, step: AuthError.Step) -> AuthError {
        guard let error = error as? AppwriteError else {
            log.error("Нет ответа сервера: \(error)")
            return .network
        }
        log.error("Сервер вернул ошибку \(error.code ?? 0) \(error.type ?? ""): \(error.message)")
        return AuthError(status: error.code, type: error.type, step: step)
    }

    private static let log = Logger(subsystem: "com.docomoz.onetoone", category: "Auth")
}
