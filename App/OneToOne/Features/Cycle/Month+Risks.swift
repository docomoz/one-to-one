import Core

extension Month {
    /// Риск беременности для каждого дня месяца: полоски в календаре у неё и у него.
    func risks(periodDays: Set<DayKey>, today: DayKey) -> [DayKey: PregnancyRisk] {
        let days = cells.compactMap { $0 }
        return Dictionary(uniqueKeysWithValues: days.map {
            ($0, PregnancyRiskCalculator.risk(on: $0, periodDays: periodDays, today: today))
        })
    }
}
