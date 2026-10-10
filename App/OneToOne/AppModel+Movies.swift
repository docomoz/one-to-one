import Core
import Foundation
import MovieAPI

/// Действия фильмов: списки «хочу посмотреть».
extension AppModel {
    /// Добавляет фильм в мой список. Пока непонятно, кто «я» (знакомство не пройдено), ничего не делает.
    func addToWatchlist(_ movie: Movie) {
        guard let me = data.meID else { return }
        update { $0.addToWatchlist(movie, ownerID: me, addedAt: .now) }
    }

    func removeFromWatchlist(movieID: Int) {
        guard let me = data.meID else { return }
        update { $0.removeFromWatchlist(movieID: movieID, ownerID: me) }
    }

    func isInMyWatchlist(movieID: Int) -> Bool {
        data.watchlist.contains { $0.ownerID == data.meID && $0.movie.id == movieID }
    }
}

/// Вечер с фильмом: подбор, свайпы, совпадения, «Смотрим».
extension AppModel {
    /// Пока непонятно, кто «я» (знакомство не пройдено), подбор не начинается: свайпать в нём всё равно нельзя.
    func startPick(mood: Mood) -> PickSession? {
        guard let me = data.meID else { return nil }
        var session: PickSession?
        update { session = $0.startPick(mood: mood, startedBy: me, at: .now) }
        return session
    }

    /// Возвращает `true`, если этот свайп дал совпадение. Без «я» ничего не делает.
    @discardableResult
    func swipe(_ action: SwipeAction, movie: Movie, in session: PickSession) -> Bool {
        guard let me = data.meID else { return false }
        var matched = false
        update { matched = $0.swipe(action, movie: movie, in: session, by: me, at: .now) }
        return matched
    }

    func matches(in session: PickSession) -> [Int] {
        data.matches(in: session)
    }

    func likedByAnyone(in session: PickSession) -> [Int] {
        data.likedByAnyone(in: session)
    }

    func markWatched(movieID: Int) {
        update { $0.markWatched(movieID: movieID) }
    }

    /// Колода для меня: оба списка плюс рекомендации каталога. Нет сети — только списки.
    /// Каждый вызов — до 6 запросов к Кинопоиску (200 в день бесплатно), поэтому зови один раз на подбор.
    func deck(for session: PickSession, catalog: some MovieCatalog) async -> [Movie] {
        let recommendations = await DeckLoader.recommendations(seeds: data.recommendationSeeds(),
                                                               mood: session.mood, catalog: catalog)
        return data.deck(for: session, recommendations: recommendations, me: data.meID ?? UUID())
    }
}
