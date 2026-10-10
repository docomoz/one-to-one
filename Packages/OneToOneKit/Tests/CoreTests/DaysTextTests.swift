import Testing
@testable import Core

@Test func daysPlural() {
    #expect(daysText(0) == "0 дней")
    #expect(daysText(1) == "1 день")
    #expect(daysText(2) == "2 дня")
    #expect(daysText(5) == "5 дней")
    #expect(daysText(11) == "11 дней")
    #expect(daysText(14) == "14 дней")
    #expect(daysText(21) == "21 день")
    #expect(daysText(22) == "22 дня")
    #expect(daysText(25) == "25 дней")
}
