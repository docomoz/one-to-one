import Core
import DesignSystem
import SwiftUI

/// Шаг 3 подбора: оба поставили ♥ одному фильму.
struct MatchView: View {
    let movie: Movie
    let onWatch: () -> Void
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("💘 Совпадение!")
                .font(.largeTitle.weight(.heavy))
                .foregroundStyle(BrandGradient.text)
            AsyncImage(url: movie.posterURL) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    ZStack {
                        Palette.tile
                        Image(systemName: "film").font(.system(size: 48)).foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: 180, height: 270)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            VStack(spacing: 4) {
                Text(movie.title).font(.title2.bold()).multilineTextAlignment(.center)
                Text("Вам обоим понравилось").foregroundStyle(.secondary)
            }
            Spacer()
            GradientButton(title: "Смотрим", action: onWatch)
            Button("Ещё свайпать", action: onContinue)
                .font(.headline)
                .foregroundStyle(BrandColor.pink.color)
                .padding(.bottom, 8)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.background)
    }
}

#Preview {
    MatchView(movie: Movie(id: 1, title: "Амели", year: 2001, genres: [], overview: "", posterURL: nil),
              onWatch: {}, onContinue: {})
}
