import Foundation


/// Ищет совпадения: фильмы, которым оба из пары поставили ♥.
public enum MatchFinder {
    /// Фильмы, где у обоих последний свайп ♥, в порядке, в котором случились совпадения.
    /// Свайпы могут быть сделаны в разное время: важно только, что оба сказали «да».
    /// Передавай свайпы одного подбора.
    public static func matches(_ swipes: [Swipe], couple: Couple) -> [Int] {
        let latest = latestSwipes(swipes)
        let pair = [couple.man.id, couple.woman.id]
        let matched = Set(latest.keys.map(\.movieID)).filter { movieID in
            pair.allSatisfy { latest[Key(personID: $0, movieID: movieID)]?.action == .yes }
        }
        return orderedByLastDate(matched, latest: latest)
    }

    /// Фильмы, которым кто-то из двоих поставил ♥ (и не передумал), в порядке первых ♥.
    /// Запасной список, когда колода кончилась без совпадения.
    public static func likedByAnyone(_ swipes: [Swipe]) -> [Int] {
        let latest = latestSwipes(swipes)
        let liked = Set(latest.values.filter { $0.action == .yes }.map(\.movieID))
        var seen = Set<Int>()
        return swipes.sorted { $0.date < $1.date }
            .map(\.movieID)
            .filter { liked.contains($0) && seen.insert($0).inserted }
    }

    private struct Key: Hashable {
        let personID: UUID
        let movieID: Int
    }

    /// Последний свайп каждого человека по каждому фильму: передумал — считается последнее решение.
    private static func latestSwipes(_ swipes: [Swipe]) -> [Key: Swipe] {
        var latest: [Key: Swipe] = [:]
        for swipe in swipes.sorted(by: { $0.date < $1.date }) {
            latest[Key(personID: swipe.personID, movieID: swipe.movieID)] = swipe
        }
        return latest
    }

    /// Совпадение случается во время второго ♥, поэтому сортируем по самому позднему свайпу фильма.
    private static func orderedByLastDate(_ movieIDs: Set<Int>, latest: [Key: Swipe]) -> [Int] {
        let dates = Dictionary(latest.values.filter { movieIDs.contains($0.movieID) }.map { ($0.movieID, $0.date) },
                               uniquingKeysWith: max)
        return movieIDs.sorted { (dates[$0]!, $0) < (dates[$1]!, $1) }
    }
}
