import Foundation

/// Один подбор фильма на вечер.
public struct PickSession: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let mood: Mood
    public let startedBy: UUID
    public let startedAt: Date

    public init(id: UUID = UUID(), mood: Mood, startedBy: UUID, startedAt: Date) {
        self.id = id
        self.mood = mood
        self.startedBy = startedBy
        self.startedAt = startedAt
    }
}
