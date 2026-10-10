import Core
import DesignSystem
import SwiftUI

/// Секция списка фильмов с кнопкой «Смотрим»: «Совпали» или «Кто-то из вас лайкнул».
/// Кладётся внутрь `List`.
struct MatchesListView: View {
    let title: String
    let movies: [Movie]
    let onWatch: (Movie) -> Void

    var body: some View {
        Section(title) {
            ForEach(movies) { movie in
                HStack {
                    MovieRow(movie: movie)
                    Spacer()
                    Button("Смотрим") { onWatch(movie) }
                        .buttonStyle(.borderedProminent)
                        .tint(BrandColor.pink.color)
                }
            }
        }
    }
}
