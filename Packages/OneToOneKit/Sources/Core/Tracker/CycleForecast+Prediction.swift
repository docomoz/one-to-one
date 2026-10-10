extension CycleForecast {
    /// Прогнозные дни месячных: по 5 дней в каждых из трёх следующих месячных.
    /// Трёх хватает, чтобы листать календарь на пару месяцев вперёд.
    public var predictedPeriodDays: Set<DayKey> {
        guard let nextPeriodStart else { return [] }
        let starts = (0..<3).map { nextPeriodStart.adding(days: $0 * averageLength) }
        return Set(starts.flatMap { start in (0..<5).map { start.adding(days: $0) } })
    }
}
