/// Ближайшая годовщина пары: какая по счёту и сколько до неё дней.
public struct UpcomingAnniversary: Hashable, Sendable {
    /// Сколько лет вместе исполнится в этот день.
    public let years: Int
    /// 0 — сегодня, 1 — завтра.
    public let daysLeft: Int

    public init(years: Int, daysLeft: Int) {
        self.years = years
        self.daysLeft = daysLeft
    }
}

/// Ищет, скоро ли годовщина пары. «Сегодня» приходит снаружи, чтобы тесты не зависели от часов.
public enum AnniversaryCalculator {
    /// Ближайшая годовщина не дальше `within` дней. Без даты и в первый год знакомства — `nil`.
    public static func upcoming(since: DayKey?, today: DayKey, within: Int = 30) -> UpcomingAnniversary? {
        guard let since else { return nil }
        let thisYear = since.occurrence(in: today.year)
        let next = thisYear >= today ? thisYear : since.occurrence(in: today.year + 1)
        let years = next.year - since.year
        let daysLeft = today.days(to: next)
        guard years >= 1, daysLeft <= within else { return nil }
        return UpcomingAnniversary(years: years, daysLeft: daysLeft)
    }
}
