import Foundation

/// Списки «хочу посмотреть»: у каждого свой, видны оба.
extension AppData {
    /// Второй человек в паре.
    public var partner: Person? {
        guard let couple, let meID else { return nil }
        if meID == couple.man.id { return couple.woman }
        if meID == couple.woman.id { return couple.man }
        return nil
    }

    public var partnerID: UUID? { partner?.id }

    /// Свежие сверху.
    public func watchlist(of ownerID: UUID) -> [WatchlistItem] {
        watchlist.filter { $0.ownerID == ownerID }.sorted { $0.addedAt > $1.addedAt }
    }

    /// Фильм уже в списке этого человека — ничего не меняет. Новый фильм кладём и в кэш,
    /// чтобы не просить его у Кинопоиска ещё раз (200 запросов в день); уже лежащий не трогаем,
    /// в нём могут быть дозаполненные рейтинги.
    public mutating func addToWatchlist(_ movie: Movie, ownerID: UUID, addedAt: Date, fromLater: Bool = false) {
        if movieCache[movie.id] == nil { movieCache[movie.id] = movie }
        guard !watchlist.contains(where: { $0.ownerID == ownerID && $0.movie.id == movie.id }) else { return }
        watchlist.append(WatchlistItem(movie: movie, ownerID: ownerID, addedAt: addedAt, fromLater: fromLater))
    }

    public mutating func removeFromWatchlist(movieID: Int, ownerID: UUID) {
        watchlist.removeAll { $0.ownerID == ownerID && $0.movie.id == movieID }
    }
}
