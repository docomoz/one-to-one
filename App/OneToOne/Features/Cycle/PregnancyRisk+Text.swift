import Core
import SwiftUI

extension PregnancyRisk {
    /// Заголовок плашки «Сегодня». Низкий риск всегда «но не ноль».
    var title: String {
        switch self {
        case .high: "Высокий риск забеременеть"
        case .medium, .late: "Средний риск"
        case .low: "Низкий риск, но не ноль"
        case .unknown: "Риск неизвестен"
        }
    }

    /// Строка под заголовком плашки.
    var detail: String {
        switch self {
        case .high: "Близко к овуляции: за один раз без защиты шанс до 1 из 3. Надевай презерватив"
        case .medium: "Прогноз тут не уверен. Лучше с презервативом"
        case .late: "Месячные задерживаются, прогноз ненадёжен. Лучше с презервативом"
        case .low: "Если прогноз верный, шанс небольшой. Но овуляция может сдвинуться"
        case .unknown: "Отметьте месячные во вкладке „Цикл“. Пока лучше с презервативом"
        }
    }

    /// «Риск беременности: высокий» в карточке выбранного дня.
    var shortTitle: String {
        switch self {
        case .high: "высокий"
        case .medium: "средний"
        case .late: "средний, задержка"
        case .low: "низкий"
        case .unknown: "неизвестен"
        }
    }

    /// Точка на плашке. Системные цвета сами подстраиваются под тёмную тему.
    var dotColor: Color {
        markColor ?? (self == .low ? .green : .gray)
    }

    /// Полоска дня в календаре. У низкого и неизвестного её нет:
    /// зелёный день выглядел бы разрешением.
    var markColor: Color? {
        switch self {
        case .high: .red
        case .medium, .late: .orange
        case .low, .unknown: nil
        }
    }

    /// Добавка к подписи дня для VoiceOver, только когда у дня есть полоска.
    var dayAccessibility: String? {
        switch self {
        case .high: "высокий риск беременности"
        case .medium, .late: "средний риск беременности"
        case .low, .unknown: nil
        }
    }
}
