import Foundation

extension DayKey {
    /// Тот же месяц и число в году `year`: для дней рождения и годовщин.
    /// 29 февраля в невисокосный год — 1 марта, как в `age(on:)`.
    public func occurrence(in year: Int) -> DayKey {
        if month == 2, day == 29, !Self.isLeap(year) {
            return DayKey(year: year, month: 3, day: 1)
        }
        return DayKey(year: year, month: month, day: day)
    }

    private static func isLeap(_ year: Int) -> Bool {
        (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
    }
}
