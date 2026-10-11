import Foundation
import Core
import Testing
@testable import OneToOne

private func entry(condom: Bool?, finish: SexFinish?) -> SexEntry {
    SexEntry(day: DayKey(year: 2026, month: 10, day: 9), types: [.vaginal], orgasmsMan: 1, orgasmsWoman: 1,
             condom: condom, finish: finish, createdBy: UUID())
}

@Test func protectionTextJoinsParts() {
    #expect(entry(condom: false, finish: .inside).protectionText == "Без презерватива · внутрь")
    #expect(entry(condom: true, finish: .didNotFinish).protectionText == "С презервативом · не кончил")
}

@Test func protectionTextWithOnePart() {
    #expect(entry(condom: true, finish: nil).protectionText == "С презервативом")
    #expect(entry(condom: false, finish: nil).protectionText == "Без презерватива")
    #expect(entry(condom: nil, finish: .outside).protectionText == "Не внутрь")
}

@Test func protectionTextEmptyWhenNotAnswered() {
    #expect(entry(condom: nil, finish: nil).protectionText == nil)
}
