import Foundation

/// Отметки дня, которые ставит она: месячные, «как я сегодня», симптомы.
extension AppData {
    /// Ставит или снимает отметку месячных. Если между этим днём и отмеченным соседним
    /// пропущен ровно один день (до или после), отмечает и его: скорее всего, его просто забыли.
    public mutating func togglePeriodDay(_ day: DayKey) {
        if periodDays.remove(day) != nil { return }
        periodDays.insert(day)
        for direction in [-1, 1] {
            let skipped = day.adding(days: direction)
            if !periodDays.contains(skipped), periodDays.contains(day.adding(days: 2 * direction)) {
                periodDays.insert(skipped)
            }
        }
    }

    /// `nil` снимает отметку.
    public mutating func setHerMood(_ mood: HerMood?, for day: DayKey) {
        herMoods[day] = mood
    }

    /// Ставит симптом или снимает, если он уже стоит.
    public mutating func toggleSymptom(_ symptom: Symptom, on day: DayKey) {
        var daySymptoms = symptoms[day, default: []]
        if daySymptoms.remove(symptom) == nil {
            daySymptoms.insert(symptom)
        }
        symptoms[day] = daySymptoms.isEmpty ? nil : daySymptoms
    }

    /// Добавляет свой симптом текстом и никогда не снимает. Пустой текст не сохраняется,
    /// а название готового симптома («болит голова») ставит готовый, чтобы не было двойников.
    public mutating func addCustomSymptom(_ text: String, on day: DayKey) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let preset = PresetSymptom.allCases.first { $0.title.lowercased() == trimmed.lowercased() }
        symptoms[day, default: []].insert(preset.map(Symptom.preset) ?? .custom(trimmed))
    }

    /// Свои симптомы, которые она уже когда-то ставила, по алфавиту.
    public var customSymptoms: [String] {
        let texts = symptoms.values.flatMap { $0 }.compactMap { symptom -> String? in
            if case .custom(let text) = symptom { text } else { nil }
        }
        return Set(texts).sorted()
    }
}
