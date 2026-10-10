import Core

/// Дозаполняет рейтинги фильма. Никогда не бросает ошибку: чего не нашли, то остаётся `nil`.
public protocol RatingsProvider: Sendable {
    func ratings(for movie: Movie) async -> Ratings
}
