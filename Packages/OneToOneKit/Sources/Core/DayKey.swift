import Foundation

/// Календарный день без времени и часового пояса: «14 марта 2026».
/// Дни (месячные, серии, «сегодня») считаем через него, а не через `Date`.
public struct DayKey: Codable, Hashable, Comparable, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// День, на который приходится момент `date` в часовом поясе `calendar`.
    /// Год и месяц всегда григорианские, даже если в настройках iPhone выбран другой календарь.
    public init(_ date: Date, calendar: Calendar = .current) {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        let parts = gregorian.dateComponents([.year, .month, .day], from: date)
        self.init(year: parts.year!, month: parts.month!, day: parts.day!)
    }

    /// День через `days` дней (отрицательное число — назад).
    public func adding(days: Int) -> DayKey {
        // Считаем в UTC: там нет перехода на летнее время, сутки всегда ровно 24 часа.
        let shifted = Self.utc.date(byAdding: .day, value: days, to: utcDate)!
        return DayKey(shifted, calendar: Self.utc)
    }

    /// Сколько дней от этого дня до `other` (отрицательное число, если `other` раньше).
    public func days(to other: DayKey) -> Int {
        Self.utc.dateComponents([.day], from: utcDate, to: other.utcDate).day!
    }

    public static func < (lhs: DayKey, rhs: DayKey) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    private var utcDate: Date {
        Self.utc.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()
}
