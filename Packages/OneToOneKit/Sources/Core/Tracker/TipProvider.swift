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
            return Tip(text: moodTexts[herMood]!, isEstimate: false)
        }
        guard let texts = phaseTexts[forecast.phase], let dayOfCycle = forecast.dayOfCycle else {
            return Tip(text: "Пусть она отметит цикл, и тут появятся подсказки", isEstimate: false)
        }
        // Выбор по дню цикла: весь день один и тот же текст, а назавтра другой.
        return Tip(text: texts[dayOfCycle % texts.count], isEstimate: true)
    }

    static let moodTexts: [HerMood: String] = [
        .leaveMeAlone: "Сегодня лучше не подходить. Серьёзно.",
        .wants: "Она сама сказала, что хочет 😏",
        .neutral: "Обычный день. Действуй по обстановке",
    ]

    static let phaseTexts: [CyclePhase: [String]] = [
        .menstruation: [
            "Месячные. Чай, плед и шоколадка — твой выход.",
            "Сейчас не до подвигов. Обнимашки — да.",
            "Тяжёлые дни. Будь мягким, как плед.",
        ],
        .follicular: [
            "Энергии всё больше. Самое время позвать её на свидание.",
            "Хорошие дни: она бодрая и весёлая. Не упусти.",
            "Настроение на подъёме. Предложи что-нибудь новенькое.",
        ],
        .ovulation: [
            "Скорее всего, она хочет. Действуй 😏",
            "Пик формы. Комплимент сработает вдвойне.",
            "Самые жаркие дни цикла. Не теряйся 🔥",
        ],
        .luteal: [
            "Терпение и вкусняшки. Она может быть чуть на взводе.",
            "Скоро месячные. Меньше споров, больше заботы.",
            "Время сюрпризов: цветы или её любимая еда.",
        ],
    ]
}
