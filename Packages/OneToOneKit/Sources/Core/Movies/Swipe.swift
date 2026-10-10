import Foundation

public enum SwipeAction: String, Codable, Sendable {
    case no, yes, later
}

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

/// Решение одного человека по одному фильму в подборе.
public struct Swipe: Codable, Equatable, Sendable {
    public let sessionID: UUID
    public let personID: UUID
    public let movieID: Int
    public let action: SwipeAction
    public let date: Date

    public init(sessionID: UUID, personID: UUID, movieID: Int, action: SwipeAction, date: Date) {
        self.sessionID = sessionID
        self.personID = personID
        self.movieID = movieID
        self.action = action
        self.date = date
    }
}
