import Foundation

/// Документ на сервере: непрозрачный id и конверт. Сервер не знает ни вида, ни даты, ни удалена ли запись.
public struct EncryptedRecord: Equatable, Sendable {
    /// `RecordIDHasher.documentID(for:key:)` от id записи.
    public let documentID: String
    /// Время на сервере: только подсказка для сортировки, слиянию оно не указ.
    public let updatedAt: Date
    /// Всегда есть, и у удалённых тоже: внутри зашифрован весь `SyncRecord` (id, updatedAt, payload или null) в JSON.
    public let envelope: Data

    public init(documentID: String, updatedAt: Date, envelope: Data) {
        self.documentID = documentID
        self.updatedAt = updatedAt
        self.envelope = envelope
    }
}
