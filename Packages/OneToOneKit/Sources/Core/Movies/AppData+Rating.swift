import Foundation

/// Оценка просмотренных фильмов: 👍 / 👎 / «не оценивать».
extension AppData {
    /// Запоминает оценку. Прежняя оценка этого человека этому фильму заменяется.
    public mutating func rate(movieID: Int, _ verdict: MovieVerdict, by personID: UUID, at date: Date) {
        ratings.removeAll { $0.movieID == movieID && $0.personID == personID }
        ratings.append(MovieRating(movieID: movieID, personID: personID, verdict: verdict, date: date))
    }

    /// Про какой фильм спросить «Как вам?»: последний, на котором нажали «Смотрим».
    /// Не в тот же день (ещё не посмотрели), не после моего ответа и не после нового подбора.
    public func movieToRate(me personID: UUID, now: Date, calendar: Calendar = .current) -> Movie? {
        guard let (movieID, watchDate) = watchedAt.max(by: { $0.value < $1.value }),
              DayKey(watchDate, calendar: calendar) < DayKey(now, calendar: calendar),
              !ratings.contains(where: { $0.movieID == movieID && $0.personID == personID }),
              !sessions.contains(where: { $0.startedAt > watchDate })
        else { return nil }
        return movieCache[movieID]
    }

    /// Фильмы с 👎 от любого из пары, свежие первыми: их «похожие» убираем из рекомендаций.
    public func dislikedMovies(limit: Int = 3) -> [Int] {
        var seen: Set<Int> = []
        return ratings.filter { $0.verdict == .dislike }
            .sorted { $0.date > $1.date }
            .map(\.movieID)
            .filter { seen.insert($0).inserted }
            .prefix(limit)
            .map { $0 }
    }

    /// Фильмы с 👍 и без единого 👎: сколько человек поставили 👍 и когда последний раз.
    func likedRatings() -> [Int: (likers: Int, lastLike: Date)] {
        let disliked = Set(ratings.filter { $0.verdict == .dislike }.map(\.movieID))
        var result: [Int: (likers: Int, lastLike: Date)] = [:]
        for rating in ratings where rating.verdict == .like && !disliked.contains(rating.movieID) {
            let old = result[rating.movieID]
            result[rating.movieID] = ((old?.likers ?? 0) + 1, max(old?.lastLike ?? rating.date, rating.date))
        }
        return result
    }
}
