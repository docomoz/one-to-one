/// «1 день», «2 дня», «5 дней»: число дней с правильным словом.
public func daysText(_ count: Int) -> String {
    "\(count) \(pluralWord(count, one: "день", few: "дня", many: "дней"))"
}

/// «1 год», «2 года», «5 лет»: число лет с правильным словом.
public func yearsText(_ count: Int) -> String {
    "\(count) \(pluralWord(count, one: "год", few: "года", many: "лет"))"
}

/// Выбирает форму слова по числу: 1, 2–4, 5–20 (11–14 всегда «много»).
private func pluralWord(_ count: Int, one: String, few: String, many: String) -> String {
    let lastTwo = abs(count) % 100
    let last = abs(count) % 10
    return switch (lastTwo, last) {
    case (11...14, _): many
    case (_, 1): one
    case (_, 2...4): few
    default: many
    }
}
