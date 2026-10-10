import Foundation

/// Вечер с фильмом: подбор, свайпы, совпадения, «Смотрим».
extension AppData {
    /// Начинает новый подбор под настроение.
    public mutating func startPick(mood: Mood, startedBy personID: UUID, at date: Date) -> PickSession {
        let session = PickSession(mood: mood, startedBy: personID, startedAt: date)
        sessions.append(session)
        return session
    }

    /// Запоминает свайп. «Потом» ещё кладёт фильм в список этого человека.
    /// Возвращает `true`, если именно этот свайп дал новое совпадение.
    @discardableResult
    public mutating func swipe(_ action: SwipeAction, movie: Movie, in session: PickSession,
                               by personID: UUID, at date: Date) -> Bool {
        let matchedBefore = matches(in: session)
        swipes.append(Swipe(sessionID: session.id, personID: personID, movieID: movie.id, action: action, date: date))
        // Фильм кладём в кэш, чтобы потом не просить его у Кинопоиска; addToWatchlist делает это сам.
        if action == .later {
            addToWatchlist(movie, ownerID: personID, addedAt: date, fromLater: true)
        } else if movieCache[movie.id] == nil {
            movieCache[movie.id] = movie
        }
        return !matchedBefore.contains(movie.id) && matches(in: session).contains(movie.id)
    }

    /// Совпадения подбора в порядке, в котором они случились. Без пары совпадений нет.
    public func matches(in session: PickSession) -> [Int] {
        guard let couple else { return [] }
        return MatchFinder.matches(swipes(in: session), couple: couple)
    }

    /// Запасной список, когда колода кончилась без совпадения. Только ♥ от этой пары.
    public func likedByAnyone(in session: PickSession) -> [Int] {
        guard let couple else { return [] }
        let pair = [couple.man.id, couple.woman.id]
        return MatchFinder.likedByAnyone(swipes(in: session).filter { pair.contains($0.personID) })
    }

    /// Подбор, который сейчас идёт: последний, пока не посмотрели фильм, получивший в нём ♥.
    /// Так «Смотрим» сам закрывает подбор, а новый подбор сразу становится текущим.
    public var currentPick: PickSession? {
        guard let last = sessions.last else { return nil }
        let liked = MatchFinder.likedByAnyone(swipes(in: last))
        return liked.contains(where: watched.contains) ? nil : last
    }

    /// Свайпал ли человек хоть раз в этом подборе.
    public func hasSwiped(in session: PickSession, person personID: UUID) -> Bool {
        swipes.contains { $0.sessionID == session.id && $0.personID == personID }
    }

    /// Фильмы из кэша в том же порядке. Каких нет в кэше, пропускаем.
    public func movies(_ ids: [Int]) -> [Movie] {
        ids.compactMap { movieCache[$0] }
    }

    /// «Смотрим»: фильм больше не попадёт в колоду. Дата нужна, чтобы назавтра спросить «Как вам?»;
    /// остаётся самая ранняя, так повторное нажатие не откладывает вопрос.
    public mutating func markWatched(movieID: Int, at date: Date) {
        watched.insert(movieID)
        watchedAt[movieID] = min(watchedAt[movieID] ?? date, date)
    }

    /// Колода для этого человека: оба списка, рекомендации, без просмотренных
    /// и без того, что он уже свайпнул в этом подборе.
    public func deck(for session: PickSession, recommendations: [Movie], me personID: UUID) -> [Movie] {
        let swipedByMe = Set(swipes(in: session).filter { $0.personID == personID }.map(\.movieID))
        return DeckBuilder.build(lists: watchlist, recommendations: recommendations, mood: session.mood,
                                 watched: watched, swipedByMe: swipedByMe)
    }

    /// По каким фильмам просить «похожие»: последние, что получили ♥ (и никто не передумал)
    /// или попали в списки, свежие первыми, без просмотренных.
    /// Их немного, потому что у Кинопоиска 200 бесплатных запросов в день.
    public func recommendationSeeds(limit: Int = 5) -> [Int] {
        let liked = MatchFinder.latestSwipes(swipes).filter { $0.action == .yes }.map { ($0.date, $0.movieID) }
        let listed = watchlist.map { ($0.addedAt, $0.movie.id) }
        var seen = watched
        return (liked + listed).sorted { $0.0 > $1.0 }
            .map(\.1)
            .filter { seen.insert($0).inserted }
            .prefix(limit)
            .map { $0 }
    }

    private func swipes(in session: PickSession) -> [Swipe] {
        swipes.filter { $0.sessionID == session.id }
    }
}
