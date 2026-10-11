import Foundation
@testable import OneToOne

/// Сервер входа без сети: помнит, кто вошёл и дал ли согласие, и умеет падать нужной ошибкой.
@MainActor
final class FakeAuthService: AuthService, ConsentService {
    var signedInUserID: String?
    var consent: Int?
    /// Какой код примет `confirm`.
    var validCode = "123456"
    var sendError: AuthError?
    var consentError: AuthError?
    var signOutError: AuthError?
    private(set) var sentTo: [String] = []
    private(set) var savedConsent: (version: Int, date: Date)?

    init(signedInUserID: String? = nil, consent: Int? = nil) {
        self.signedInUserID = signedInUserID
        self.consent = consent
    }

    func sendCode(to email: String) async throws -> String {
        if let sendError { throw sendError }
        sentTo.append(email)
        return "user-\(email)"
    }

    func confirm(userId: String, code: String) async throws {
        guard code == validCode else { throw AuthError.wrongCode }
        signedInUserID = userId
    }

    func currentUserID() async -> String? { signedInUserID }

    func signOut() async throws {
        if let signOutError { throw signOutError }
        signedInUserID = nil
    }

    func consentVersion() async throws -> Int? {
        if let consentError { throw consentError }
        return consent
    }

    func saveConsent(version: Int, date: Date) async throws {
        if let consentError { throw consentError }
        consent = version
        savedConsent = (version, date)
    }
}
