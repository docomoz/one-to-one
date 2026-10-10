import Core
import Testing
@testable import OneToOne

private func day(_ month: Int, _ day: Int) -> DayKey {
    DayKey(year: 2026, month: month, day: day)
}

/// Начала 12 июня, 10 июля, 7 августа, 5 сентября: длины 28, 28, 29, окно 10–18 дни цикла.
private let regular: Set = [day(6, 12), day(7, 10), day(8, 7), day(9, 5)]

@Test func monthRisksCoverEveryDayOfMonth() {
    let risks = Month(year: 2026, month: 9).risks(periodDays: regular, today: day(9, 20))
    #expect(risks.count == 30)
    #expect(risks.keys.allSatisfy { $0.month == 9 })
}

@Test func monthRisksMatchCalculator() {
    let today = day(9, 20)
    let risks = Month(year: 2026, month: 9).risks(periodDays: regular, today: today)
    for (key, risk) in risks {
        #expect(risk == PregnancyRiskCalculator.risk(on: key, periodDays: regular, today: today))
    }
    #expect(risks[day(9, 14)] == .high)  // 10-й день цикла
    #expect(risks[day(9, 5)] == .low)    // 1-й день
}
