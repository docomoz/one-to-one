import Foundation
import Testing
@testable import Core

private let today = DayKey(year: 2026, month: 10, day: 10)

private func day(_ year: Int, _ month: Int, _ day: Int) -> DayKey {
    DayKey(year: year, month: month, day: day)
}

@Test func noDateIsNil() {
    #expect(AnniversaryCalculator.upcoming(since: nil, today: today) == nil)
}

@Test func anniversaryIn12Days() {
    #expect(AnniversaryCalculator.upcoming(since: day(2023, 10, 22), today: today)
        == UpcomingAnniversary(years: 3, daysLeft: 12))
}

@Test func anniversaryTomorrow() {
    #expect(AnniversaryCalculator.upcoming(since: day(2023, 10, 11), today: today)?.daysLeft == 1)
}

@Test func anniversaryTodayIsZero() {
    #expect(AnniversaryCalculator.upcoming(since: day(2023, 10, 10), today: today)
        == UpcomingAnniversary(years: 3, daysLeft: 0))
    #expect(AnniversaryCalculator.upcoming(since: day(2020, 12, 31), today: day(2026, 12, 31))
        == UpcomingAnniversary(years: 6, daysLeft: 0))
}

@Test func anniversaryYesterdayIsHidden() {
    #expect(AnniversaryCalculator.upcoming(since: day(2023, 10, 9), today: today) == nil)
}

@Test func anniversaryBeyondWindowIsHidden() {
    #expect(AnniversaryCalculator.upcoming(since: day(2023, 11, 10), today: today) == nil)
    #expect(AnniversaryCalculator.upcoming(since: day(2023, 11, 9), today: today)?.daysLeft == 30)
}

@Test func anniversaryAcrossNewYear() {
    #expect(AnniversaryCalculator.upcoming(since: day(2020, 1, 5), today: day(2026, 12, 20))
        == UpcomingAnniversary(years: 7, daysLeft: 16))
    // Первая годовщина тоже может прийтись на следующий год.
    #expect(AnniversaryCalculator.upcoming(since: day(2026, 1, 5), today: day(2026, 12, 20))
        == UpcomingAnniversary(years: 1, daysLeft: 16))
}

@Test func leapDayAnniversaryInCommonYear() {
    let since = day(2024, 2, 29)
    // 2027 невисокосный: годовщина 1 марта.
    #expect(AnniversaryCalculator.upcoming(since: since, today: day(2027, 2, 20))
        == UpcomingAnniversary(years: 3, daysLeft: 9))
    // 2028 високосный: 29 февраля.
    #expect(AnniversaryCalculator.upcoming(since: since, today: day(2028, 2, 20))
        == UpcomingAnniversary(years: 4, daysLeft: 9))
}

@Test func anniversaryNotInFirstYear() {
    #expect(AnniversaryCalculator.upcoming(since: day(2026, 9, 1), today: today) == nil)
    #expect(AnniversaryCalculator.upcoming(since: day(2025, 10, 20), today: today)
        == UpcomingAnniversary(years: 1, daysLeft: 10))
}

@Test func anniversarySameDayAsStartIsHidden() {
    #expect(AnniversaryCalculator.upcoming(since: day(2026, 10, 10), today: today) == nil)
}
