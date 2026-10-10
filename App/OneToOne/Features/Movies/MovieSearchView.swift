import Core
import DesignSystem
import MovieAPI
import SwiftUI

/// Поиск фильма на Кинопоиске и добавление в мой список.
struct MovieSearchView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.movieCatalog) private var catalog
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [Movie] = []
    @State private var errorMessage: String?
    @State private var isSearching = false
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        NavigationStack {
            List(results) { movie in
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
            .task(id: query) { await search() }
        }
    }

    @ViewBuilder private var placeholder: some View {
        if let errorMessage {
            ContentUnavailableView("Не получилось найти", systemImage: "wifi.exclamationmark",
                                   description: Text(errorMessage))
        } else if isSearching && results.isEmpty {
            ProgressView()
        } else if results.isEmpty && trimmedQuery.count >= 2 {
            ContentUnavailableView.search(text: trimmedQuery)
        } else if results.isEmpty {
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

    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespaces) }

    /// Ждём паузу в наборе: каждый запрос тратит один из 200 бесплатных в день.
    private func search() async {
        let text = trimmedQuery
        errorMessage = nil
        guard text.count >= 2 else {
            results = []
            return
        }
        do {
            try await Task.sleep(for: .milliseconds(600))
        } catch {
            return // набрали ещё букву: этот поиск отменён
        }
        isSearching = true
        defer { isSearching = false }
        do {
            results = try await catalog.search(text)
        } catch is CancellationError {
        } catch {
            if Task.isCancelled { return }
            results = []
            errorMessage = MovieSearchError.message(for: error)
        }
    }
}

#Preview {
    MovieSearchView()
        .environment(AppModel(store: InMemoryStore()))
        .environment(\.movieCatalog, PreviewCatalog())
}
