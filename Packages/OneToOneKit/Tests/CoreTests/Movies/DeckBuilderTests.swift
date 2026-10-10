import Foundation
import Testing
@testable import Core

private let me = UUID()
private let partner = UUID()

private func movie(_ id: Int, _ genres: [String] = ["комедия"]) -> Movie {
    Movie(id: id, title: "Фильм \(id)", year: 2020, genres: genres, overview: "", posterURL: nil)
}

private func item(_ movie: Movie, owner: UUID = me) -> WatchlistItem {
    WatchlistItem(movie: movie, ownerID: owner, addedAt: Date(timeIntervalSince1970: 0), fromLater: false)
}

private func ids(_ movies: [Movie]) -> [Int] { movies.map(\.id) }

@Test func listsComeFirst() {
    let deck = DeckBuilder.build(lists: [item(movie(1)), item(movie(2), owner: partner)],
                                 recommendations: [movie(10), movie(11)],
                                 mood: .laugh, watched: [], swipedByMe: [])
    #expect(ids(deck) == [1, 2, 10, 11])
}

@Test func moodSortsListsNotFilters() {
    let drama = movie(1, ["драма"])
    let comedy = movie(2, ["комедия"])
    let deck = DeckBuilder.build(lists: [item(drama), item(comedy, owner: partner)],
                                 recommendations: [movie(10)],
                                 mood: .laugh, watched: [], swipedByMe: [])
    #expect(ids(deck) == [2, 1, 10])
}

@Test func recommendationsFilteredByMood() {
    let deck = DeckBuilder.build(lists: [],
                                 recommendations: [movie(10, ["ужасы"]), movie(11, ["комедия", "драма"])],
                                 mood: .laugh, watched: [], swipedByMe: [])
    #expect(ids(deck) == [11])
}

@Test func dedupesAcrossListsAndRecs() {
    let shared = movie(1)
    let deck = DeckBuilder.build(lists: [item(shared), item(shared, owner: partner)],
                                 recommendations: [shared, movie(10), movie(10)],
                                 mood: .laugh, watched: [], swipedByMe: [])
    #expect(ids(deck) == [1, 10])
}

@Test func excludesWatchedAndSwiped() {
    let deck = DeckBuilder.build(lists: [item(movie(1)), item(movie(2))],
                                 recommendations: [movie(10), movie(11)],
                                 mood: .laugh, watched: [1, 10], swipedByMe: [2])
    #expect(ids(deck) == [11])
}

@Test func worksWithNoRecommendations() {
    let deck = DeckBuilder.build(lists: [item(movie(1, ["драма"])), item(movie(2), owner: partner)],
                                 recommendations: [],
                                 mood: .laugh, watched: [], swipedByMe: [])
    #expect(ids(deck) == [2, 1])
}

@Test func respectsLimit() {
    let deck = DeckBuilder.build(lists: (1...5).map { item(movie($0)) },
                                 recommendations: (10...20).map { movie($0) },
                                 mood: .laugh, watched: [], swipedByMe: [], limit: 7)
    #expect(ids(deck) == [1, 2, 3, 4, 5, 10, 11])
}

@Test func emptyWhenNothingToShow() {
    #expect(DeckBuilder.build(lists: [], recommendations: [], mood: .cry, watched: [], swipedByMe: []).isEmpty)
}
