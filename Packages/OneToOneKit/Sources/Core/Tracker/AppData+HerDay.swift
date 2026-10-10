/// Отметки дня, которые ставит она: месячные, «как я сегодня», симптомы.
extension AppData {
    /// Ставит или снимает отметку месячных. Если между отмеченным днём и этим пропущен
    /// ровно один день, отмечает и его: скорее всего, его просто забыли.
    public mutating func togglePeriodDay(_ day: DayKey) {
        if periodDays.remove(day) != nil { return }
        periodDays.insert(day)
        let skipped = day.adding(days: -1)
        if !periodDays.contains(skipped), periodDays.contains(day.adding(days: -2)) {
            periodDays.insert(skipped)
        }
    }

    /// `nil` снимает отметку.
    public mutating func setHerMood(_ mood: HerMood?, for day: DayKey) {
        herMoods[day] = mood
    }

    /// Ставит симптом или снимает, если он уже стоит. Пустой свой текст не сохраняется.
    public mutating func toggleSymptom(_ symptom: Symptom, on day: DayKey) {
        var symptom = symptom
        if case .custom(let text) = symptom {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            symptom = .custom(trimmed)
        }
        var daySymptoms = symptoms[day, default: []]
        if daySymptoms.remove(symptom) == nil {
            daySymptoms.insert(symptom)
        }
        symptoms[day] = daySymptoms.isEmpty ? nil : daySymptoms
    }

    /// Свои симптомы, которые она уже когда-то ставила, по алфавиту.
    public var customSymptoms: [String] {
        let texts = symptoms.values.flatMap { $0 }.compactMap { symptom -> String? in
            if case .custom(let text) = symptom { text } else { nil }
        }
        return Set(texts).sorted()
    }
}
