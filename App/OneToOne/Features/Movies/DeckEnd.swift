import Core

/// Что показать, когда колода кончилась.
enum DeckEnd: Equatable {
    /// Есть совпадения: выбираем из них.
    case matches([Movie])
    /// Совпадений нет, но кто-то лайкнул: «Кто-то из вас лайкнул».
    case liked([Movie])
    /// Никто ничего не лайкнул: ждём партнёра или начинаем новый подбор.
    case empty(partnerName: String)

    static func make(_ data: AppData, session: PickSession) -> DeckEnd {
        let matches = data.movies(data.matches(in: session))
        if !matches.isEmpty { return .matches(matches) }
        let liked = data.movies(data.likedByAnyone(in: session))
        if !liked.isEmpty { return .liked(liked) }
        return .empty(partnerName: data.partner?.name ?? "партнёр")
    }
}
