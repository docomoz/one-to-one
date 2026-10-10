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
}
