import Core
import DesignSystem
import SwiftUI

/// Карточка фильма в колоде: постер на всю карточку, текст снизу на затемнении.
struct MovieCardView: View {
    let movie: Movie

    var body: some View {
        poster
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .bottom) { caption }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
            .accessibilityElement(children: .combine)
    }

    private var poster: some View {
        AsyncImage(url: movie.posterURL) { phase in
            if let image = phase.image {
                image.resizable().scaledToFill()
            } else {
                ZStack {
                    Palette.tile
                    Image(systemName: "film").font(.system(size: 64)).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var caption: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(movie.title).font(.title2.bold())
            if !movie.details.isEmpty {
                Text(movie.details).font(.subheadline)
            }
            if let ratings = movie.ratings.line {
                Text(ratings).font(.subheadline.bold())
            }
            if !movie.overview.isEmpty {
                Text(movie.overview).font(.callout).lineLimit(3).opacity(0.9)
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .padding(.top, 60)
        .background(LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .top, endPoint: .bottom))
    }
}

#Preview("С рейтингами") {
    MovieCardView(movie: Movie(id: 1, title: "Амели", year: 2001, genres: ["комедия", "мелодрама"],
                               overview: "Застенчивая официантка решает тайком помогать людям вокруг.",
                               posterURL: nil, ratings: Ratings(imdb: 8.3, kinopoisk: 7.9)))
        .padding()
}

#Preview("Без постера и рейтингов") {
    MovieCardView(movie: Movie(id: 2, title: "Брат", year: nil, genres: [], overview: "", posterURL: nil))
        .padding()
}
