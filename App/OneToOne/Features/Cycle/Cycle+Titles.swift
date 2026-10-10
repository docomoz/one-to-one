import Core

extension CyclePhase {
    /// «Сегодня: фолликулярная фаза».
    var title: String {
        switch self {
        case .menstruation: "месячные"
        case .follicular: "фолликулярная фаза"
        case .ovulation: "овуляция"
        case .luteal: "лютеиновая фаза"
        case .unknown: "фаза неизвестна"
        }
    }
}

extension HerMood {
    /// Подпись на кнопках «как я сегодня».
    var title: String {
        switch self {
        case .wants: "Хочу"
        case .neutral: "Обычно"
        case .leaveMeAlone: "Не трогать"
        }
    }
}
