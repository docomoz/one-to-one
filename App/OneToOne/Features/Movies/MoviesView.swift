import Core
import SwiftUI

/// Вкладка «Фильмы»: сверху карточка вечера и совпадения, ниже списки.
struct MoviesView: View {
    @Environment(AppModel.self) private var model
    @State private var flow: PickFlowRequest?

    var body: some View {
        NavigationStack {
            WatchlistView { header }
                .navigationTitle("Фильмы")
                #if DEBUG
                .toolbar { debugSwitch }
                #endif
                .fullScreenCover(item: $flow) { PickFlowView(session: $0.session) }
        }
    }

    @ViewBuilder
    private var header: some View {
        let state = PickCardState.make(model.data)
        Section {
            PickCard(state: state,
                     onOpen: { flow = PickFlowRequest(session: model.currentPick) },
                     onNewPick: { flow = PickFlowRequest(session: nil) })
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
        if let movie = model.movieToRate {
            Section {
                RateMovieBanner(movie: movie) { verdict in
                    withAnimation { model.rate(movieID: movie.id, verdict) }
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
        if case .inProgress(let session, let count) = state, count > 0 {
            MatchesListView(title: "Совпали", movies: model.data.movies(model.matches(in: session))) {
                model.markWatched(movieID: $0.id)
            }
        }
    }

    #if DEBUG
    /// Переключатель «я — он / она»: пройти подбор за двоих на одном телефоне.
    private var debugSwitch: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu("Я: \(myName)") {
                Button("Переключиться на партнёра") { model.switchMe() }
            }
        }
    }

    private var myName: String {
        guard let couple = model.data.couple else { return "?" }
        return model.data.meID == couple.man.id ? couple.man.name : couple.woman.name
    }
    #endif
}

#Preview {
    MoviesView()
        .environment(AppModel(store: InMemoryStore()))
}
