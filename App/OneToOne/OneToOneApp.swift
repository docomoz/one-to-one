import Core
import SwiftUI

@main
struct OneToOneApp: App {
    @State private var model = AppModel(store: LocalStore())

    var body: some Scene {
        WindowGroup {
            TabView {
                Tab("Главная", systemImage: "house") {
                    HomeView()
                }
                Tab("Фильмы", systemImage: "film") {
                    MoviesView()
                }
                Tab("Трекер", systemImage: "heart") {
                    TrackerView()
                }
            }
            .environment(model)
        }
    }
}
