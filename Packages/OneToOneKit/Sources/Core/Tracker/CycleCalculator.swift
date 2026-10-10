import Foundation

/// Фаза цикла на конкретный день.
public enum CyclePhase: Equatable, Sendable {
    case menstruation, follicular, ovulation, luteal, unknown
}

/// Что известно о цикле на сегодня.
public struct CycleForecast: Equatable, Sendable {
    public let phase: CyclePhase
    /// День цикла, начиная с 1. `nil`, если отметок нет.
    public let dayOfCycle: Int?
    /// Средняя длина цикла в днях.
    public let averageLength: Int
    /// Когда ждать следующие месячные. `nil`, если отметок нет.
    public let nextPeriodStart: DayKey?

    public init(phase: CyclePhase, dayOfCycle: Int?, averageLength: Int, nextPeriodStart: DayKey?) {
        self.phase = phase
        self.dayOfCycle = dayOfCycle
        self.averageLength = averageLength
        self.nextPeriodStart = nextPeriodStart
    }
}

/// Считает фазу, день цикла и прогноз по отмеченным дням месячных.
public enum CycleCalculator {
    static let defaultLength = 28
    static let lengthRange = 21...40

    public static func forecast(periodDays: Set<DayKey>, today: DayKey) -> CycleForecast {
        // Отметки позже сегодня не учитываем: будущее ещё не случилось.
        let starts = periodStarts(periodDays.filter { $0 <= today })
        guard let lastStart = starts.last else {
            return CycleForecast(phase: .unknown, dayOfCycle: nil, averageLength: defaultLength, nextPeriodStart: nil)
        }
        let length = averageLength(starts)
        let dayOfCycle = days(from: lastStart, to: today) % length + 1
        let next = today.adding(days: length - dayOfCycle + 1)
        let phase = periodDays.contains(today) ? .menstruation : phase(dayOfCycle: dayOfCycle, length: length)
        return CycleForecast(phase: phase, dayOfCycle: dayOfCycle, averageLength: length, nextPeriodStart: next)
    }

    /// Фаза по дню цикла: 1–5 месячные, (L−16)…(L−12) овуляция, до неё фолликулярная, после лютеиновая.
    static func phase(dayOfCycle: Int, length: Int) -> CyclePhase {
        let ovulation = (length - 16)...(length - 12)
        if dayOfCycle <= 5 { return .menstruation }
        if ovulation.contains(dayOfCycle) { return .ovulation }
        return dayOfCycle < ovulation.lowerBound ? .follicular : .luteal
    }

    /// Среднее между соседними началами, ограничено 21–40. Если начал меньше двух, 28.
    static func averageLength(_ starts: [DayKey]) -> Int {
        guard let first = starts.first, let last = starts.last, starts.count > 1 else { return defaultLength }
        let average = Double(days(from: first, to: last)) / Double(starts.count - 1)
        return min(max(Int(average.rounded()), lengthRange.lowerBound), lengthRange.upperBound)
    }

    /// Начало месячных — отмеченный день, перед которым день не отмечен. По возрастанию.
    static func periodStarts(_ periodDays: Set<DayKey>) -> [DayKey] {
        periodDays.filter { !periodDays.contains($0.adding(days: -1)) }.sorted()
    }

    /// Сколько дней от `start` до `end`.
    static func days(from start: DayKey, to end: DayKey) -> Int {
        let a = utc.date(from: DateComponents(year: start.year, month: start.month, day: start.day))!
        let b = utc.date(from: DateComponents(year: end.year, month: end.month, day: end.day))!
        return utc.dateComponents([.day], from: a, to: b).day!
    }

    // В UTC нет перехода на летнее время, сутки всегда ровно 24 часа.
    private static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()
}
