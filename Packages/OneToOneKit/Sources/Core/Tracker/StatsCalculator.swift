import Foundation

/// Считает статистику по записям. «Сегодня» и календарь приходят снаружи, чтобы тесты не зависели от часов.
public enum StatsCalculator {
    public static func stats(_ entries: [SexEntry], today: DayKey, calendar: Calendar) -> Stats {
        let days = entries.map { DayKey($0.date, calendar: calendar) }
        let uniqueDays = Set(days)
        var typeCounts = Dictionary(uniqueKeysWithValues: SexType.allCases.map { ($0, 0) })
        for entry in entries {
            for type in entry.types { typeCounts[type, default: 0] += 1 }
        }
        return Stats(
            total: entries.count,
            thisMonth: days.filter { $0.year == today.year && $0.month == today.month }.count,
            orgasmsMan: entries.reduce(0) { $0 + $1.orgasmsMan },
            orgasmsWoman: entries.reduce(0) { $0 + $1.orgasmsWoman },
            typeCounts: typeCounts,
            currentStreak: currentStreak(uniqueDays, today: today),
            bestStreak: bestStreak(uniqueDays)
        )
    }

    /// Серия, которая заканчивается сегодня или вчера: вчерашняя ещё не прервалась.
    private static func currentStreak(_ days: Set<DayKey>, today: DayKey) -> Int {
        var day = days.contains(today) ? today : today.adding(days: -1)
        var streak = 0
        while days.contains(day) {
            streak += 1
            day = day.adding(days: -1)
        }
        return streak
    }

    /// Самая длинная цепочка дней подряд. Два раза в один день — один день серии.
    private static func bestStreak(_ days: Set<DayKey>) -> Int {
        var best = 0
        var streak = 0
        var previous: DayKey?
        for day in days.sorted() {
            streak = previous?.adding(days: 1) == day ? streak + 1 : 1
            best = max(best, streak)
            previous = day
        }
        return best
    }
}
