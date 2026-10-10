import Core
import Foundation
import Testing
@testable import OneToOne

private let today = DayKey(year: 2026, month: 10, day: 10)
private let adult = DayKey(year: 1996, month: 5, day: 12)

@MainActor
@Test func createCoupleSavesCoupleAndMe() throws {
    let store = InMemoryStore()
    let model = AppModel(store: store)
    let me = PersonDraft(sex: .female, name: "Даша", birthDate: adult)
    let partner = PersonDraft(sex: .male, name: "Максим", birthDate: adult)

    try model.createCouple(me: me, partner: partner, today: today)

    #expect(model.data.isPaired)
    #expect(model.data.meID == me.id)
    #expect(try store.load() == model.data)
}

@MainActor
@Test func createCoupleSameSexChangesNothing() throws {
    let store = InMemoryStore()
    let model = AppModel(store: store)
    let me = PersonDraft(sex: .female, name: "Даша", birthDate: adult)
    let partner = PersonDraft(sex: .female, name: "Аня", birthDate: adult)

    #expect(throws: OnboardingError.sameSex) { try model.createCouple(me: me, partner: partner, today: today) }
    #expect(model.data == AppData())
    #expect(try store.load() == AppData())
}
