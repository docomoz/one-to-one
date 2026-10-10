import Foundation
import Testing
@testable import Core

private let october10 = DayKey(year: 2026, month: 10, day: 10)

private func entry(_ month: Int, _ day: Int, types: Set<SexType> = [.vaginal],
                   man: Int = 1, woman: Int = 1) -> SexEntry {
    SexEntry(day: DayKey(year: 2026, month: month, day: day), types: types,
             orgasmsMan: man, orgasmsWoman: woman, createdBy: UUID())
}

private func stats(_ entries: [SexEntry], today: DayKey = october10) -> Stats {
    StatsCalculator.stats(entries, today: today)
}

@Test func emptyStats() {
    let result = stats([])

    #expect(result.total == 0)
    #expect(result.thisMonth == 0)
    #expect(result.orgasmsMan == 0)
    #expect(result.orgasmsWoman == 0)
    #expect(result.typeCounts.values.allSatisfy { $0 == 0 })
    #expect(result.currentStreak == 0)
    #expect(result.bestStreak == 0)
}

@Test func countsTotalAndMonth() {
    let result = stats([entry(10, 1), entry(10, 5), entry(10, 10), entry(9, 30)])

    #expect(result.total == 4)
    #expect(result.thisMonth == 3)
}

@Test func twoEntriesSameDayCountTwice() {
    let result = stats([entry(10, 9), entry(10, 9)])

    #expect(result.total == 2)
    #expect(result.thisMonth == 2)
}

@Test func sumsOrgasms() {
    let result = stats([entry(10, 1, man: 2, woman: 1), entry(10, 2, man: 1, woman: 0)])

    #expect(result.orgasmsMan == 3)
    #expect(result.orgasmsWoman == 1)
}

@Test func countsTypes() {
    let result = stats([entry(10, 1, types: [.anal, .blowjob]), entry(10, 2, types: [.blowjob])])

    #expect(result.typeCounts[.anal] == 1)
    #expect(result.typeCounts[.blowjob] == 2)
    #expect(result.typeCounts[.vaginal] == 0)
    #expect(result.typeCounts[.cunnilingus] == 0)
}

@Test func twoEntriesSameDayIsOneStreakDay() {
    let result = stats([entry(10, 8), entry(10, 9), entry(10, 9), entry(10, 10)])

    #expect(result.currentStreak == 3)
    #expect(result.bestStreak == 3)
}

@Test func streakBrokenByGap() {
    let result = stats([entry(10, 5), entry(10, 6), entry(10, 8)], today: DayKey(year: 2026, month: 10, day: 8))

    #expect(result.currentStreak == 1)
    #expect(result.bestStreak == 2)
}

@Test func streakAliveIfYesterday() {
    #expect(stats([entry(10, 8), entry(10, 9)]).currentStreak == 2)
    #expect(stats([entry(10, 7), entry(10, 8)]).currentStreak == 0)
}

@Test func streakCrossesMonthBoundary() {
    let result = stats([entry(9, 30), entry(10, 1)], today: DayKey(year: 2026, month: 10, day: 1))

    #expect(result.currentStreak == 2)
}

@Test func streakIgnoresEntryOrder() {
    #expect(stats([entry(10, 10), entry(10, 8), entry(10, 9)]).currentStreak == 3)
}
