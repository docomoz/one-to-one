import Core
import Foundation
import Testing
@testable import Sync

private let man = Person(id: UUID(uuidString: "00000000-0000-0000-0000-00000000000A")!, name: "Максим", sex: .male)
private let woman = Person(id: UUID(uuidString: "00000000-0000-0000-0000-00000000000B")!, name: "Даша", sex: .female)

private func day(_ number: Int) -> DayKey { DayKey(year: 2026, month: 10, day: number) }

private func sex(on number: Int) -> SexEntry {
    SexEntry(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000D\(number)")!, day: day(number),
             types: [.vaginal], orgasmsMan: 1, orgasmsWoman: 1, createdBy: man.id)
}

/// Пока шла синхронизация, на телефоне ничего не меняли: берём всё синхронизируемое из результата.
@Test func syncedFieldsReplacedLocalFieldsKept() {
    var started = AppData()
    started.meID = man.id
    started.periodDays = [day(1)]
    var synced = started
    synced.sexEntries = [sex(on: 2)]
    synced.periodDays = []

    let merged = SyncRecordMapper.merge(synced: synced, startedFrom: started, into: started)

    #expect(merged.sexEntries == [sex(on: 2)])
    #expect(merged.periodDays.isEmpty)
    #expect(merged.meID == man.id)
}

/// Правка во время синхронизации не откатывается: ни новая запись, ни удаление, ни локальные поля.
@Test func editsDuringSyncSurvive() {
    var started = AppData()
    started.periodDays = [day(1)]
    var current = started
    current.periodDays = [day(3)]          // удалила 1-е, добавила 3-е, пока шёл запрос
    current.meID = woman.id
    current.movieCache = [7: Movie(id: 7, title: "Фильм", year: nil, genres: [], overview: "", posterURL: nil, imdbID: nil, ratings: Ratings())]
    var synced = started
    synced.sexEntries = [sex(on: 2)]       // партнёр записал секс

    let merged = SyncRecordMapper.merge(synced: synced, startedFrom: started, into: current)

    #expect(merged.periodDays == [day(3)])
    #expect(merged.sexEntries == [sex(on: 2)])
    #expect(merged.meID == woman.id)
    #expect(merged.movieCache.keys.sorted() == [7])
}
