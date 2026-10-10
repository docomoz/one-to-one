/// «1 день», «2 дня», «5 дней»: число дней с правильным словом.
public func daysText(_ count: Int) -> String {
    let lastTwo = abs(count) % 100
    let last = abs(count) % 10
    let word = switch (lastTwo, last) {
    case (11...14, _): "дней"
    case (_, 1): "день"
    case (_, 2...4): "дня"
    default: "дней"
    }
    return "\(count) \(word)"
}
