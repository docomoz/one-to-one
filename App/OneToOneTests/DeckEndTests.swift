import Core
import Foundation
import Testing
@testable import OneToOne

private let man = Person(name: "Боря", sex: .male)
private let woman = Person(name: "Аня", sex: .female)
private let amelie = Movie(id: 1, title: "Амели", year: 2001, genres: ["комедия"], overview: "", posterURL: nil)
private let brat = Movie(id: 2, title: "Брат", year: 1997, genres: ["драма"], overview: "", posterURL: nil)

private func started() -> (AppData, PickSession) {
    var data = AppData()
    data.couple = try! Couple.make(man, woman)
    data.meID = man.id
    let session = data.startPick(mood: .laugh, startedBy: man.id, at: .now)
    return (data, session)
}

@Test func deckEndShowsMatches() {
    var (data, session) = started()
    data.swipe(.yes, movie: amelie, in: session, by: man.id, at: .now)
    data.swipe(.yes, movie: brat, in: session, by: man.id, at: .now)
    data.swipe(.yes, movie: amelie, in: session, by: woman.id, at: .now)

    #expect(DeckEnd.make(data, session: session) == .matches([amelie]))
}

@Test func deckEndFallsBackToLiked() {
    var (data, session) = started()
    data.swipe(.yes, movie: brat, in: session, by: man.id, at: .now)
    data.swipe(.no, movie: brat, in: session, by: woman.id, at: .now)

    #expect(DeckEnd.make(data, session: session) == .liked([brat]))
}

@Test func deckEndWaitsForPartnerWhoHasNotSwiped() {
    var (data, session) = started()
    data.swipe(.no, movie: brat, in: session, by: man.id, at: .now)

    #expect(DeckEnd.make(data, session: session) == .waitForPartner(partnerName: "Аня"))
}

@Test func deckEndNoMoviesWhenNobodySwiped() {
    let (data, session) = started()

    #expect(DeckEnd.make(data, session: session) == .noMovies)
}

@Test func deckEndNothingLikedWhenBothSwiped() {
    var (data, session) = started()
    data.swipe(.no, movie: brat, in: session, by: man.id, at: .now)
    data.swipe(.later, movie: amelie, in: session, by: woman.id, at: .now)

    #expect(DeckEnd.make(data, session: session) == .nothingLiked)
}
