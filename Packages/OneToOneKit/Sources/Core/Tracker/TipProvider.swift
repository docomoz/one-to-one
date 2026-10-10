/// Подсказка дня для него.
public struct Tip: Equatable, Sendable {
    public let text: String
    /// `true`, если подсказка угадана по фазе цикла, а не сказана ею самой.
    public let isEstimate: Bool

    public init(text: String, isEstimate: Bool) {
        self.text = text
        self.isEstimate = isEstimate
    }
}

/// Выбирает подсказку дня: её «как я сегодня» главнее фазы.
public enum TipProvider {
    public static func tip(forecast: CycleForecast, herMood: HerMood?) -> Tip {
        if let herMood {
            return Tip(text: text(for: herMood), isEstimate: false)
        }
        guard let texts = texts(for: forecast.phase), let dayOfCycle = forecast.dayOfCycle else {
            return Tip(text: "Пусть она отметит цикл, и тут появятся подсказки", isEstimate: false)
        }
        // Выбор по дню цикла: весь день один и тот же текст, а назавтра другой.
        return Tip(text: texts[dayOfCycle % texts.count], isEstimate: true)
    }

    // `switch`, а не словарь: новое настроение или фаза не соберутся без своего текста.
    static func text(for mood: HerMood) -> String {
        switch mood {
        case .leaveMeAlone: "Сегодня лучше не подходить. Серьёзно."
        case .wants: "Она сама сказала, что хочет 😏"
        case .neutral: "Обычный день. Действуй по обстановке"
        }
    }

    /// По 3 текста на фазу. У неизвестной фазы текстов нет.
    static func texts(for phase: CyclePhase) -> [String]? {
        switch phase {
        case .menstruation: [
            "Месячные. Чай, плед и шоколадка — твой выход.",
            "Сейчас не до подвигов. Обнимашки — да.",
            "Тяжёлые дни. Будь мягким, как плед.",
        ]
        case .follicular: [
            "Энергии всё больше. Самое время позвать её на свидание.",
            "Хорошие дни: она бодрая и весёлая. Не упусти.",
            "Настроение на подъёме. Предложи что-нибудь новенькое.",
        ]
        case .ovulation: [
            "Скорее всего, она хочет. Действуй 😏",
            "Пик формы. Комплимент сработает вдвойне.",
            "Самые жаркие дни цикла. Не теряйся 🔥",
        ]
        case .luteal: [
            "Терпение и вкусняшки. Она может быть чуть на взводе.",
            "Скоро месячные. Меньше споров, больше заботы.",
            "Время сюрпризов: цветы или её любимая еда.",
        ]
        case .unknown: nil
        }
    }
}
