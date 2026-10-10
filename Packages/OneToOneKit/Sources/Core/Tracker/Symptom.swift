/// Готовый симптом из списка.
public enum PresetSymptom: String, Codable, CaseIterable, Sendable {
    case headache, cramps, breastPain, backPain, bloating, nausea, fatigue, acne, moodSwings, badSleep

    public var title: String {
        switch self {
        case .headache: "Болит голова"
        case .cramps: "Тянет живот"
        case .breastPain: "Болит грудь"
        case .backPain: "Болит спина"
        case .bloating: "Вздутие"
        case .nausea: "Тошнота"
        case .fatigue: "Усталость"
        case .acne: "Высыпания"
        case .moodSwings: "Перепады настроения"
        case .badSleep: "Плохой сон"
        }
    }
}

/// Симптом дня: готовый из списка или свой, написанный текстом.
public enum Symptom: Codable, Hashable, Sendable {
    case preset(PresetSymptom)
    case custom(String)

    public var title: String {
        switch self {
        case .preset(let preset): preset.title
        case .custom(let text): text
        }
    }
}
