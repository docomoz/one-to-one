import Core
import DesignSystem
import SwiftUI

/// Колода кончилась: выбираем из совпадений, из лайков или ждём партнёра.
struct DeckEndView: View {
    let session: PickSession
    let onWatch: (Movie) -> Void
    @Environment(AppModel.self) private var model

    var body: some View {
        switch DeckEnd.make(model.data, session: session) {
        case .matches(let movies):
            list(title: "Совпали", movies: movies)
        case .liked(let movies):
            list(title: "Кто-то из вас лайкнул", movies: movies)
        case .empty(let partnerName):
            ContentUnavailableView(
                "Колода кончилась",
                systemImage: "rectangle.stack",
                description: Text("Подождите, пока посвайпает \(partnerName), или начните новый подбор."))
        }
    }

    private func list(title: String, movies: [Movie]) -> some View {
        List {
            MatchesListView(title: title, movies: movies, onWatch: onWatch)
        }
        .scrollContentBackground(.hidden)
        .background(Palette.background)
    }
}
