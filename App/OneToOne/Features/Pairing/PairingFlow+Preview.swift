#if DEBUG
import Core
import Foundation
import SwiftUI
import Sync

/// Пара без сервера для превью и скриншотов: всё удаётся, в паре двое, запросов ключа нет.
struct PreviewPairingService: PairingService {
    func createCouple(coupleID: String) async throws -> String { coupleID }
    func createInvite(coupleID: String) async throws -> InviteCode {
        InviteCode(code: "K7PMQ4XH", expiresAt: Date().addingTimeInterval(7 * 24 * 3600))
    }
    func acceptInvite(code: String) async throws -> String { "preview-couple" }
    func leaveCouple(coupleID: String) async throws {}
    func couples() async throws -> [String] { [] }
    func deleteAccount() async throws {}
    func memberCount(coupleID: String) async throws -> Int { 2 }
    func createKeyRequest(coupleID: String, commitment: Data, expiresAt: Date) async throws -> KeyRequest {
        KeyRequest(id: "preview", coupleID: coupleID, requesterUserID: "preview",
                   requesterKeyCommitment: commitment, status: .waiting, expiresAt: expiresAt)
    }
    func keyRequest(id: String) async throws -> KeyRequest? { nil }
    func keyRequests(coupleID: String) async throws -> [KeyRequest] { [] }
    func update(_ request: KeyRequest, with update: KeyRequestUpdate) async throws {}
}

extension PairingFlow {
    /// Каждый раз с чистыми настройками пары: иначе состояние прошлого превью (например, «уже в паре») перешло бы в следующее.
    static func preview(model: AppModel) -> PairingFlow {
        let suite = "preview-pairing"
        UserDefaults.standard.removePersistentDomain(forName: suite)
        return PairingFlow(model: model, service: PreviewPairingService(), keys: InMemoryKeyStore(),
                           defaults: PairingDefaults(defaults: UserDefaults(suiteName: suite)!))
    }
}

/// Запуск с `-previewPairing <экран>` показывает экран пары без сервера (для скриншотов и проверки на симуляторе):
/// `onboarding`, `partner`, `invite`, `join`, `verify`, `choose`, `restore`, `restoreVerify`, `settings`.
struct PairingPreviewScreen: View {
    let screen: String
    @State private var model: AppModel
    @State private var pairing: PairingFlow
    @State private var auth = AuthFlow.preview(signedIn: true)
    @State private var partner = PersonDraft(sex: .male, name: "Максим", birthDate: DayKey(year: 1994, month: 3, day: 2))

    init(screen: String) {
        self.screen = screen
        var data = AppData()
        if screen == "choose" {
            data = .homePreview(meIsWoman: false)
            data.meID = nil
        } else if screen == "join" || screen == "settings" {
            data = .homePreview(meIsWoman: false)
        }
        let model = AppModel(store: InMemoryStore(data))
        let pairing = PairingFlow.preview(model: model)
        switch screen {
        case "invite": pairing.invite = InviteCode(code: "K7PMQ4XH", expiresAt: Date().addingTimeInterval(7 * 24 * 3600))
        case "verify": pairing.joinStep = .verify(code: "042917")
        case "choose": (pairing.coupleID, pairing.isCoupleOnServer) = ("preview-couple", true)
        case "restore":
            pairing.restoringCoupleID = "preview-couple"
            pairing.joinStep = .waiting
        case "restoreVerify":
            pairing.restoringCoupleID = "preview-couple"
            pairing.joinStep = .verify(code: "042917")
            pairing.joinRequestID = "6acbe1c5001b61609635"
        case "settings":
            (pairing.coupleID, pairing.isCoupleOnServer, pairing.partnerJoined) = ("preview-couple", true, true)
        default: break
        }
        _model = State(initialValue: model)
        _pairing = State(initialValue: pairing)
    }

    /// Экран из аргументов запуска или `nil`, если их нет.
    static var fromLaunchArguments: String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-previewPairing"), index + 1 < arguments.count else { return nil }
        return arguments[index + 1]
    }

    var body: some View {
        Group {
            switch screen {
            case "invite":
                NavigationStack { InvitePartnerView(showsLater: true) }
            case "join", "verify":
                NavigationStack { JoinCoupleView() }
            case "restore", "restoreVerify":
                RestoreAccessView()
            case "settings":
                NavigationStack { PairSettingsView() }
            case "partner":
                NavigationStack {
                    PersonFormView(title: "Партнёр", draft: $partner, buttonTitle: "Создать пару", onSexPicked: {},
                                   note: LossWarning.couple) { () throws(OnboardingError) in }
                }
            default:
                OnboardingView()
            }
        }
        .environment(model)
        .environment(pairing)
        .environment(auth)
        .environment(\.locale, Locale(identifier: "ru_RU"))
    }
}
#endif
