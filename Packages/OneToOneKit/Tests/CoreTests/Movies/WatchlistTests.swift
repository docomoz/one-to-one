import Foundation
import Testing
@testable import Core

private let me = UUID()
private let partner = UUID()
private let film = Movie(id: 1, title: "Амели", year: 2001, genres: ["комедия"], overview: "", posterURL: nil)
private let other = Movie(id: 2, title: "Брат", year: 1997, genres: ["драма"], overview: "", posterURL: nil)

@Test func addToWatchlistAddsItemAndCachesMovie() throws {
    var data = AppData()
    let date = Date(timeIntervalSince1970: 100)

    data.addToWatchlist(film, ownerID: me, addedAt: date)

    let saved = try #require(data.watchlist.first)
    #expect(saved == WatchlistItem(movie: film, ownerID: me, addedAt: date, fromLater: false))
    #expect(data.movieCache[1] == film)
}

@Test func addToWatchlistTwiceKeepsOneInMyList() {
    var data = AppData()

    data.addToWatchlist(film, ownerID: me, addedAt: .now)
    data.addToWatchlist(film, ownerID: me, addedAt: .now)
    data.addToWatchlist(film, ownerID: partner, addedAt: .now)

    #expect(data.watchlist.count == 2)
}

@Test func removeFromWatchlistRemovesOnlyMine() {
    var data = AppData()
    data.addToWatchlist(film, ownerID: me, addedAt: .now)
    data.addToWatchlist(film, ownerID: partner, addedAt: .now)

    data.removeFromWatchlist(movieID: 1, ownerID: me)

    #expect(data.watchlist.map(\.ownerID) == [partner])
}

@Test func watchlistOfOwnerIsNewestFirst() {
    var data = AppData()
    data.addToWatchlist(film, ownerID: me, addedAt: Date(timeIntervalSince1970: 1))
    data.addToWatchlist(other, ownerID: me, addedAt: Date(timeIntervalSince1970: 2))
    data.addToWatchlist(film, ownerID: partner, addedAt: Date(timeIntervalSince1970: 3))

    #expect(data.watchlist(of: me).map(\.movie.id) == [2, 1])
    #expect(data.watchlist(of: partner).map(\.movie.id) == [1])
}

@Test func partnerIDIsTheOtherPerson() throws {
    let man = Person(id: UUID(), name: "Макс", sex: .male)
    let woman = Person(id: UUID(), name: "Даша", sex: .female)
    var data = AppData()
    data.couple = try Couple.make(man, woman)

    data.meID = woman.id
    #expect(data.partnerID == man.id)
    data.meID = man.id
    #expect(data.partnerID == woman.id)
    data.meID = nil
    #expect(data.partnerID == nil)
}

@Test func addToWatchlistKeepsCachedMovie() {
    var data = AppData()
    var rated = film
    rated.ratings = Ratings(imdb: 8.3, kinopoisk: 8.0)
    data.movieCache[1] = rated

    data.addToWatchlist(film, ownerID: me, addedAt: .now)

    #expect(data.movieCache[1] == rated)
}
