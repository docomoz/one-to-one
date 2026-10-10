#if DEBUG
import Core

/// Только для проверки на одном телефоне: пройти подбор за обоих.
extension AppModel {
    /// Переключает «я» на другого из пары. Без пары ничего не делает.
    func switchMe() {
        guard let couple = data.couple, let me = data.meID else { return }
        let other = me == couple.man.id ? couple.woman.id : couple.man.id
        update { $0.meID = other }
    }
}
#endif
