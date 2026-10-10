import Core
import SwiftUI

/// Плашка «Как вам фильм?» под карточкой вечера: 👍 / 👎 или закрыть без оценки.
struct RateMovieBanner: View {
    let movie: Movie
    let onRate: (MovieVerdict) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text("Как вам «\(movie.title)»?")
                .font(.subheadline)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            emojiButton("👍", label: "Понравился", verdict: .like)
            emojiButton("👎", label: "Не понравился", verdict: .dislike)
            Button { onRate(.skip) } label: {
                Image(systemName: "xmark")
                    .font(.footnote.weight(.semibold))
                    .frame(width: 28, height: 36)
            }
            // Стиль .borderless красит кнопку акцентным цветом: крестик должен быть неприметным.
            .tint(.secondary)
            .accessibilityLabel("Не оценивать")
        }
        // В строке List без этого нажатие на любую кнопку срабатывает как на все сразу.
        .buttonStyle(.borderless)
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func emojiButton(_ emoji: String, label: String, verdict: MovieVerdict) -> some View {
        Button { onRate(verdict) } label: {
            Text(emoji)
                .font(.title3)
                .frame(width: 40, height: 36)
                .background(.background, in: Capsule())
        }
        .accessibilityLabel(label)
    }
}

#Preview {
    VStack {
        RateMovieBanner(movie: Movie(id: 1, title: "Амели", year: 2001, genres: [], overview: "", posterURL: nil)) { _ in }
        RateMovieBanner(movie: Movie(id: 2, title: "Вечное сияние чистого разума", year: 2004, genres: [],
                                     overview: "", posterURL: nil)) { _ in }
    }
    .padding()
}
