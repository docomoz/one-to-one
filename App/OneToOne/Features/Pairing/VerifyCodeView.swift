import DesignSystem
import SwiftUI

/// Сверка кода при передаче ключа пары: оба телефона показывают одни и те же 6 цифр, люди сверяют их голосом
/// или в переписке. Совпали — ключ переходит. Не совпали — кто-то вмешался, ключ не передаётся.
/// Только показывает шаг; что делать по кнопкам, решает тот, кто показывает.
struct VerifyCodeView: View {
    let step: HandoffStep
    /// Что сказать, пока второй телефон молчит.
    let waitingText: String
    var errorMessage: String?
    var isWorking = false
    let onConfirm: () -> Void
    let onReject: () -> Void
    /// «Начать заново» после ошибки. `nil` — кнопки нет.
    var onRetry: (() -> Void)?
    /// Телефон без ключа: QR с тем же кодом для сверки вживую (`VerifyQR`). `nil` — QR нет.
    var qrPayload: String?
    /// Телефон с ключом: отсканировать QR телефона без ключа вместо сверки цифр. `nil` — кнопки нет.
    var onScan: ((String) -> Void)?
    @State private var showsScanner = false

    var body: some View {
        VStack(spacing: 20) {
            switch step {
            case .waiting:
                waiting(waitingText)
            case .verify(let code):
                verify(code)
            case .waitingForPartner:
                waiting("Ждём, пока партнёр подтвердит код у себя.")
            case .done:
                done
            case .failed(let error):
                failed(error)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
    }

    private func waiting(_ text: String) -> some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text(text)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 32)
    }

    private func verify(_ code: String) -> some View {
        VStack(spacing: 20) {
            Text("Сверьте код")
                .font(.title2.bold())
            Text(Self.spaced(code))
                .font(.system(size: 52, weight: .bold, design: .rounded).monospacedDigit())
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
                .background(Palette.tile, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .accessibilityLabel(code.map(String.init).joined(separator: " "))
            Text("На телефоне партнёра должны быть те же 6 цифр. Сверьте их голосом или в переписке. Если цифры разные, нажми «Не совпадает»: ключ не передастся.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let errorMessage {
                AuthFooter(error: errorMessage, hint: "")
            }
            GradientButton(title: isWorking ? "Передаём…" : "Совпадает", action: onConfirm)
                .disabled(isWorking)
            Button("Не совпадает", role: .destructive, action: onReject)
                .disabled(isWorking)
            if let onScan, QRScannerView.isAvailable {
                Button("Вы рядом? Отсканировать QR", systemImage: "qrcode.viewfinder") { showsScanner = true }
                    .disabled(isWorking)
                    .sheet(isPresented: $showsScanner) { QRScannerSheet(onScan: onScan) }
            }
            if let qrPayload {
                VStack(spacing: 8) {
                    QRCodeView(text: qrPayload)
                        .frame(width: 180, height: 180)
                    Text("Если вы рядом, партнёр может отсканировать этот QR в окне сверки вместо цифр.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 8)
            }
        }
    }

    private var done: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(BrandGradient.primary)
            Text("Готово, вы в паре")
                .font(.title2.bold())
            Text("Записи пары теперь на обоих телефонах.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 24)
    }

    private func failed(_ error: PairingError) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "xmark.octagon.fill")
                .font(.system(size: 48))
                .foregroundStyle(BrandColor.pink.color)
            Text(error.message)
                .multilineTextAlignment(.center)
            if let onRetry {
                GradientButton(title: "Начать заново", action: onRetry)
            }
        }
        .padding(.vertical, 24)
    }

    /// «123456» → «123 456»: так легче продиктовать.
    static func spaced(_ code: String) -> String {
        guard code.count == 6 else { return code }
        return "\(code.prefix(3)) \(code.suffix(3))"
    }
}

#Preview("Код") {
    VerifyCodeView(step: .verify(code: "042917"), waitingText: "", onConfirm: {}, onReject: {})
}

#Preview("Ждём") {
    VerifyCodeView(step: .waiting, waitingText: "Попроси партнёра открыть приложение.", onConfirm: {}, onReject: {})
}

#Preview("Ошибка") {
    VerifyCodeView(step: .failed(.keyMismatch), waitingText: "", onConfirm: {}, onReject: {}, onRetry: {})
}
