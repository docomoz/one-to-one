import DesignSystem
import SwiftUI

/// Сразу после входа: проверяем, чьи данные на телефоне и есть ли у человека пара на сервере
/// (`PairingFlow.prepareAccount`). Обычно это мгновенно; без сети после переустановки — повторить.
struct AccountCheckView: View {
    @Environment(PairingFlow.self) private var pairing
    @Environment(AuthFlow.self) private var auth

    var body: some View {
        VStack(spacing: 16) {
            if case .failed(let error) = pairing.accountState {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 44))
                    .foregroundStyle(BrandColor.pink.color)
                Text("Не получилось узнать, есть ли у тебя пара")
                    .font(.title3.bold())
                    .multilineTextAlignment(.center)
                Text(error.message)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                GradientButton(title: "Повторить") { Task { await retry() } }
                Button("Выйти из аккаунта") { Task { await pairing.signOut(auth: auth) } }
                    .disabled(auth.isWorking)
            } else {
                ProgressView()
                    .controlSize(.large)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.background)
    }

    private func retry() async {
        guard let userID = auth.userID else { return }
        await pairing.prepareAccount(userID: userID)
    }
}
