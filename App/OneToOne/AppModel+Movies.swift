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

    /// Подбор, который сейчас идёт. `nil`, если его нет или фильм из него уже смотрят.
    var currentPick: PickSession? {
        data.currentPick
    }

    func matches(in session: PickSession) -> [Int] {
        data.matches(in: session)
    }

    func likedByAnyone(in session: PickSession) -> [Int] {
        data.likedByAnyone(in: session)
    }

    func markWatched(movieID: Int) {
        update { $0.markWatched(movieID: movieID, at: .now) }
    }

    /// Про какой фильм спросить «Как вам?» сегодня. Без «я» — ни про какой.
    var movieToRate: Movie? {
        guard let me = data.meID else { return nil }
        return data.movieToRate(me: me, now: .now)
    }

    /// Моя оценка фильма. Без «я» ничего не делает.
    func rate(movieID: Int, _ verdict: MovieVerdict) {
        guard let me = data.meID else { return }
        update { $0.rate(movieID: movieID, verdict, by: me, at: .now) }
    }

    /// Колода для меня: оба списка плюс рекомендации каталога. Нет сети — только списки.
    /// Рекомендации (до 6 запросов к Кинопоиску из 200 в день) просим один раз на подбор,
    /// дальше берём запомненные: колоду открывают много раз, и оба из пары видят одни и те же.
    func deck(for session: PickSession, catalog: some MovieCatalog) async -> [Movie] {
        async let excluded = excluded(for: session, catalog: catalog)
        let recommendations: [Movie]
        if let saved = recommendationsByPick[session.id] {
            recommendations = saved
        } else {
            recommendations = await DeckLoader.recommendations(seeds: data.recommendationSeeds(),
                                                               mood: session.mood, catalog: catalog)
            // Пусто — скорее всего, не было сети: в следующий раз попросим снова.
            if !recommendations.isEmpty { recommendationsByPick[session.id] = recommendations }
        }
        // Фильмы с телефона — всегда в конце: без сети и при лимите Кинопоиска колода живёт на них.
        // В `recommendationsByPick` их не кладём, чтобы с появлением сети пришли и сетевые.
        let local = await catalog.localMovies(genres: session.mood.genres)
        return data.deck(for: session, recommendations: recommendations + local, me: data.meID ?? UUID(),
                         excluded: await excluded)
    }

    /// «Похожие» на 3 последних фильма с 👎 (до 3 запросов к Кинопоиску), один раз на подбор.
    private func excluded(for session: PickSession, catalog: some MovieCatalog) async -> Set<Int> {
        if let saved = excludedByPick[session.id] { return saved }
        let excluded = await DeckLoader.similar(to: data.dislikedMovies(), catalog: catalog)
        // Пусто — 👎 нет или не было сети: в следующий раз проверим снова.
        if !excluded.isEmpty { excludedByPick[session.id] = excluded }
        return excluded
    }
}
