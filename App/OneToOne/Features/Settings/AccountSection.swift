import DesignSystem
import SwiftUI

/// Настройки аккаунта: выход и удаление. Перед выходом пробуем отправить правки; если не ушли — предупреждаем,
/// что они пропадут. Удаление аккаунта по требованию App Store прямо в приложении, с подтверждением.
struct AccountSection: View {
    @Environment(AuthFlow.self) private var auth
    @Environment(PairingFlow.self) private var pairing
    @State private var signOutCheck: SignOutCheck?
    @State private var isCheckingUnsent = false
    @State private var confirmsDelete = false

    private enum SignOutCheck: Identifiable {
        case clean, unsent
        var id: Self { self }
    }

    var body: some View {
        Section {
            Button(isCheckingUnsent ? "Отправляем правки…" : "Выйти из аккаунта", role: .destructive) {
                Task { await askSignOut() }
            }
            .confirmationDialog("Выйти из аккаунта?", isPresented: signOutDialog, titleVisibility: .visible,
                                presenting: signOutCheck) { check in
                Button(check == .unsent ? "Выйти, правки пропадут" : "Выйти", role: .destructive) {
                    Task { await pairing.signOut(auth: auth) }
                }
            } message: { check in
                Text(check == .unsent ? Self.unsentMessage : Self.signOutMessage)
            }
            Button("Удалить аккаунт", role: .destructive) { confirmsDelete = true }
                .confirmationDialog("Удалить аккаунт?", isPresented: $confirmsDelete, titleVisibility: .visible) {
                    Button("Удалить навсегда", role: .destructive) {
                        Task { await pairing.deleteAccount(auth: auth) }
                    }
                } message: {
                    Text(Self.deleteMessage)
                }
        } header: {
            Text("Аккаунт")
        } footer: {
            if let error = auth.errorMessage ?? pairing.errorMessage {
                AuthFooter(error: error, hint: "")
            }
        }
        .disabled(auth.isWorking || pairing.isWorking || isCheckingUnsent)
    }

    private var signOutDialog: Binding<Bool> {
        Binding(get: { signOutCheck != nil }, set: { if !$0 { signOutCheck = nil } })
    }

    private func askSignOut() async {
        isCheckingUnsent = true
        let unsent = await pairing.hasUnsentChanges()
        isCheckingUnsent = false
        signOutCheck = unsent ? .unsent : .clean
    }

    static let signOutMessage = "Записи сотрутся с этого телефона, следующий, кто войдёт, их не увидит. Войди с той же почтой, и они вернутся с сервера."
    static let unsentMessage = "Есть неотправленные изменения, они пропадут. Чтобы их сохранить, подключись к интернету и выйди чуть позже."
    static let deleteMessage = "Аккаунт удалится с сервера, записи сотрутся с этого телефона. Если ты в паре, у партнёра записи останутся. Отменить нельзя."
}
