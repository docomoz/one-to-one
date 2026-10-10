import Core
import Foundation

/// Действия фильмов: списки «хочу посмотреть».
extension AppModel {
    /// Добавляет фильм в мой список. Пока непонятно, кто «я» (знакомство не пройдено), ничего не делает.
    func addToWatchlist(_ movie: Movie) {
        guard let me = data.meID else { return }
        update { $0.addToWatchlist(movie, ownerID: me, addedAt: .now) }
    }

    func removeFromWatchlist(movieID: Int) {
        guard let me = data.meID else { return }
        update { $0.removeFromWatchlist(movieID: movieID, ownerID: me) }
    }

    func isInMyWatchlist(movieID: Int) -> Bool {
        data.watchlist.contains { $0.ownerID == data.meID && $0.movie.id == movieID }
    }
}
