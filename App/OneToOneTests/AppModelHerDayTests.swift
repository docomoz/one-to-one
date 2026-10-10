import Core
import Testing
@testable import OneToOne

private let today = DayKey(year: 2026, month: 10, day: 10)

@MainActor
@Test func togglePeriodDaySaves() throws {
    let store = InMemoryStore()
    let model = AppModel(store: store)

    model.togglePeriodDay(today)

    #expect(try store.load().periodDays == [today])
}

@MainActor
@Test func setHerMoodSaves() throws {
    let store = InMemoryStore()
    let model = AppModel(store: store)

    model.setHerMood(.wants, for: today)

    #expect(try store.load().herMoods == [today: .wants])
}

@MainActor
@Test func toggleSymptomSaves() throws {
    let store = InMemoryStore()
    let model = AppModel(store: store)

    model.toggleSymptom(.preset(.cramps), on: today)

    #expect(try store.load().symptoms == [today: [.preset(.cramps)]])
}

@MainActor
@Test func addCustomSymptomSaves() throws {
    let store = InMemoryStore()
    let model = AppModel(store: store)

    model.addCustomSymptom("Мигрень", on: today)

    #expect(try store.load().symptoms == [today: [.custom("Мигрень")]])
}
