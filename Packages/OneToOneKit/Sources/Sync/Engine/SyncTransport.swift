import Foundation

/// Связь с сервером пары. В приложении — Appwrite, в тестах — `FakeTransport`.
public protocol SyncTransport: Sendable {
    /// Создаёт или заменяет документы с этими `documentID`. Время на сервере ставит сам сервер,
    /// `updatedAt` отправляемых записей не используется.
    func push(_ records: [EncryptedRecord], coupleID: String) async throws
    /// Всё, что изменилось на сервере после курсора, по порядку (`$updatedAt`, затем `$id`), и новый курсор.
    /// Пустой список — новых документов нет. Отдавать можно порциями: движок спрашивает, пока список не пуст.
    /// Уже отданные документы можно отдать снова (например, с запасом по времени, чтобы не пропустить запись,
    /// которая сохранилась на сервере позже соседней): слияние от повтора не меняется.
    func pull(coupleID: String, after cursor: String?) async throws -> (records: [EncryptedRecord], cursor: String?)
}
