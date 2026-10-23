import Core
import Foundation
import Testing
@testable import OneToOne

private let man = Person(name: "Боря", sex: .male)
private let woman = Person(name: "Аня", sex: .female)
private let film = Movie(id: 1, title: "Амели", year: 2001, genres: ["комедия"], overview: "", posterURL: nil)

private func pairedData(me: Person = man) -> AppData {
    var data = AppData()
    data.couple = try! Couple.make(man, woman)
    data.meID = me.id
    return data
}

@Test func noPickState() {
    #expect(PickCardState.make(pairedData()) == .noPick)
}

@Test func partnerStartedState() {
    var data = pairedData()
    _ = data.startPick(mood: .light, startedBy: woman.id, at: .now)

    #expect(PickCardState.make(data) == .partnerStarted(partnerName: "Аня", mood: .light))
}

@Test func inProgressAfterMySwipe() {
    var data = pairedData()
    let session = data.startPick(mood: .light, startedBy: woman.id, at: .now)
    data.swipe(.no, movie: film, in: session, by: man.id, at: .now)

    #expect(PickCardState.make(data) == .inProgress(session: session, matchCount: 0))
}

@Test func inProgressWhenIStarted() {
    var data = pairedData()
    let session = data.startPick(mood: .laugh, startedBy: man.id, at: .now)

    #expect(PickCardState.make(data) == .inProgress(session: session, matchCount: 0))
}

@Test func matchCountCounted() {
    var data = pairedData()
    let session = data.startPick(mood: .laugh, startedBy: man.id, at: .now)
    data.swipe(.yes, movie: film, in: session, by: man.id, at: .now)
    data.swipe(.yes, movie: film, in: session, by: woman.id, at: .now)

    #expect(PickCardState.make(data) == .inProgress(session: session, matchCount: 1))
}

@Test func moodTitlesFromSpec() {
    #expect(Mood.allCases.map(\.title) ==
        ["Посмеяться", "Что-то лёгкое", "Пощекотать нервы", "Поплакать", "Залипнуть", "Романтика"])
}
