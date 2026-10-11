import DesignSystem
import SwiftUI

/// Вход в пару партнёра по коду из сообщения. Потом сверка 6 цифр, и ключ пары переходит на этот телефон.
/// Если на телефоне уже есть записи, перед входом предупреждаем: их заменят записи пары.
struct JoinCoupleView: View {
    @Environment(PairingFlow.self) private var pairing
    @Environment(AppModel.self) private var model
    @State private var code = ""
    @State private var confirmsReplace = false
    /// Есть ли записи, которые заменятся. Считаем один раз: каждый перерасчёт перебирает все данные.
    @State private var hasRecords = false
    @FocusState private var isFocused: Bool

    var body: some View {
        // ZStack, а не Group: модификаторы Group достались бы каждой ветке, и `.task` перезапускался бы при смене шага.
        ZStack {
            if let step = pairing.joinStep {
                ScrollView {
                    VerifyCodeView(
                        step: step,
                        waitingText: "Попроси партнёра открыть one-to-one: на его телефоне появится такой же код. Не закрывай этот экран.",
                        onConfirm: { Task { await pairing.confirmJoin() } },
                        onReject: { Task { await pairing.rejectJoin() } },
                        onRetry: { Task { await pairing.startKeyRequest() } },
                        qrPayload: pairing.verifyQRPayload
                    )
                    if step != .done {
                        Button("Не входить в пару", role: .destructive) { Task { await pairing.cancelJoin() } }
                            .disabled(pairing.isWorking)
                        if let error = pairing.errorMessage {
                            AuthFooter(error: error, hint: "")
                                .padding(.horizontal, 20)
                        }
                    }
                }
                .task {
                    while !Task.isCancelled {
                        await pairing.pollJoin()
                        try? await Task.sleep(for: .seconds(2))
                    }
                }
            } else if pairing.joiningCoupleID != nil {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                form
            }
        }
        .background(Palette.background)
        .navigationTitle("Код от партнёра")
        .onAppear {
            pairing.clearError()
            hasRecords = model.hasSyncedRecords
        }
        // Вошли по коду раньше, но ключ не получили (например, закрыли приложение): просим заново.
        // Задача на всём экране, а не на крутилке: та пропадёт, как только начнётся запрос, и отменила бы его.
        .task {
            if pairing.joiningCoupleID != nil, pairing.joinStep == nil { await pairing.startKeyRequest() }
        }
    }

    private var form: some View {
        Form {
            Section {
                TextField("Например, K7PM-Q4XH", text: $code)
                    .font(.title2.monospaced())
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .focused($isFocused)
                    .submitLabel(.join)
                    .onSubmit(submit)
            } footer: {
                AuthFooter(error: pairing.errorMessage,
                           hint: "8 букв и цифр из сообщения партнёра. Он найдёт код в настройках пары: «Пригласить партнёра».")
            }
            if hasRecords {
                Section {
                    Label("Записи на этом телефоне заменятся записями пары. Свои записи сюда не перенесутся.",
                          systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            GradientButton(title: pairing.isWorking ? "Входим…" : "Войти в пару", action: submit)
                .disabled(!canSubmit)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
        }
        .onChange(of: code) { pairing.clearError() }
        .onAppear { isFocused = true }
        .confirmationDialog("Заменить записи на этом телефоне?", isPresented: $confirmsReplace,
                            titleVisibility: .visible) {
            Button("Заменить и войти", role: .destructive) { join() }
        } message: {
            Text("Твои записи на этом телефоне сотрутся, вместо них появятся записи пары.")
        }
    }

    private var canSubmit: Bool {
        PairingFlow.normalizedCode(code).count == 8 && !pairing.isWorking
    }

    private func submit() {
        guard canSubmit else { return }
        if hasRecords {
            confirmsReplace = true
        } else {
            join()
        }
    }

    private func join() {
        Task { await pairing.join(code: code) }
    }
}
