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

    /// Готовый симптом с незнакомым именем (его переименовали или убрали) читаем как свой,
    /// иначе из-за одного симптома не прочитается весь файл данных.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let text = try? container.nestedContainer(keyedBy: ValueKeys.self, forKey: .custom).decode(String.self, forKey: ._0) {
            self = .custom(text)
            return
        }
        let raw = try container.nestedContainer(keyedBy: ValueKeys.self, forKey: .preset).decode(String.self, forKey: ._0)
        self = PresetSymptom(rawValue: raw).map(Symptom.preset) ?? .custom(raw)
    }

    private enum CodingKeys: String, CodingKey { case preset, custom }
    private enum ValueKeys: String, CodingKey { case _0 }
}
