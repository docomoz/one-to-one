import Core
import DesignSystem
import SwiftUI

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

extension CyclePhase {
    /// Подпись в легенде календаря.
    var shortTitle: String {
        switch self {
        case .menstruation: "Месячные"
        case .follicular: "Фолликулярная"
        case .ovulation: "Овуляция"
        case .luteal: "Лютеиновая"
        case .unknown: "Неизвестно"
        }
    }

    /// Цвет фазы в календаре. У неизвестной фазы цвета нет.
    var color: Color? {
        switch self {
        case .menstruation: BrandColor.pink.color
        case .follicular: BrandColor.orange.color
        case .ovulation: BrandColor.purple.color
        case .luteal: BrandColor.blue.color
        case .unknown: nil
        }
    }

    /// Мягкая заливка дня в календаре и в легенде. На тёмном фоне ярче, иначе фазы не различить.
    func tint(_ scheme: ColorScheme) -> Color? {
        color?.opacity(scheme == .dark ? 0.5 : 0.22)
    }
}
