import Foundation

/// Списки «хочу посмотреть»: у каждого свой, видны оба.
extension AppData {
    /// Второй человек в паре.
    public var partnerID: UUID? {
        guard let couple, let meID else { return nil }
        if meID == couple.man.id { return couple.woman.id }
        if meID == couple.woman.id { return couple.man.id }
        return nil
    }

    /// Свежие сверху.
    public func watchlist(of ownerID: UUID) -> [WatchlistItem] {
        watchlist.filter { $0.ownerID == ownerID }.sorted { $0.addedAt > $1.addedAt }
    }

    /// Фильм уже в списке этого человека — ничего не меняет. Фильм кладём и в кэш,
    /// чтобы не просить его у Кинопоиска ещё раз (200 запросов в день).
    public mutating func addToWatchlist(_ movie: Movie, ownerID: UUID, addedAt: Date, fromLater: Bool = false) {
        movieCache[movie.id] = movie
        guard !watchlist.contains(where: { $0.ownerID == ownerID && $0.movie.id == movie.id }) else { return }
        watchlist.append(WatchlistItem(movie: movie, ownerID: ownerID, addedAt: addedAt, fromLater: fromLater))
    }

    public mutating func removeFromWatchlist(movieID: Int, ownerID: UUID) {
        watchlist.removeAll { $0.ownerID == ownerID && $0.movie.id == movieID }
    }
}
