import DesignSystem
import SwiftUI

/// Новый телефон или переустановка: пара на сервере есть, а ключа от записей на этом телефоне нет.
/// Ключ просим у телефона партнёра (или своего второго) той же передачей со сверкой кода, что и при приглашении.
/// Вживую партнёр может отсканировать QR вместо сверки цифр.
struct RestoreAccessView: View {
    @Environment(PairingFlow.self) private var pairing
    @Environment(AuthFlow.self) private var auth
    @State private var confirmsStartOver = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 8) {
                    Text("Ты уже в паре, но на этом телефоне нет ключа от ваших записей. Его даст телефон партнёра.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                    if let step = pairing.joinStep {
                        VerifyCodeView(
                            step: step,
                            waitingText: "Попроси партнёра открыть one-to-one и подтвердить код: на обоих телефонах появятся одинаковые 6 цифр. Не закрывай этот экран.",
                            onConfirm: { Task { await pairing.confirmJoin() } },
                            onReject: { Task { await pairing.rejectJoin() } },
                            onRetry: { Task { await pairing.startKeyRequest() } },
                            qrPayload: pairing.verifyQRPayload
                        )
                    } else {
                        ProgressView()
                            .padding(.vertical, 40)
                    }
                    footer
                }
            }
            .background(Palette.background)
            .navigationTitle("Ключ от записей")
            .confirmationDialog("Начать заново без старых записей?", isPresented: $confirmsStartOver,
                                titleVisibility: .visible) {
                Button("Выйти из пары и начать заново", role: .destructive) {
                    Task { await pairing.abandonRestore() }
                }
            } message: {
                Text("Ты выйдешь из пары. Старые записи на этом телефоне не откроются, у партнёра они останутся.")
            }
        }
        // Запрос ключа живёт, пока открыт экран; после перезапуска начинается новый.
        .task {
            if pairing.joinStep == nil { await pairing.startKeyRequest() }
            while !Task.isCancelled {
                await pairing.pollJoin()
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 12) {
            if let error = pairing.errorMessage {
                AuthFooter(error: error, hint: "")
            }
            Label("Ключ есть только на ваших телефонах, сервер его не знает. Если телефона партнёра нет, записи не открыть.",
                  systemImage: "lock.shield")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button("Начать заново без старых записей", role: .destructive) { confirmsStartOver = true }
                .disabled(pairing.isWorking)
            Button("Войти в другой аккаунт") { Task { await pairing.signOut(auth: auth) } }
                .disabled(pairing.isWorking || auth.isWorking)
        }
        .font(.callout)
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
    }
}
