import SwiftUI

@main
struct OneToOneApp: App {
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
        }
    }
}
