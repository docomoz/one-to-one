import Core
import DesignSystem
import SwiftUI

/// Списки «хочу посмотреть»: мой и партнёра. Добавляю только в свой, через поиск.
struct WatchlistView: View {
    @Environment(AppModel.self) private var model
    @State private var showsPartner = false
    @State private var isSearching = false

    var body: some View {
        List {
            Section {
                Picker("Чей список", selection: $showsPartner) {
                    Text("Мой список").tag(false)
                    Text(partnerName.map { "Список: \($0)" } ?? "Партнёра").tag(true)
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            ForEach(items, id: \.movie.id) { item in
                MovieRow(movie: item.movie)
                    .swipeActions {
                        if !showsPartner {
                            Button("Удалить", systemImage: "trash", role: .destructive) {
                                model.removeFromWatchlist(movieID: item.movie.id)
                            }
                        }
                    }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Palette.background)
        .overlay { if items.isEmpty { emptyState } }
        .safeAreaInset(edge: .bottom) {
            if !showsPartner {
                GradientButton(title: "Добавить фильм") { isSearching = true }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            }
        }
        .sheet(isPresented: $isSearching) { MovieSearchView() }
    }

    private var items: [WatchlistItem] {
        guard let owner = showsPartner ? model.data.partnerID : model.data.meID else { return [] }
        return model.data.watchlist(of: owner)
    }

    private var partnerName: String? {
        guard let couple = model.data.couple, let partner = model.data.partnerID else { return nil }
        return [couple.man, couple.woman].first { $0.id == partner }?.name
    }

    private var emptyState: some View {
        ContentUnavailableView(
            showsPartner ? "Пока пусто" : "Список пуст",
            systemImage: "popcorn",
            description: Text(showsPartner
                ? "Здесь появятся фильмы, которые добавит партнёр."
                : "Добавьте фильмы, которые хотите посмотреть вместе."))
    }
}

#Preview {
    NavigationStack {
        WatchlistView()
            .navigationTitle("Фильмы")
    }
    .environment(AppModel(store: InMemoryStore()))
    .environment(\.movieCatalog, PreviewCatalog())
}
