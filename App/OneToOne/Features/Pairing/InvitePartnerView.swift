import DesignSystem
import SwiftUI
import UIKit

/// «Пригласить партнёра»: код приглашения, отправка в мессенджер и, когда партнёр ввёл код, сверка 6 цифр.
/// Пока экран открыт, раз в пару секунд спрашиваем сервер, не пришёл ли запрос ключа.
struct InvitePartnerView: View {
    @Environment(PairingFlow.self) private var pairing
    @Environment(\.dismiss) private var dismiss
    /// Сразу после знакомства: кнопка «Позже» закрывает окно.
    var showsLater = false

    var body: some View {
        ScrollView {
            if let step = pairing.incomingStep {
                VerifyCodeView(
                    step: step,
                    waitingText: "Партнёр ввёл код. Ждём его телефон…",
                    errorMessage: pairing.errorMessage,
                    isWorking: pairing.isWorking,
                    onConfirm: { Task { await pairing.confirmIncoming() } },
                    onReject: { Task { await pairing.rejectIncoming() } },
                    onRetry: { pairing.dismissIncoming() }
                )
            } else {
                invite
                    .padding(20)
            }
        }
        .background(Palette.background)
        .navigationTitle("Пригласить партнёра")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsLater || pairing.incomingStep == .done {
                ToolbarItem(placement: .confirmationAction) {
                    Button(pairing.incomingStep == .done ? "Готово" : "Позже") { close() }
                }
            }
        }
        .onAppear { pairing.isInviteScreenVisible = true }
        .onDisappear {
            pairing.isInviteScreenVisible = false
            // Закончившуюся сверку не показываем ещё раз окном поверх; идущая продолжится в нём.
            switch pairing.incomingStep {
            case .done, .failed: pairing.dismissIncoming()
            default: break
            }
        }
        .task {
            if pairing.invite == nil { await pairing.createInvite() }
        }
        .task {
            while !Task.isCancelled {
                if pairing.incomingStep == nil {
                    await pairing.checkIncoming()
                } else {
                    await pairing.pollIncoming()
                }
                try? await Task.sleep(for: .seconds(2.5))
            }
        }
    }

    private var invite: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Отправь код партнёру. Он установит one-to-one, войдёт по своей почте и введёт код. Потом на обоих телефонах появятся одинаковые 6 цифр: сверьте их, и записи пары будут у вас обоих.")
                .foregroundStyle(.secondary)

            Card {
                VStack(spacing: 8) {
                    if let invite = pairing.invite {
                        Text(PairingFlow.formattedCode(invite.code))
                            .font(.system(size: 40, weight: .bold, design: .monospaced))
                            .textSelection(.enabled)
                            .accessibilityLabel(invite.code.map(String.init).joined(separator: " "))
                        Text("Действует до \(invite.expiresAt.formatted(.dateTime.day().month(.wide)))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else if let error = pairing.errorMessage, !pairing.isWorking {
                        AuthFooter(error: error, hint: "")
                        Button("Попробовать ещё раз") { Task { await pairing.createInvite() } }
                    } else {
                        ProgressView()
                            .padding(.vertical, 16)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            if let invite = pairing.invite {
                ShareLink(item: Self.shareText(code: invite.code)) {
                    Label("Отправить код", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(BrandGradient.primary, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                Button {
                    UIPasteboard.general.string = PairingFlow.formattedCode(invite.code)
                } label: {
                    Label("Скопировать код", systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 4)
            }

            Label("Держи этот экран открытым, пока партнёр вводит код: здесь появятся цифры для сверки.",
                  systemImage: "iphone.gen3")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Card {
                Label {
                    Text(LossWarning.solo)
                } icon: {
                    Image(systemName: "lock.shield")
                        .foregroundStyle(BrandColor.purple.color)
                }
                .font(.footnote)
            }
        }
    }

    private func close() {
        pairing.presentsInvite = false
        if pairing.incomingStep == .done { pairing.dismissIncoming() }
        dismiss()
    }

    /// Текст для мессенджера. Ссылки нет: своего домена пока нет (docs/decisions.md), партнёр вводит код руками.
    static func shareText(code: String) -> String {
        "Давай вести one-to-one вместе. Установи приложение, войди по своей почте и введи код приглашения: \(PairingFlow.formattedCode(code)). Код действует 7 дней."
    }
}
