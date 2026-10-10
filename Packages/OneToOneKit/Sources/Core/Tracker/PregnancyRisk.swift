/// Риск забеременеть в день без защиты. «Безопасного» уровня нет: низкий — тоже не ноль.
public enum PregnancyRisk: Equatable, Sendable {
    /// Окно вокруг прогнозной овуляции.
    case high
    /// Края окна или прогноз не уверен (мало циклов, цикл скачет).
    case medium
    /// Средний риск: месячные задерживаются, прогноз ненадёжен.
    case late
    /// Вне окна при регулярном цикле. Но не ноль.
    case low
    /// Месячные не отмечены.
    case unknown
}

/// Считает риск календарным методом (Огино–Кнаус) по отметкам месячных.
public enum PregnancyRiskCalculator {
    /// Сколько циклов нужно, чтобы доверять самому короткому и самому длинному.
    static let enoughCycles = 3
    /// Больше разброс длин — цикл скачет, низкий риск не показываем.
    static let maxSpread = 10
    /// Берём только последние циклы: старые хуже говорят о нынешнем.
    static let recentCycles = 6
    /// Средний риск по краям окна.
    static let margin = 2
    /// Пока циклов мало — метод стандартных дней для циклов 26–32.
    static let fallbackWindow = 8...19
    static let fallbackLongest = 32

    /// Риск на день `day`. Учитываем только отметки до `day` и не позже `today`:
    /// прошлый день судим по тому, что знали тогда, а будущих месячных ещё не было.
    public static func risk(on day: DayKey, periodDays: Set<DayKey>, today: DayKey) -> PregnancyRisk {
        let known = min(day, today)
        let starts = CycleCalculator.periodStarts(periodDays.filter { $0 <= known })
        guard let lastStart = starts.last else { return .unknown }

        let lengths = cycleLengths(starts)
        let isEnough = lengths.count >= enoughCycles
        let shortest = lengths.min() ?? 0
        let longest = isEnough ? lengths.max() ?? 0 : fallbackLongest
        let window = isEnough ? (shortest - 18)...(longest - 11) : fallbackWindow
        let allowsLow = isEnough && longest - shortest <= maxSpread

        let elapsed = lastStart.days(to: day)
        let dayOfCycle: Int
        if day <= today {
            // Без заворота по длине: иначе задержку не увидеть.
            dayOfCycle = elapsed + 1
            if dayOfCycle > longest { return .late }
        } else {
            // Будущие циклы идут по прогнозу, как в `CycleCalculator.forecast`.
            dayOfCycle = elapsed % CycleCalculator.averageLength(starts) + 1
        }

        if window.contains(dayOfCycle) { return .high }
        let edges = (window.lowerBound - margin)...(window.upperBound + margin)
        if edges.contains(dayOfCycle) || !allowsLow { return .medium }
        return .low
    }

    /// Промежутки между соседними началами, только 21–40 дней (длиннее — видимо, забыли отметить), последние 6.
    static func cycleLengths(_ starts: [DayKey]) -> [Int] {
        let lengths = zip(starts, starts.dropFirst()).map { $0.days(to: $1) }
        return Array(lengths.filter(CycleCalculator.lengthRange.contains).suffix(recentCycles))
    }
}
