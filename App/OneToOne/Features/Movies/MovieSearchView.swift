import Core
import DesignSystem
import MovieAPI
import SwiftUI

/// Поиск фильма на Кинопоиске и добавление в мой список.
struct MovieSearchView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var search: MovieSearch
    @State private var query = ""
    @FocusState private var isFieldFocused: Bool

    init(catalog: any MovieCatalog) {
        _search = State(initialValue: MovieSearch(catalog: catalog))
    }

    var body: some View {
        NavigationStack {
            List(search.results) { movie in
                HStack {
                    MovieRow(movie: movie)
                    Spacer()
                    addButton(movie)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Palette.background)
            .overlay { placeholder }
            .navigationTitle("Добавить фильм")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Название фильма")
            .searchFocused($isFieldFocused)
            .onAppear { isFieldFocused = true }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
            .task(id: trimmedQuery) { await search.run(trimmedQuery) }
        }
    }

    @ViewBuilder private var placeholder: some View {
        if let errorMessage = search.errorMessage {
            ContentUnavailableView("Не получилось найти", systemImage: "wifi.exclamationmark",
                                   description: Text(errorMessage))
        } else if search.isLoading && search.results.isEmpty {
            ProgressView()
        } else if search.results.isEmpty && trimmedQuery.count >= 2 {
            ContentUnavailableView.search(text: trimmedQuery)
        } else if search.results.isEmpty {
            ContentUnavailableView("Найдите фильм", systemImage: "magnifyingglass",
                                   description: Text("Он попадёт в ваш список, и его увидит партнёр."))
        }
    }

    private func addButton(_ movie: Movie) -> some View {
        let added = model.isInMyWatchlist(movieID: movie.id)
        return Button {
            if added { model.removeFromWatchlist(movieID: movie.id) } else { model.addToWatchlist(movie) }
        } label: {
            Image(systemName: added ? "checkmark.circle.fill" : "plus.circle")
                .font(.title2)
                .foregroundStyle(BrandGradient.primary)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(added ? "Убрать из списка" : "Добавить в список")
    }

    private var trimmedQuery: String { MovieSearch.normalized(query) }

}

#Preview {
    MovieSearchView(catalog: PreviewCatalog())
        .environment(AppModel(store: InMemoryStore()))
}
