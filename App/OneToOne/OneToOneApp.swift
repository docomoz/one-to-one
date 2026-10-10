import Core
import SwiftUI

@main
struct OneToOneApp: App {
    @State private var model = AppModel(store: LocalStore())

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
            // Полный календарь цикла только у неё; его упрощённый вид появится в #17.
            if model.data.meIsWoman {
                Tab("Цикл", systemImage: "drop") {
                    HerCalendarView()
                }
            }
        }
    }
}
