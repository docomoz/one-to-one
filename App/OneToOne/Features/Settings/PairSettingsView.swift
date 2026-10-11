import Core
import DesignSystem
import SwiftUI

/// Экран «Пара»: с какого дня вы вместе (дата сохраняется сразу, по ней строится плашка годовщины),
/// приглашение партнёра, выход из пары, выход из аккаунта и его удаление.
struct PairSettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(AuthFlow.self) private var auth
    @Environment(PairingFlow.self) private var pairing

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
            if pairing.coupleID != nil {
                LeaveCoupleSection()
            }
            AccountSection()
        }
        .navigationTitle("Пара")
        // Ошибки общие для нескольких экранов: старые, например прошлого выхода или приглашения, здесь не нужны.
        .onAppear {
            auth.clearError()
            pairing.clearError()
        }
    }

    /// Пока партнёр не вошёл, его можно пригласить в любой момент или самому войти в пару партнёра по его коду.
    private var partnerSection: some View {
        Section {
            if pairing.partnerLeft {
                Label("Партнёр вышел из пары", systemImage: "heart.slash")
            } else if pairing.partnerJoined {
                Label("Вы в паре вдвоём", systemImage: "heart.fill")
            } else {
                NavigationLink("Пригласить партнёра") { InvitePartnerView() }
                NavigationLink("Войти по коду партнёра") { JoinCoupleView() }
            }
        } header: {
            Text("Партнёр")
        } footer: {
            if pairing.partnerLeft {
                Text("Записи пары пока у тебя. Нового партнёра в эту пару не пригласить: у бывшего есть её ключ. Выйди из пары и создай новую, она начнётся с новым ключом. Записи этой пары при выходе сотрутся.")
            } else {
                Text(pairing.partnerJoined ? LossWarning.couple : LossWarning.solo)
            }
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
