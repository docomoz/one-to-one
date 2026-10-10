import Foundation

/// Ищет совпадения: фильмы, которым оба из пары поставили ♥.
public enum MatchFinder {
    /// Фильмы, где у обоих последний свайп ♥, в порядке, в котором случились совпадения.
    /// Свайпы могут быть сделаны в разное время: важно только, что оба сказали «да».
    /// Передавай свайпы одного подбора.
    public static func matches(_ swipes: [Swipe], couple: Couple) -> [Int] {
        let pair = [couple.man.id, couple.woman.id]
        var latest: [Key: SwipeAction] = [:]
        var matched: [Int] = []
        // Проигрываем свайпы по времени: совпадение случается в момент второго ♥,
        // а если кто-то передумал, фильм из совпадений уходит.
        for swipe in chronological(swipes) where pair.contains(swipe.personID) {
            latest[Key(personID: swipe.personID, movieID: swipe.movieID)] = swipe.action
            let bothYes = pair.allSatisfy { latest[Key(personID: $0, movieID: swipe.movieID)] == .yes }
            if bothYes, !matched.contains(swipe.movieID) {
                matched.append(swipe.movieID)
            } else if !bothYes {
                matched.removeAll { $0 == swipe.movieID }
            }
        }
        return matched
    }

    /// Фильмы, которым кто-то поставил ♥ (и не передумал), в порядке первых ♥.
    /// Запасной список, когда колода кончилась без совпадения.
    public static func likedByAnyone(_ swipes: [Swipe]) -> [Int] {
        let liked = Set(latestSwipes(swipes).filter { $0.action == .yes }.map(\.movieID))
        var seen = Set<Int>()
        return chronological(swipes)
            .filter { $0.action == .yes && liked.contains($0.movieID) }
            .map(\.movieID)
            .filter { seen.insert($0).inserted }
    }

    /// Последний свайп каждого человека по каждому фильму: передумал — считается последнее решение.
    static func latestSwipes(_ swipes: [Swipe]) -> [Swipe] {
        var latest: [Key: Swipe] = [:]
        for swipe in chronological(swipes) {
            latest[Key(personID: swipe.personID, movieID: swipe.movieID)] = swipe
        }
        return Array(latest.values)
    }

    private struct Key: Hashable {
        let personID: UUID
        let movieID: Int
    }

    /// Свайпы с одинаковым временем остаются в порядке добавления.
    private static func chronological(_ swipes: [Swipe]) -> [Swipe] {
        swipes.enumerated().sorted { ($0.element.date, $0.offset) < ($1.element.date, $1.offset) }.map(\.element)
    }
}
