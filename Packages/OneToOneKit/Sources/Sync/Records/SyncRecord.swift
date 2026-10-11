import Foundation

/// Одна запись синхронизации. `payload == nil` — запись удалена (надгробие), чтобы удаление дошло до партнёра.
public struct SyncRecord: Codable, Equatable, Sendable {
    /// "<вид>:<ключ>", например "period:2026-10-11". Виден только на устройствах, сервер видит непрозрачный id.
    public let id: String
    public let updatedAt: Date
    /// JSON значения из `SyncRecordMapper.payloads(from:)`.
    public let payload: Data?

    public init(id: String, updatedAt: Date, payload: Data?) {
        self.id = id
        self.updatedAt = updatedAt
        self.payload = payload
    }
}
