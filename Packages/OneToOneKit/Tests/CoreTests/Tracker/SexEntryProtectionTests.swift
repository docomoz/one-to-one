import Foundation
import Testing
@testable import Core

@Test func decodesOldEntryWithoutProtection() throws {
    let json = #"{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","day":{"year":2026,"month":10,"day":9},"types":["vaginal"],"orgasmsMan":1,"orgasmsWoman":1,"createdBy":"6F9619FF-8B86-D011-B42D-00C04FC964FF"}"#
    let entry = try JSONDecoder().decode(SexEntry.self, from: Data(json.utf8))
    #expect(entry.condom == nil)
    #expect(entry.finish == nil)
    #expect(entry.types == [.vaginal])
}

@Test func protectionSurvivesRoundTrip() throws {
    let entry = SexEntry(day: DayKey(year: 2026, month: 10, day: 9), types: [.vaginal],
                         orgasmsMan: 1, orgasmsWoman: 1, condom: false, finish: .inside, createdBy: UUID())
    let decoded = try JSONDecoder().decode(SexEntry.self, from: JSONEncoder().encode(entry))
    #expect(decoded == entry)
}

@Test func protectionClearedWithoutVaginal() {
    let day = DayKey(year: 2026, month: 10, day: 9)
    let anal = SexEntry(day: day, types: [.anal], orgasmsMan: 1, orgasmsWoman: 1,
                        condom: false, finish: .inside, createdBy: UUID())
    let vaginal = SexEntry(day: day, types: [.vaginal, .anal], orgasmsMan: 1, orgasmsWoman: 1,
                           condom: false, finish: .inside, createdBy: UUID())

    #expect(anal.withProtectionOnlyIfVaginal.condom == nil)
    #expect(anal.withProtectionOnlyIfVaginal.finish == nil)
    #expect(vaginal.withProtectionOnlyIfVaginal == vaginal)
}
