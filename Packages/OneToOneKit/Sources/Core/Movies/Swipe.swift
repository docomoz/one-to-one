import Foundation

public enum SwipeAction: String, Codable, Sendable {
    case no, yes, later
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
