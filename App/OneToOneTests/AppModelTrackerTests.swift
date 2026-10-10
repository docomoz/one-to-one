import Core
import Foundation
import Testing
@testable import OneToOne

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
    let date = Date(timeIntervalSince1970: 1_000_000)

    model.logSex(types: [.vaginal, .cunnilingus], orgasmsMan: 1, orgasmsWoman: 2, date: date)

    let saved = try #require(try store.load().sexEntries.first)
    #expect(saved.types == [.vaginal, .cunnilingus])
    #expect(saved.orgasmsMan == 1)
    #expect(saved.orgasmsWoman == 2)
    #expect(saved.date == date)
    #expect(saved.createdBy == me)
}

@MainActor
@Test func updateSexReplacesEntryWithSameID() throws {
    let (model, store) = makeModel()
    model.logSex(types: [.vaginal], orgasmsMan: 1, orgasmsWoman: 1, date: .now)
    var edited = model.data.sexEntries[0]
    edited.orgasmsWoman = 3

    model.updateSex(edited)

    #expect(try store.load().sexEntries == [edited])
}

@MainActor
@Test func deleteSexRemovesOnlyThatEntry() throws {
    let (model, store) = makeModel()
    model.logSex(types: [.vaginal], orgasmsMan: 1, orgasmsWoman: 1, date: .now)
    model.logSex(types: [.anal], orgasmsMan: 1, orgasmsWoman: 0, date: .now)
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
@Test func orgasmDefaultsCopyLatestEntryByDate() {
    let (model, _) = makeModel()
    model.logSex(types: [.vaginal], orgasmsMan: 2, orgasmsWoman: 3, date: Date(timeIntervalSince1970: 2_000))
    // Отмеченная задним числом запись не должна менять значения по умолчанию.
    model.logSex(types: [.vaginal], orgasmsMan: 0, orgasmsWoman: 0, date: Date(timeIntervalSince1970: 1_000))

    #expect(model.orgasmDefaults == OrgasmDefaults(man: 2, woman: 3))
}
