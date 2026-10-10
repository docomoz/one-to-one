/// Подбадривающая фраза для неё на главной, под фазу цикла.
public enum CheerProvider {
    /// Весь день одна и та же фраза, назавтра другая. Если фаза неизвестна, фразы нет.
    public static func cheer(forecast: CycleForecast) -> String? {
        guard let texts = texts(for: forecast.phase), let dayOfCycle = forecast.dayOfCycle else { return nil }
        return texts[dayOfCycle % texts.count]
    }

    /// По 3 фразы на фазу. `switch`, чтобы новая фаза не собралась без своих фраз.
    static func texts(for phase: CyclePhase) -> [String]? {
        switch phase {
        case .menstruation: [
            "Береги себя. Плед и сериал — уважительная причина.",
            "Ты справляешься. Можно попросить чай в постель ☕️",
            "Тяжёлые дни пройдут. Ты всё равно лучшая.",
        ]
        case .follicular: [
            "Энергии всё больше. Самое время для новых планов ✨",
            "Ты сегодня в ударе. Пользуйся!",
            "Лёгкость и настроение на подъёме. Красотка 💫",
        ]
        case .ovulation: [
            "Ты сегодня огонь 🔥",
            "Пик формы. Пусть все любуются.",
            "Сияешь. Он точно заметит 😏",
        ]
        case .luteal: [
            "Можно чуть больше вкусного и чуть меньше дел.",
            "Если всё бесит, это нормально. Ты молодец.",
            "Скоро новый цикл. Побалуй себя сегодня 💜",
        ]
        case .unknown: nil
        }
    }
}
