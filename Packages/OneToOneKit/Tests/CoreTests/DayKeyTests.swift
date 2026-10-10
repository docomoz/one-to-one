import Foundation
import Testing
@testable import Core

private let moscow: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Moscow")!
    return calendar
}()

private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int) -> Date {
    moscow.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
}

@Test func dayKeyIgnoresTime() {
    let morning = DayKey(date(2026, 3, 14, 0, 1), calendar: moscow)
    let night = DayKey(date(2026, 3, 14, 23, 59), calendar: moscow)
    let nextDay = DayKey(date(2026, 3, 15, 0, 1), calendar: moscow)

    #expect(morning == night)
    #expect(night != nextDay)
    #expect(night < nextDay)
    #expect(morning == DayKey(year: 2026, month: 3, day: 14))
}

@Test func dayKeyAddingDaysCrossesMonthAndYear() {
    #expect(DayKey(year: 2026, month: 2, day: 28).adding(days: 1) == DayKey(year: 2026, month: 3, day: 1))
    #expect(DayKey(year: 2026, month: 12, day: 31).adding(days: 1) == DayKey(year: 2027, month: 1, day: 1))
    #expect(DayKey(year: 2026, month: 3, day: 1).adding(days: -1) == DayKey(year: 2026, month: 2, day: 28))
}

@Test func dayKeyOrdersByYearThenMonthThenDay() {
    #expect(DayKey(year: 2025, month: 12, day: 31) < DayKey(year: 2026, month: 1, day: 1))
    #expect(DayKey(year: 2026, month: 1, day: 31) < DayKey(year: 2026, month: 2, day: 1))
}

@Test func dayKeyAlwaysUsesGregorianYear() {
    // В настройках iPhone можно выбрать буддийский календарь: там сейчас 2569 год.
    var buddhist = Calendar(identifier: .buddhist)
    buddhist.timeZone = moscow.timeZone

    #expect(DayKey(date(2026, 3, 14, 12, 0), calendar: buddhist) == DayKey(year: 2026, month: 3, day: 14))
}
