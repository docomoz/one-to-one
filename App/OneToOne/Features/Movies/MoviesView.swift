import SwiftUI

struct MoviesView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView("Скоро здесь что-то будет", systemImage: "film")
                .navigationTitle("Фильмы")
        }
    }
}

#Preview {
    MoviesView()
}
