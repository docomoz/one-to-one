import Foundation
import Testing
@testable import Core

private let man = Person(name: "Макс", sex: .male)
private let woman = Person(name: "Даша", sex: .female)

private func movie(_ id: Int) -> Movie {
    Movie(id: id, title: "Фильм \(id)", year: 2020, genres: ["комедия"], overview: "", posterURL: nil)
}

private func pairedData() -> AppData {
    var data = AppData()
    data.couple = try! Couple.make(man, woman)
    data.meID = man.id
    return data
}

private func at(hours: Double) -> Date { Date(timeIntervalSince1970: hours * 3600) }

/// В UTC час 0 — полночь 1 января 1970, поэтому часы 0–23 — первый день, 24–47 — второй.
private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}()

/// Данные, где вечером первого дня нажали «Смотрим» на фильме `id`.
private func watched(_ id: Int = 1, hours: Double = 20) -> AppData {
    var data = pairedData()
    data.movieCache[id] = movie(id)
    data.markWatched(movieID: id, at: at(hours: hours))
    return data
}

@Test func noBannerOnWatchDay() {
    #expect(watched().movieToRate(me: man.id, now: at(hours: 23), calendar: utc) == nil)
}

@Test func bannerNextDay() {
    #expect(watched().movieToRate(me: man.id, now: at(hours: 30), calendar: utc) == movie(1))
}

@Test func onlyLastWatchedAsked() {
    var data = watched(1, hours: 20)
    data.movieCache[2] = movie(2)
    data.markWatched(movieID: 2, at: at(hours: 21))

    #expect(data.movieToRate(me: man.id, now: at(hours: 30), calendar: utc) == movie(2))
}

@Test(arguments: [MovieVerdict.like, .dislike, .skip])
func anyVerdictHidesBanner(_ verdict: MovieVerdict) {
    var data = watched()
    data.rate(movieID: 1, verdict, by: man.id, at: at(hours: 30))

    #expect(data.movieToRate(me: man.id, now: at(hours: 31), calendar: utc) == nil)
}

@Test func partnerRatingDoesNotHideMine() {
    var data = watched()
    data.rate(movieID: 1, .like, by: woman.id, at: at(hours: 30))

    #expect(data.movieToRate(me: man.id, now: at(hours: 31), calendar: utc) == movie(1))
}

@Test func newPickHidesBanner() {
    var data = watched()
    _ = data.startPick(mood: .laugh, startedBy: woman.id, at: at(hours: 25))

    #expect(data.movieToRate(me: man.id, now: at(hours: 30), calendar: utc) == nil)
}

@Test func noBannerForWatchedWithoutDate() {
    var data = pairedData()
    data.movieCache[1] = movie(1)
    data.watched = [1]

    #expect(data.movieToRate(me: man.id, now: at(hours: 30), calendar: utc) == nil)
}

@Test func noBannerWhenMovieNotCached() {
    var data = pairedData()
    data.markWatched(movieID: 99, at: at(hours: 20))

    #expect(data.movieToRate(me: man.id, now: at(hours: 30), calendar: utc) == nil)
}

@Test func markWatchedKeepsEarliestDate() {
    var later = pairedData()
    later.markWatched(movieID: 1, at: at(hours: 20))
    later.markWatched(movieID: 1, at: at(hours: 30))
    var earlier = pairedData()
    earlier.markWatched(movieID: 1, at: at(hours: 30))
    earlier.markWatched(movieID: 1, at: at(hours: 20))

    #expect(later.watchedAt[1] == at(hours: 20))
    #expect(earlier.watchedAt[1] == at(hours: 20))
    #expect(later.watched == [1])
}

@Test func rateReplacesMyPreviousVerdict() {
    var data = pairedData()
    data.rate(movieID: 1, .like, by: woman.id, at: at(hours: 1))
    data.rate(movieID: 1, .like, by: man.id, at: at(hours: 2))
    data.rate(movieID: 1, .dislike, by: man.id, at: at(hours: 3))

    #expect(data.ratings == [
        MovieRating(movieID: 1, personID: woman.id, verdict: .like, date: at(hours: 1)),
        MovieRating(movieID: 1, personID: man.id, verdict: .dislike, date: at(hours: 3)),
    ])
}

@Test func oldDataWithoutRatingsDecodes() throws {
    let encoded = try JSONEncoder().encode(watched())
    var dict = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    dict["watchedAt"] = nil
    dict["ratings"] = nil
    let old = try JSONSerialization.data(withJSONObject: dict)

    let data = try JSONDecoder().decode(AppData.self, from: old)

    #expect(data.watchedAt.isEmpty)
    #expect(data.ratings.isEmpty)
    #expect(data.watched == [1])
}

@Test func likedWatchedMovieBecomesSeed() {
    var data = watched()
    data.rate(movieID: 1, .like, by: man.id, at: at(hours: 30))

    #expect(data.recommendationSeeds() == [1])
}

@Test func likedByBothGoesFirst() {
    var data = watched()
    data.rate(movieID: 1, .like, by: man.id, at: at(hours: 30))
    data.rate(movieID: 1, .like, by: woman.id, at: at(hours: 31))
    let session = data.startPick(mood: .laugh, startedBy: man.id, at: at(hours: 40))
    data.swipe(.yes, movie: movie(2), in: session, by: man.id, at: at(hours: 41))

    #expect(data.recommendationSeeds() == [1, 2])
}

@Test func likedByOneSortedByRatingDate() {
    var data = watched()
    data.rate(movieID: 1, .like, by: man.id, at: at(hours: 50))
    let session = data.startPick(mood: .laugh, startedBy: man.id, at: at(hours: 40))
    data.swipe(.yes, movie: movie(2), in: session, by: man.id, at: at(hours: 41))

    #expect(data.recommendationSeeds() == [1, 2])
}

@Test func mixedVerdictIsNotSeed() {
    var data = watched()
    data.rate(movieID: 1, .like, by: man.id, at: at(hours: 30))
    data.rate(movieID: 1, .dislike, by: woman.id, at: at(hours: 31))

    #expect(data.recommendationSeeds().isEmpty)
    #expect(data.dislikedMovies() == [1])
}

@Test func skipDoesNothing() {
    var data = watched()
    data.rate(movieID: 1, .skip, by: man.id, at: at(hours: 30))

    #expect(data.recommendationSeeds().isEmpty)
    #expect(data.dislikedMovies().isEmpty)
}

@Test func dislikedMoviesLastThree() {
    var data = pairedData()
    for id in 1...4 { data.rate(movieID: id, .dislike, by: man.id, at: at(hours: Double(id))) }
    data.rate(movieID: 1, .dislike, by: woman.id, at: at(hours: 0.5))

    #expect(data.dislikedMovies() == [4, 3, 2])
}

@Test func seedsStillLimitFive() {
    var data = pairedData()
    for id in 1...4 { data.addToWatchlist(movie(id), ownerID: woman.id, addedAt: at(hours: Double(id))) }
    for id in 10...12 {
        data.markWatched(movieID: id, at: at(hours: 5))
        data.rate(movieID: id, .like, by: man.id, at: at(hours: Double(id)))
    }

    #expect(data.recommendationSeeds() == [12, 11, 10, 4, 3])
}
