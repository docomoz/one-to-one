import Foundation

/// Фильм в личном списке «хочу посмотреть».
public struct WatchlistItem: Codable, Equatable, Sendable {
    public let movie: Movie
    public let ownerID: UUID
    public let addedAt: Date
    /// Попал в список из свайпа «Потом».
    public let fromLater: Bool

    public init(movie: Movie, ownerID: UUID, addedAt: Date, fromLater: Bool) {
        self.movie = movie
        self.ownerID = ownerID
        self.addedAt = addedAt
        self.fromLater = fromLater
    }
}
