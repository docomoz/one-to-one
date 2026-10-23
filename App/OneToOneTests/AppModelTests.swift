import Core
import Foundation
import Testing
@testable import OneToOne

@MainActor
@Test func appModelLoadsDataFromStore() throws {
    var saved = AppData()
    saved.watched = [326]
    let store = InMemoryStore(saved)

    let model = AppModel(store: store)

    #expect(model.data == saved)
}

@MainActor
@Test func appModelUpdateSavesImmediately() throws {
    let store = InMemoryStore()
    let model = AppModel(store: store)
    let me = Person(name: "Боря", sex: .male)

    model.update { $0.meID = me.id }

    #expect(model.data.meID == me.id)
    #expect(try store.load().meID == me.id)
}
