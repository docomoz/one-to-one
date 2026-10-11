import DesignSystem
import SwiftUI

/// Окно поверх приложения, когда телефон партнёра просит ключ пары, а экран приглашения закрыт:
/// партнёр ввёл код, пока приложение было свёрнуто, или вошёл на новом телефоне. Сверка кода, как на экране приглашения.
struct IncomingKeySheet: View {
    @Environment(PairingFlow.self) private var pairing

    var body: some View {
        NavigationStack {
            ScrollView {
                if let step = pairing.incomingStep {
                    VerifyCodeView(
                        step: step,
                        waitingText: "Телефон партнёра просит ключ пары. Ждём его ответа…",
                        errorMessage: pairing.errorMessage,
                        isWorking: pairing.isWorking,
                        onConfirm: { Task { await pairing.confirmIncoming() } },
                        onReject: { Task { await pairing.rejectIncoming() } },
                        onScan: { text in Task { await pairing.confirmIncoming(scanned: text) } }
                    )
                }
            }
            .background(Palette.background)
            .navigationTitle("Ключ пары")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(pairing.incomingStep == .done ? "Готово" : "Закрыть") { Task { await close() } }
                }
            }
        }
        .interactiveDismissDisabled()
        .task {
            while !Task.isCancelled {
                await pairing.pollIncoming()
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    /// Закрыли, не сверив код: ключ не отдаём, телефон партнёра узнает об отказе.
    private func close() async {
        switch pairing.incomingStep {
        case .waiting, .verify: await pairing.rejectIncoming()
        default: break
        }
        pairing.dismissIncoming()
    }
}
