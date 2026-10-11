import Foundation

/// Всё, что движок помнит между запусками. Приложение сохраняет его в `SyncState.json`.
public struct SyncState: Codable, Equatable, Sendable {
    /// Последнее слитое состояние по id записи, вместе с правками этого телефона и записями незнакомых видов.
    /// Из него собираются данные для экранов.
    public var known: [String: SyncRecord]
    /// Ещё не отправлено на сервер. Каждая запись отсюда есть и в `known`.
    public var outbox: [String: SyncRecord]
    /// Докуда уже забрали документы с сервера; `nil` — с начала.
    public var cursor: String?

    public init(known: [String: SyncRecord] = [:], outbox: [String: SyncRecord] = [:], cursor: String? = nil) {
        self.known = known
        self.outbox = outbox
        self.cursor = cursor
    }
}
