import Core

/// Что показывает карточка вечера на вкладке «Фильмы».
enum PickCardState: Equatable {
    /// Подбора нет: «Что смотрим сегодня?».
    case noPick
    /// Подбор начал партнёр, а я в нём ещё не свайпал: «Ваша очередь».
    case partnerStarted(partnerName: String, mood: Mood)
    /// Подбор идёт: я его начал или уже свайпал.
    case inProgress(session: PickSession, matchCount: Int)

    static func make(_ data: AppData) -> PickCardState {
        guard let session = data.currentPick, let me = data.meID else { return .noPick }
        if session.startedBy != me, !data.hasSwiped(in: session, person: me), let partner = data.partner {
            return .partnerStarted(partnerName: partner.name, mood: session.mood)
        }
        return .inProgress(session: session, matchCount: data.matches(in: session).count)
    }
}
