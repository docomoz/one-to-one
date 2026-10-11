import Core
import SwiftUI

@main
struct OneToOneApp: App {
    @State private var model = AppModel(store: LocalStore())
    @State private var auth = Self.makeAuth()
    @State private var tab = AppTab.home
    @State private var pickFlow: PickFlowRequest?

    var body: some Scene {
        WindowGroup {
            // ZStack, а не Group: модификаторы Group достаются каждому экрану, и `.task` с проверкой
            // входа запускался бы заново при каждой смене экрана.
            ZStack {
                // Вход по почте → согласие → знакомство → вкладки.
                switch auth.screen(isPaired: model.data.isPaired) {
                case .checking:
                    ProgressView()
                case .signIn:
                    EmailSignInView()
                case .consent:
                    ConsentView()
                case .onboarding:
                    OnboardingView()
                case .tabs:
                    tabs
                }
            }
            .task { await auth.start() }
            .environment(model)
            .environment(auth)
            // Интерфейс только на русском: месяцы в выборе даты тоже, даже если iPhone на другом языке.
            .environment(\.locale, Locale(identifier: "ru_RU"))
        }
    }

    private var tabs: some View {
        TabView(selection: $tab) {
            Tab("Главная", systemImage: "house", value: .home) {
                // «Выбрать фильм» открывает подбор: идущий или выбор настроения, как карточка на «Фильмах».
                HomeView(pickMovie: { pickFlow = PickFlowRequest(session: model.currentPick) })
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
        .fullScreenCover(item: $pickFlow) { PickFlowView(session: $0.session) }
    }

    private static func makeAuth() -> AuthFlow {
        #if DEBUG
        if let preview = AuthFlow.fromLaunchArguments() { return preview }
        #endif
        let service = AppwriteAuthService.shared
        return AuthFlow(auth: service, consent: service)
    }
}

/// Вкладки приложения: по ним главная переключает на «Фильмы».
enum AppTab: Hashable {
    case home, movies, tracker, cycle
}
