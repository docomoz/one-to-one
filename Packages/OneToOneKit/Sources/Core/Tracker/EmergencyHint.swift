/// Подсказка про экстренную таблетку после секса без защиты.
public enum EmergencyHint: Equatable, Sendable {
    /// Кончил внутрь.
    case strong
    /// Снаружи, не кончил или не ответили: риск всё равно есть.
    case soft

    /// Таблетка работает до 5 дней после секса, позже подсказка бесполезна.
    static let daysToAct = 0...5

    /// Подсказка для записи секса в день `day`. Риск считаем на день записи, а не на сегодня:
    /// отметить можно и задним числом.
    public static func hint(types: Set<SexType>, condom: Bool?, finish: SexFinish?,
                            day: DayKey, periodDays: Set<DayKey>, today: DayKey) -> EmergencyHint? {
        guard types.contains(.vaginal), condom == false, daysToAct.contains(day.days(to: today)) else { return nil }
        if PregnancyRiskCalculator.risk(on: day, periodDays: periodDays, today: today) == .low { return nil }
        return finish == .inside ? .strong : .soft
    }
}
