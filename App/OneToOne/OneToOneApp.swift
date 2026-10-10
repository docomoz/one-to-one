import Core
import SwiftUI

@main
struct OneToOneApp: App {
    @State private var model = AppModel(store: LocalStore())
    @State private var tab = AppTab.home

    var body: some Scene {
        WindowGroup {
            Group {
                if model.data.isPaired {
                    tabs
                } else {
                    OnboardingView()
                }
            }
            .environment(model)
            // Интерфейс только на русском: месяцы в выборе даты тоже, даже если iPhone на другом языке.
            .environment(\.locale, Locale(identifier: "ru_RU"))
        }
    }

    private var tabs: some View {
        TabView(selection: $tab) {
            Tab("Главная", systemImage: "house", value: .home) {
                HomeView(pickMovie: { tab = .movies })
            }
            Tab("Фильмы", systemImage: "film", value: .movies) {
                MoviesView()
            }
            Tab("Трекер", systemImage: "heart", value: .tracker) {
                TrackerView()
            }
            // Полный календарь цикла у неё, у него упрощённый вид с подсказкой дня.
            Tab("Цикл", systemImage: "drop", value: .cycle) {
                if model.data.meIsWoman {
                    HerCalendarView()
                } else {
                    HisCalendarView()
                }
            }
        }
    }
}

/// Вкладки приложения: по ним главная переключает на «Фильмы».
enum AppTab: Hashable {
    case home, movies, tracker, cycle
}
