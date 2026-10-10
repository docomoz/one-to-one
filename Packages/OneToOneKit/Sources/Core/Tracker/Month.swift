import Foundation

/// Месяц для сетки календаря. Неделя начинается с понедельника.
public struct Month: Hashable, Sendable {
    public let year: Int
    public let month: Int

    public init(year: Int, month: Int) {
        self.year = year
        self.month = month
    }

    public init(_ day: DayKey) {
        self.init(year: day.year, month: day.month)
    }

    public func adding(months: Int) -> Month {
        let index = year * 12 + (month - 1) + months
        return Month(year: index / 12, month: index % 12 + 1)
    }

    /// Клетки сетки: сначала пустые (`nil`) до первого понедельника, потом все дни месяца.
    public var cells: [DayKey?] {
        let first = Self.calendar.date(from: DateComponents(year: year, month: month, day: 1))!
        let dayCount = Self.calendar.range(of: .day, in: .month, for: first)!.count
        // weekday: 1 — воскресенье, 2 — понедельник… Переводим в 0 — понедельник.
        let leading = (Self.calendar.component(.weekday, from: first) + 5) % 7
        let days = (1...dayCount).map { DayKey(year: year, month: month, day: $0) }
        return Array(repeating: nil, count: leading) + days
    }

    /// «Октябрь 2026».
    public var title: String {
        "\(Self.names[month - 1]) \(year)"
    }

    private static let names = ["Январь", "Февраль", "Март", "Апрель", "Май", "Июнь",
                                "Июль", "Август", "Сентябрь", "Октябрь", "Ноябрь", "Декабрь"]

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()
}
