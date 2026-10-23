import Foundation
import Testing
@testable import Core

private let man = Person(name: "Боря", sex: .male)
private let woman = Person(name: "Аня", sex: .female)

private func movie(_ id: Int, _ genres: [String] = ["комедия"]) -> Movie {
    Movie(id: id, title: "Фильм \(id)", year: 2020, genres: genres, overview: "", posterURL: nil)
}

private func pairedData() -> AppData {
    var data = AppData()
    data.couple = try! Couple.make(man, woman)
    data.meID = man.id
    return data
}

private func at(hours: Double) -> Date { Date(timeIntervalSince1970: hours * 3600) }

@Test func startPickSavesSession() {
    var data = pairedData()

    let session = data.startPick(mood: .laugh, startedBy: man.id, at: at(hours: 0))

    #expect(data.sessions == [session])
    #expect(session.mood == .laugh)
    #expect(session.startedBy == man.id)
}

@Test func swipeReturnsTrueOnlyWhenMatchHappens() {
    var data = pairedData()
    let session = data.startPick(mood: .laugh, startedBy: man.id, at: at(hours: 0))

    #expect(data.swipe(.yes, movie: movie(1), in: session, by: man.id, at: at(hours: 0)) == false)
    #expect(data.swipe(.yes, movie: movie(1), in: session, by: woman.id, at: at(hours: 6)) == true)
    #expect(data.matches(in: session) == [1])
    #expect(data.swipe(.yes, movie: movie(1), in: session, by: woman.id, at: at(hours: 7)) == false)
}

@Test func swipesOfOtherSessionDontMatch() {
    var data = pairedData()
    let first = data.startPick(mood: .laugh, startedBy: man.id, at: at(hours: 0))
    let second = data.startPick(mood: .laugh, startedBy: woman.id, at: at(hours: 24))
    data.swipe(.yes, movie: movie(1), in: first, by: man.id, at: at(hours: 0))

    #expect(data.swipe(.yes, movie: movie(1), in: second, by: woman.id, at: at(hours: 24)) == false)
    #expect(data.matches(in: second).isEmpty)
}

@Test func swipeCachesMovie() {
    var data = pairedData()
    let session = data.startPick(mood: .laugh, startedBy: man.id, at: at(hours: 0))

    data.swipe(.no, movie: movie(5), in: session, by: man.id, at: at(hours: 0))

    #expect(data.movieCache[5] == movie(5))
}

@Test func laterAddsToMyWatchlist() throws {
    var data = pairedData()
    let session = data.startPick(mood: .laugh, startedBy: man.id, at: at(hours: 0))

    let matched = data.swipe(.later, movie: movie(1), in: session, by: man.id, at: at(hours: 1))

    #expect(matched == false)
    let item = try #require(data.watchlist.first)
    #expect(item.ownerID == man.id)
    #expect(item.fromLater)
    #expect(item.addedAt == at(hours: 1))
    #expect(data.watchlist(of: woman.id).isEmpty)
}

@Test func likedByAnyoneInSession() {
    var data = pairedData()
    let session = data.startPick(mood: .laugh, startedBy: man.id, at: at(hours: 0))
    data.swipe(.yes, movie: movie(1), in: session, by: man.id, at: at(hours: 0))
    data.swipe(.no, movie: movie(1), in: session, by: woman.id, at: at(hours: 1))
    data.swipe(.yes, movie: movie(2), in: session, by: woman.id, at: at(hours: 2))

    #expect(data.likedByAnyone(in: session) == [1, 2])
}

@Test func markWatchedRemembersMovie() {
    var data = pairedData()
    data.markWatched(movieID: 7, at: at(hours: 1))
    #expect(data.watched == [7])
}

@Test func watchedExcludedFromNextDeck() {
    var data = pairedData()
    data.addToWatchlist(movie(1), ownerID: man.id, addedAt: at(hours: 0))
    data.addToWatchlist(movie(2), ownerID: woman.id, addedAt: at(hours: 0))
    data.markWatched(movieID: 1, at: at(hours: 1))
    let session = data.startPick(mood: .laugh, startedBy: man.id, at: at(hours: 1))

    let deck = data.deck(for: session, recommendations: [movie(1), movie(3)], me: man.id)

    #expect(deck.map(\.id) == [2, 3])
}

@Test func deckSkipsMoviesISwipedInThisSessionOnly() {
    var data = pairedData()
    data.addToWatchlist(movie(1), ownerID: man.id, addedAt: at(hours: 0))
    data.addToWatchlist(movie(2), ownerID: woman.id, addedAt: at(hours: 0))
    let old = data.startPick(mood: .laugh, startedBy: man.id, at: at(hours: 0))
    data.swipe(.no, movie: movie(2), in: old, by: man.id, at: at(hours: 0))
    let session = data.startPick(mood: .laugh, startedBy: man.id, at: at(hours: 24))
    data.swipe(.no, movie: movie(1), in: session, by: man.id, at: at(hours: 24))
    data.swipe(.yes, movie: movie(2), in: session, by: woman.id, at: at(hours: 24))

    #expect(data.deck(for: session, recommendations: [], me: man.id).map(\.id) == [2])
    #expect(data.deck(for: session, recommendations: [], me: woman.id).map(\.id) == [1])
}

@Test func recommendationSeedsAreLastFiveLikedOrListed() {
    var data = pairedData()
    let session = data.startPick(mood: .laugh, startedBy: man.id, at: at(hours: 0))
    for id in 1...4 { data.addToWatchlist(movie(id), ownerID: woman.id, addedAt: at(hours: Double(id))) }
    data.swipe(.yes, movie: movie(10), in: session, by: man.id, at: at(hours: 10))
    data.swipe(.no, movie: movie(11), in: session, by: man.id, at: at(hours: 11))
    data.swipe(.yes, movie: movie(3), in: session, by: man.id, at: at(hours: 12))
    data.swipe(.yes, movie: movie(12), in: session, by: woman.id, at: at(hours: 0.5))

    #expect(data.recommendationSeeds() == [3, 10, 4, 2, 1])
}

@Test func recommendationSeedsSkipChangedMindAndWatched() {
    var data = pairedData()
    let session = data.startPick(mood: .laugh, startedBy: man.id, at: at(hours: 0))
    data.swipe(.yes, movie: movie(1), in: session, by: man.id, at: at(hours: 1))
    data.swipe(.no, movie: movie(1), in: session, by: man.id, at: at(hours: 2))
    data.swipe(.yes, movie: movie(2), in: session, by: man.id, at: at(hours: 3))
    data.swipe(.yes, movie: movie(3), in: session, by: woman.id, at: at(hours: 4))
    data.markWatched(movieID: 3, at: at(hours: 1))

    #expect(data.recommendationSeeds() == [2])
}

@Test func likedByAnyoneOnlyFromCouple() {
    var data = pairedData()
    let session = data.startPick(mood: .laugh, startedBy: man.id, at: at(hours: 0))
    data.swipe(.yes, movie: movie(1), in: session, by: UUID(), at: at(hours: 0))

    #expect(data.likedByAnyone(in: session).isEmpty)
}
