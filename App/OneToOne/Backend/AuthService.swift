import Foundation

/// Вход по почте: код из письма → сессия на сервере. Ошибки — `AuthError`.
protocol AuthService: Sendable {
    /// Отправляет письмо с 6-значным кодом. Возвращает userId, с которым потом подтверждаем код.
    func sendCode(to email: String) async throws -> String
    func confirm(userId: String, code: String) async throws
    /// Кто вошёл на этом телефоне. `nil` — никто, нужен вход.
    func currentUserID() async -> String?
    func signOut() async throws
}

/// Согласие на обработку данных хранится в аккаунте на сервере, а не в `AppData`:
/// это юридический факт про человека, а не запись пары.
protocol ConsentService: Sendable {
    /// Версия текста согласия, которую человек принял. `nil` — ещё не соглашался.
    func consentVersion() async throws -> Int?
    func saveConsent(version: Int, date: Date) async throws
}
