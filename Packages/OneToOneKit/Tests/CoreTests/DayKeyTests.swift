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

@Test func ageCountsFullYears() {
    let birth = DayKey(year: 2000, month: 5, day: 12)
    #expect(birth.age(on: DayKey(year: 2018, month: 5, day: 11)) == 17)
    #expect(birth.age(on: DayKey(year: 2018, month: 5, day: 12)) == 18)
    #expect(birth.age(on: DayKey(year: 2018, month: 12, day: 31)) == 18)
}

@Test func ageForLeapDayGrowsOnFirstOfMarch() {
    let birth = DayKey(year: 2008, month: 2, day: 29)
    #expect(birth.age(on: DayKey(year: 2026, month: 2, day: 28)) == 17)
    #expect(birth.age(on: DayKey(year: 2026, month: 3, day: 1)) == 18)
}

@Test func dayKeyDateRoundTripsInAnyCalendar() {
    let key = DayKey(year: 1996, month: 5, day: 12)
    var buddhist = Calendar(identifier: .buddhist)
    buddhist.timeZone = moscow.timeZone
    #expect(DayKey(key.date(calendar: moscow), calendar: moscow) == key)
    #expect(DayKey(key.date(calendar: buddhist), calendar: buddhist) == key)
}

@Test func dayKeyDaysToOtherDay() {
    #expect(DayKey(year: 2026, month: 2, day: 28).days(to: DayKey(year: 2026, month: 3, day: 1)) == 1)
    #expect(DayKey(year: 2026, month: 12, day: 31).days(to: DayKey(year: 2027, month: 1, day: 1)) == 1)
    #expect(DayKey(year: 2026, month: 10, day: 10).days(to: DayKey(year: 2026, month: 10, day: 1)) == -9)
}

@Test func dayKeyRoundTripsThroughDate() {
    // Нью-Йорк: 8 марта 2026 переход на летнее время, полночи в этот день может «не быть».
    var newYork = Calendar(identifier: .gregorian)
    newYork.timeZone = TimeZone(identifier: "America/New_York")!

    for key in [DayKey(year: 2026, month: 3, day: 8), DayKey(year: 2026, month: 12, day: 31)] {
        #expect(DayKey(key.date(in: newYork), calendar: newYork) == key)
        #expect(DayKey(key.date(in: moscow), calendar: moscow) == key)
    }
}
