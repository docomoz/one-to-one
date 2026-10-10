import Core
import Foundation

extension AppModel {
    /// Создаёт пару из знакомства и запоминает, что этот телефон — `me`.
    /// При ошибке данные не меняются.
    func createCouple(me: PersonDraft, partner: PersonDraft, today: DayKey = DayKey(.now)) throws(OnboardingError) {
        let couple = try Couple.make(me: me, partner: partner, today: today)
        update {
            $0.couple = couple
            $0.meID = me.id
        }
    }
}
