import Core
import DesignSystem
import SwiftUI

/// Строка фильма: постер, название, год и жанры.
struct MovieRow: View {
    let movie: Movie

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: movie.posterURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Image(systemName: "film").foregroundStyle(.secondary)
            }
            .frame(width: 44, height: 66)
            .background(Palette.tile)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(movie.title).font(.headline)
                Text(details).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var details: String {
        ([movie.year.map(String.init)] + [movie.genres.prefix(2).joined(separator: ", ")])
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }
}
