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

    /// День, на который приходится момент `date` по местному календарю.
    public init(_ date: Date, calendar: Calendar = .current) {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: parts.year!, month: parts.month!, day: parts.day!)
    }

    /// День через `days` дней (отрицательное число — назад).
    public func adding(days: Int) -> DayKey {
        // Считаем в UTC: там нет перехода на летнее время, сутки всегда ровно 24 часа.
        let start = Self.utc.date(from: DateComponents(year: year, month: month, day: day))!
        let shifted = Self.utc.date(byAdding: .day, value: days, to: start)!
        return DayKey(shifted, calendar: Self.utc)
    }

    public static func < (lhs: DayKey, rhs: DayKey) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    private static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()
}
