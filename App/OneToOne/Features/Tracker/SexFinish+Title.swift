import Core

extension SexFinish {
    /// Подпись на чипе «Кончил».
    var title: String {
        switch self {
        case .inside: "Внутрь"
        case .outside: "Не внутрь"
        case .didNotFinish: "Не кончил"
        }
    }
}
