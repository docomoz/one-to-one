import Core
import Foundation
import Testing
@testable import OneToOne

@MainActor
@Test func switchMeTogglesAndSaves() throws {
    let man = Person(name: "Боря", sex: .male)
    let woman = Person(name: "Аня", sex: .female)
    var data = AppData()
    data.couple = try Couple.make(man, woman)
    data.meID = man.id
    let store = InMemoryStore(data)
    let model = AppModel(store: store)

    model.switchMe()
    #expect(model.data.meID == woman.id)
    #expect(try store.load().meID == woman.id)

    model.switchMe()
    #expect(model.data.meID == man.id)
}

@MainActor
@Test func switchMeWithoutCoupleDoesNothing() {
    let model = AppModel(store: InMemoryStore())

    model.switchMe()

    #expect(model.data.meID == nil)
}

@MainActor
@Test func modelCurrentPickFollowsData() throws {
    let man = Person(name: "Боря", sex: .male)
    var data = AppData()
    data.couple = try Couple.make(man, Person(name: "Аня", sex: .female))
    data.meID = man.id
    let model = AppModel(store: InMemoryStore(data))

    let session = try #require(model.startPick(mood: .cry))

    #expect(model.currentPick == session)
}
