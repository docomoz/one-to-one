import DesignSystem
import SwiftUI

/// Первый экран: почта → «Получить код». Код вводится на следующем экране.
struct EmailSignInView: View {
    @Environment(AuthFlow.self) private var auth
    @State private var email = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Почта", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.send)
                        .focused($isFocused)
                        .onSubmit(send)
                } header: {
                    Text("Заметки, цикл и фильмы на двоих. Войдите, чтобы записи были у вас обоих.")
                        .font(.body)
                        .foregroundStyle(.primary)
                        .textCase(nil)
                        .padding(.bottom, 8)
                } footer: {
                    AuthFooter(error: auth.errorMessage, hint: "Пришлём письмо с кодом из 6 цифр. Пароль не нужен.")
                }
            }
            .navigationTitle("Вход")
            .safeAreaInset(edge: .bottom) {
                GradientButton(title: auth.isWorking ? "Отправляем…" : "Получить код", action: send)
                    .disabled(!canSend)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            }
            .navigationDestination(isPresented: codeStep) { CodeEntryView() }
            .onChange(of: email) { auth.clearError() }
            .onAppear { isFocused = true }
        }
    }

    private var canSend: Bool {
        AuthFlow.isPlausibleEmail(email) && !auth.isWorking
    }

    /// Код отправлен — показываем экран кода; назад с него — снова почта.
    private var codeStep: Binding<Bool> {
        Binding(
            get: { auth.pending != nil },
            set: { if !$0 { auth.changeEmail() } }
        )
    }

    private func send() {
        guard canSend else { return }
        Task { await auth.sendCode(to: email) }
    }
}

#if DEBUG
#Preview {
    EmailSignInView()
        .environment(AuthFlow.preview())
}
#endif
