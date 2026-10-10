import Core

extension Month {
    /// Риск беременности на каждый день месяца — для полосок в календаре.
    func pregnancyRisks(periodDays: Set<DayKey>, today: DayKey) -> [DayKey: PregnancyRisk] {
        let days = cells.compactMap { $0 }
        return Dictionary(uniqueKeysWithValues: days.map {
            ($0, PregnancyRiskCalculator.risk(on: $0, periodDays: periodDays, today: today))
        })
    }
}
