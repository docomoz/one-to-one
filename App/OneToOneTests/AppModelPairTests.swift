import Core
import Testing
@testable import OneToOne

@MainActor
@Test func setTogetherSinceSaves() throws {
    let store = InMemoryStore()
    let model = AppModel(store: store)
    let day = DayKey(year: 2023, month: 10, day: 22)

    model.setTogetherSince(day)
    #expect(try store.load().togetherSince == day)

    model.setTogetherSince(nil)
    #expect(try store.load().togetherSince == nil)
}
