import Core

extension SexType {
    /// Подпись на кнопках и в списке записей.
    var title: String {
        switch self {
        case .vaginal: "Классика"
        case .anal: "Анал"
        case .cunnilingus: "Куни"
        case .blowjob: "Минет"
        }
    }
}
