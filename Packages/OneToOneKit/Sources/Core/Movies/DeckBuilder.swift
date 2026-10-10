/// Собирает колоду фильмов для подбора под настроение.
public enum DeckBuilder {
    /// Сначала фильмы из обоих списков (подходящие настроению раньше), потом рекомендации
    /// с жанром настроения, за ними рекомендации без жанров («похожие» Кинопоиска приходят без них). Каждый фильм один раз, без просмотренных и уже свайпнутых мной,
    /// не больше `limit`. Без рекомендаций (нет интернета) колода строится из одних списков.
    public static func build(lists: [WatchlistItem], recommendations: [Movie], mood: Mood,
                             watched: Set<Int>, swipedByMe: Set<Int>, limit: Int = 40) -> [Movie] {
        let fits = { (movie: Movie) in movie.genres.contains(where: mood.genres.contains) }
        let listed = lists.map(\.movie)
        let candidates = listed.filter(fits) + listed.filter { !fits($0) }
            + recommendations.filter(fits) + recommendations.filter(\.genres.isEmpty)

        var seen = watched.union(swipedByMe)
        var deck: [Movie] = []
        for movie in candidates where seen.insert(movie.id).inserted {
            guard deck.count < limit else { break }
            deck.append(movie)
        }
        return deck
    }
}
