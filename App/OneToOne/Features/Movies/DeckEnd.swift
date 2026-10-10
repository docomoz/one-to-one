import Core

/// Что показать, когда колода кончилась.
enum DeckEnd: Equatable {
    /// Есть совпадения: выбираем из них.
    case matches([Movie])
    /// Совпадений нет, но кто-то лайкнул: «Кто-то из вас лайкнул».
    case liked([Movie])
    /// Никто ещё ничего не свайпнул, а колода пустая: свайпать нечего (пустые списки и нет сети).
    case noMovies
    /// Партнёр ещё не свайпал: ждём его.
    case waitForPartner(partnerName: String)
    /// Оба свайпали, но ♥ никто не поставил: пора новый подбор.
    case nothingLiked

    static func make(_ data: AppData, session: PickSession) -> DeckEnd {
        let matches = data.movies(data.matches(in: session))
        if !matches.isEmpty { return .matches(matches) }
        let liked = data.movies(data.likedByAnyone(in: session))
        if !liked.isEmpty { return .liked(liked) }
        guard let couple = data.couple,
              data.hasSwiped(in: session, person: couple.man.id) || data.hasSwiped(in: session, person: couple.woman.id)
        else { return .noMovies }
        if let partner = data.partner, !data.hasSwiped(in: session, person: partner.id) {
            return .waitForPartner(partnerName: partner.name)
        }
        return .nothingLiked
    }
}
