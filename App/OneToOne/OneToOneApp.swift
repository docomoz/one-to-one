import Core
import SwiftUI

@main
struct OneToOneApp: App {
    @State private var model: AppModel
    @State private var pairing: PairingFlow
    @State private var auth = Self.makeAuth()
    @State private var tab = AppTab.home
    @State private var pickFlow: PickFlowRequest?
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let model = AppModel(store: LocalStore(), syncStateStore: SyncStateStore())
        _model = State(initialValue: model)
        _pairing = State(initialValue: PairingFlow(model: model, service: AppwritePairingService.shared))
    }

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if let screen = PairingPreviewScreen.fromLaunchArguments {
                PairingPreviewScreen(screen: screen)
            } else {
                root
            }
            #else
            root
            #endif
        }
    }

    private var root: some View {
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
            case .onboarding, .tabs:
                // Пока не ясно, чьи данные на телефоне и есть ли пара на сервере, ничего не показываем.
                if pairing.isAccountReady(for: auth.userID) {
                    if pairing.restoringCoupleID != nil {
                        // Пара есть, ключа на телефоне нет (переустановка, новый телефон, резервная копия без Keychain):
                        // просим ключ у партнёра, даже если записи из копии уже на телефоне.
                        RestoreAccessView()
                    } else if model.data.isPaired {
                        tabs
                    } else {
                        OnboardingView()
                    }
                } else {
                    AccountCheckView()
                }
            }
        }
        .task { await auth.start() }
        // Вошёл человек (или приложение запустилось уже в аккаунте): чьи данные, есть ли пара, нужен ли ключ.
        .task(id: auth.userID) {
            if let userID = auth.userID { await pairing.prepareAccount(userID: userID) }
        }
        // Синхронизация при запуске, при возврате в приложение и раз в минуту, пока оно открыто.
        // Уходя в фон или выходя из аккаунта, задача отменяется. Заодно дожимаем создание пары на сервере
        // (если не было сети) и смотрим, не просит ли телефон партнёра ключ пары.
        .task(id: scenePhase == .active && isSignedIn) {
            guard scenePhase == .active, isSignedIn else { return }
            while !Task.isCancelled {
                await pairing.prepareSync()
                #if DEBUG
                // Ручная пара из отладочного меню — только пока настоящей нет.
                if pairing.coupleID == nil { DebugSyncSettings.restore(into: model) }
                #endif
                await model.syncNow()
                await pairing.checkIncoming()
                try? await Task.sleep(for: .seconds(60))
            }
        }
        // Сразу после знакомства — приглашение партнёра.
        .sheet(isPresented: $pairing.presentsInvite) {
            NavigationStack { InvitePartnerView(showsLater: true) }
        }
        // Телефон партнёра просит ключ, а экран приглашения закрыт.
        .sheet(isPresented: incomingKeyRequest) { IncomingKeySheet() }
        .environment(model)
        .environment(auth)
        .environment(pairing)
        // Интерфейс только на русском: месяцы в выборе даты тоже, даже если iPhone на другом языке.
        .environment(\.locale, Locale(identifier: "ru_RU"))
    }

    private var incomingKeyRequest: Binding<Bool> {
        Binding(
            get: { pairing.incomingStep != nil && !pairing.isInviteScreenVisible && !pairing.presentsInvite },
            set: { if !$0 { pairing.dismissIncoming() } }
        )
    }

    /// Без входа сервер не отдаст записи пары: не синхронизируем. И пока не проверили, чьи данные на телефоне:
    /// иначе записи прежнего аккаунта ушли бы от имени нового.
    private var isSignedIn: Bool {
        switch auth.screen(isPaired: model.data.isPaired) {
        case .onboarding, .tabs: pairing.isAccountReady(for: auth.userID)
        case .checking, .signIn, .consent: false
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
