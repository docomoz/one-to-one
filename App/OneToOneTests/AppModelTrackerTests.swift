import Core
import Foundation
import Testing
@testable import OneToOne

private let today = DayKey(year: 2026, month: 10, day: 10)

@MainActor
private func makeModel(meID: UUID = UUID()) -> (AppModel, InMemoryStore) {
    var data = AppData()
    data.meID = meID
    let store = InMemoryStore(data)
    return (AppModel(store: store), store)
}

@MainActor
@Test func logSexAddsEntryAndSaves() throws {
    let me = UUID()
    let (model, store) = makeModel(meID: me)
    let day = DayKey(year: 2026, month: 10, day: 9)

    model.logSex(types: [.vaginal, .cunnilingus], orgasmsMan: 1, orgasmsWoman: 2, day: day)

    let saved = try #require(try store.load().sexEntries.first)
    #expect(saved.types == [.vaginal, .cunnilingus])
    #expect(saved.orgasmsMan == 1)
    #expect(saved.orgasmsWoman == 2)
    #expect(saved.day == day)
    #expect(saved.createdBy == me)
}

@MainActor
@Test func updateSexReplacesEntryWithSameID() throws {
    let (model, store) = makeModel()
    model.logSex(types: [.vaginal], orgasmsMan: 1, orgasmsWoman: 1, day: today)
    var edited = model.data.sexEntries[0]
    edited.orgasmsWoman = 3

    model.updateSex(edited)

    #expect(try store.load().sexEntries == [edited])
}

@MainActor
@Test func logSexSavesProtection() throws {
    let (model, store) = makeModel()

    model.logSex(types: [.vaginal], orgasmsMan: 1, orgasmsWoman: 1, condom: false, finish: .inside, day: today)

    let saved = try #require(try store.load().sexEntries.first)
    #expect(saved.condom == false)
    #expect(saved.finish == .inside)
}

@MainActor
@Test func logSexWithoutVaginalDropsProtection() throws {
    let (model, store) = makeModel()

    model.logSex(types: [.blowjob], orgasmsMan: 1, orgasmsWoman: 1, condom: false, finish: .inside, day: today)

    let saved = try #require(try store.load().sexEntries.first)
    #expect(saved.condom == nil)
    #expect(saved.finish == nil)
}

@MainActor
@Test func updateSexWithoutVaginalDropsProtection() throws {
    let (model, store) = makeModel()
    model.logSex(types: [.vaginal], orgasmsMan: 1, orgasmsWoman: 1, condom: false, finish: .inside, day: today)
    var edited = model.data.sexEntries[0]
    edited.types = [.anal]

    model.updateSex(edited)

    let saved = try #require(try store.load().sexEntries.first)
    #expect(saved.condom == nil)
    #expect(saved.finish == nil)
}

@MainActor
@Test func deleteSexRemovesOnlyThatEntry() throws {
    let (model, store) = makeModel()
    model.logSex(types: [.vaginal], orgasmsMan: 1, orgasmsWoman: 1, day: today)
    model.logSex(types: [.anal], orgasmsMan: 1, orgasmsWoman: 0, day: today)
    let first = model.data.sexEntries[0]

    model.deleteSex(id: first.id)

    #expect(try store.load().sexEntries.map(\.types) == [[.anal]])
}

@MainActor
@Test func orgasmDefaultsAreOneForFirstEntry() {
    let (model, _) = makeModel()

    #expect(model.orgasmDefaults == OrgasmDefaults(man: 1, woman: 1))
}

@MainActor
@Test func orgasmDefaultsCopyLatestEntryByDay() {
    let (model, _) = makeModel()
    model.logSex(types: [.vaginal], orgasmsMan: 2, orgasmsWoman: 3, day: today)
    // Отмеченная задним числом запись не должна менять значения по умолчанию.
    model.logSex(types: [.vaginal], orgasmsMan: 0, orgasmsWoman: 0, day: today.adding(days: -1))

    #expect(model.orgasmDefaults == OrgasmDefaults(man: 2, woman: 3))
}

@MainActor
@Test func orgasmDefaultsTakeLastAddedOnSameDay() {
    let (model, _) = makeModel()
    model.logSex(types: [.vaginal], orgasmsMan: 1, orgasmsWoman: 1, day: today)
    model.logSex(types: [.vaginal], orgasmsMan: 0, orgasmsWoman: 2, day: today)

    #expect(model.orgasmDefaults == OrgasmDefaults(man: 0, woman: 2))
}
