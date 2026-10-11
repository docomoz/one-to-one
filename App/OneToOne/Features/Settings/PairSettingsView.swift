import Core
import DesignSystem
import SwiftUI

/// Экран «Пара»: с какого дня вы вместе (дата сохраняется сразу, по ней строится плашка годовщины),
/// приглашение партнёра и выход из аккаунта.
struct PairSettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(AuthFlow.self) private var auth
    @Environment(PairingFlow.self) private var pairing
    @State private var confirmsSignOut = false

    var body: some View {
        Form {
            Section {
                DateRow(title: "Вместе с", date: togetherSince, initial: DayKey(.now))
            }
            if model.data.togetherSince != nil {
                Section {
                    Button("Убрать дату", role: .destructive) {
                        model.setTogetherSince(nil)
                    }
                }
            }
            partnerSection
            Section {
                Button("Выйти", role: .destructive) { confirmsSignOut = true }
                    .disabled(auth.isWorking)
            } footer: {
                if let error = auth.errorMessage {
                    AuthFooter(error: error, hint: "")
                }
            }
        }
        .navigationTitle("Пара")
        // Ошибка общая для всех экранов входа: старая, например прошлого выхода, здесь не нужна.
        .onAppear { auth.clearError() }
        .confirmationDialog("Выйти из аккаунта?", isPresented: $confirmsSignOut, titleVisibility: .visible) {
            Button("Выйти", role: .destructive) {
                Task { await auth.signOut() }
            }
        } message: {
            Text("Записи останутся на этом телефоне. Чтобы вернуться, войдите по почте снова.")
        }
    }

    /// Пока партнёр не вошёл, его можно пригласить в любой момент или самому войти в пару партнёра по его коду.
    private var partnerSection: some View {
        Section {
            if pairing.partnerJoined {
                Label("Вы в паре вдвоём", systemImage: "heart.fill")
            } else {
                NavigationLink("Пригласить партнёра") { InvitePartnerView() }
                NavigationLink("Войти по коду партнёра") { JoinCoupleView() }
            }
        } header: {
            Text("Партнёр")
        } footer: {
            Text(pairing.partnerJoined ? LossWarning.couple : LossWarning.solo)
        }
        .task { await pairing.refreshPartnerJoined() }
    }

    private var togetherSince: Binding<DayKey?> {
        Binding(
            get: { model.data.togetherSince },
            set: { model.setTogetherSince($0) }
        )
    }
}

#Preview {
    NavigationStack {
        PairSettingsView()
    }
    .environment(AppModel(store: InMemoryStore(.homePreview(meIsWoman: false))))
    .environment(AuthFlow.preview(signedIn: true))
    .environment(PairingFlow.preview(model: AppModel(store: InMemoryStore())))
    .environment(\.locale, Locale(identifier: "ru_RU"))
}
