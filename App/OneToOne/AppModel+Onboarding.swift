import Core
import Foundation
import Sync

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

    /// Есть ли на телефоне записи, которые пропадут при входе в пару партнёра.
    var hasSyncedRecords: Bool {
        // Без кодирования в JSON: стираем синхронизируемые поля и сравниваем.
        SyncRecordMapper.apply([:], to: data) != data
    }

    /// Вошли в пару партнёра по коду: свои записи и «кто я» стираются, их место займут записи пары
    /// с первой синхронизацией. Кэш фильмов остаётся. Партнёру это не отправляется: синхронизация к этому
    /// моменту остановлена, а новая пара о стёртых записях не знала.
    func replaceWithJoinedCouple() {
        clearSyncedData()
    }

    /// Вошедший по коду выбирает себя в паре: человек, которого вписал партнёр. Имя и дату рождения можно поправить,
    /// пол — нет (по нему строится вся пара). Правка уходит партнёру.
    func claimPerson(_ draft: PersonDraft, today: DayKey = DayKey(.now)) throws(OnboardingError) {
        guard let couple = data.couple,
              let placeholder = [couple.man, couple.woman].first(where: { $0.id == draft.id })
        else { return }
        let other = placeholder.id == couple.man.id ? couple.woman : couple.man
        var draft = draft
        draft.sex = placeholder.sex
        let me = try draft.validated(today: today)
        let updated: Couple
        do {
            updated = try Couple.make(me, other)
        } catch {
            switch error {
            case .sameSex: throw .sameSex
            }
        }
        update {
            $0.couple = updated
            $0.meID = me.id
        }
    }
}
