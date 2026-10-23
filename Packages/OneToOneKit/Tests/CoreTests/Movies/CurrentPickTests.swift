import Foundation
import Testing
@testable import Core

private let man = Person(name: "Боря", sex: .male)
private let woman = Person(name: "Аня", sex: .female)

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

@Test func noSessionsNoCurrentPick() {
    #expect(AppData().currentPick == nil)
}

@Test func latestSessionIsCurrent() {
    var data = pairedData()
    _ = data.startPick(mood: .laugh, startedBy: man.id, at: at(hours: 0))
    let second = data.startPick(mood: .cry, startedBy: woman.id, at: at(hours: 1))

    #expect(data.currentPick == second)
}

@Test func watchingLikedMovieEndsPick() {
    var data = pairedData()
    let session = data.startPick(mood: .laugh, startedBy: man.id, at: at(hours: 0))
    data.swipe(.yes, movie: movie(1), in: session, by: man.id, at: at(hours: 0))

    data.markWatched(movieID: 1, at: at(hours: 1))

    #expect(data.currentPick == nil)
}

@Test func watchingUnlikedMovieKeepsPick() {
    var data = pairedData()
    let session = data.startPick(mood: .laugh, startedBy: man.id, at: at(hours: 0))
    data.swipe(.no, movie: movie(1), in: session, by: man.id, at: at(hours: 0))

    data.markWatched(movieID: 1, at: at(hours: 1))

    #expect(data.currentPick == session)
}

@Test func newPickAfterWatchedIsCurrent() {
    var data = pairedData()
    let first = data.startPick(mood: .laugh, startedBy: man.id, at: at(hours: 0))
    data.swipe(.yes, movie: movie(1), in: first, by: man.id, at: at(hours: 0))
    data.markWatched(movieID: 1, at: at(hours: 1))

    let second = data.startPick(mood: .romance, startedBy: man.id, at: at(hours: 24))

    #expect(data.currentPick == second)
}

@Test func hasSwipedOnlyForThatPerson() {
    var data = pairedData()
    let session = data.startPick(mood: .laugh, startedBy: woman.id, at: at(hours: 0))
    data.swipe(.no, movie: movie(1), in: session, by: man.id, at: at(hours: 0))

    #expect(data.hasSwiped(in: session, person: man.id))
    #expect(!data.hasSwiped(in: session, person: woman.id))
}

@Test func moviesSkipsUnknownIDs() {
    var data = pairedData()
    let session = data.startPick(mood: .laugh, startedBy: man.id, at: at(hours: 0))
    data.swipe(.yes, movie: movie(1), in: session, by: man.id, at: at(hours: 0))

    #expect(data.movies([2, 1]).map(\.id) == [1])
}
