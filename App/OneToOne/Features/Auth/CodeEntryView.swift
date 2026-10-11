import DesignSystem
import SwiftUI

/// Второй шаг входа: 6 цифр из письма. Шестая цифра сразу отправляет код.
struct CodeEntryView: View {
    @Environment(AuthFlow.self) private var auth
    @State private var code = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        Form {
            Section {
                TextField("Код из письма", text: $code)
                    // Код из письма подскажет клавиатура, если почта на этом же телефоне.
                    .textContentType(.oneTimeCode)
                    .keyboardType(.numberPad)
                    .font(.title2.monospacedDigit())
                    .focused($isFocused)
            } header: {
                if let email = auth.pending?.email {
                    Text("Отправили код на \(email)")
                        .textCase(nil)
                }
            } footer: {
                AuthFooter(error: auth.errorMessage,
                           hint: "Письмо обычно приходит за минуту. Если его нет, загляните в «Спам».")
            }
            Section {
                // Раз в секунду пересчитываем, сколько ждать до повторной отправки.
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let delay = auth.resendDelay(at: context.date)
                    Button(delay > 0 ? "Отправить ещё раз через \(delay) с" : "Отправить код ещё раз") {
                        code = ""
                        Task { await auth.resendCode() }
                    }
                    .disabled(delay > 0 || auth.isWorking)
                }
                Button("Изменить почту") { auth.changeEmail() }
            }
        }
        .navigationTitle("Код из письма")
        .safeAreaInset(edge: .bottom) {
            GradientButton(title: auth.isWorking ? "Проверяем…" : "Войти", action: submit)
                .disabled(code.count != 6 || auth.isWorking)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
        }
        .onChange(of: code) { _, new in
            // Вставили «123 456» — оставляем цифры; onChange придёт ещё раз уже с чистым кодом.
            let clean = AuthFlow.cleanCode(new)
            guard clean == new else {
                code = clean
                return
            }
            // Пустое поле — это мы стёрли неверный код: ошибку оставляем, пока человек не начал вводить.
            if !clean.isEmpty { auth.clearError() }
            submit()
        }
        .onAppear { isFocused = true }
    }

    private func submit() {
        guard code.count == 6, !auth.isWorking else { return }
        Task {
            await auth.confirm(code: code)
            // Не подошёл — стираем, иначе новые цифры не влезут в шесть и нажатия «пропадут».
            if auth.errorMessage != nil { code = "" }
        }
    }
}

#if DEBUG
#Preview {
    @Previewable @State var auth = AuthFlow.preview()
    NavigationStack {
        CodeEntryView()
    }
    .environment(auth)
    .task { await auth.sendCode(to: "dasha@example.com") }
}
#endif
