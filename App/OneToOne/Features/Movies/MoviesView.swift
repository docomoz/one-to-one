import Core
import SwiftUI

/// Вкладка «Фильмы». Пока здесь списки; подбор под настроение появится в #23.
struct MoviesView: View {
    var body: some View {
        NavigationStack {
            WatchlistView()
                .navigationTitle("Фильмы")
        }
    }
}

#Preview {
    MoviesView()
        .environment(AppModel(store: InMemoryStore()))
}
