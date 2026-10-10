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

    /// Полдень этого дня в часовом поясе `calendar`: для системного выбора даты.
    /// Полдень, а не полночь, чтобы переход на летнее время не сдвинул день.
    public func date(calendar: Calendar = .current) -> Date {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        return gregorian.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    /// День через `days` дней (отрицательное число — назад).
    public func adding(days: Int) -> DayKey {
        // Считаем в UTC: там нет перехода на летнее время, сутки всегда ровно 24 часа.
        let shifted = Self.utc.date(byAdding: .day, value: days, to: utcDate)!
        return DayKey(shifted, calendar: Self.utc)
    }

    /// Сколько полных лет исполнилось к дню `today`, если родился в этот день.
    /// Родившимся 29 февраля в невисокосный год год добавляется 1 марта.
    public func age(on today: DayKey) -> Int {
        let years = today.year - year
        return (today.month, today.day) < (month, day) ? years - 1 : years
    }

    /// Сколько дней от этого дня до `other` (отрицательное число, если `other` раньше).
    public func days(to other: DayKey) -> Int {
        Self.utc.dateComponents([.day], from: utcDate, to: other.utcDate).day!
    }

    /// Полдень этого дня в часовом поясе `calendar`: для выбора даты на экране.
    /// Полдень, а не полночь, потому что в день перевода часов полуночи может не быть.
    public func date(in calendar: Calendar = .current) -> Date {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        return gregorian.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
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
