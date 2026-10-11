import DesignSystem
import SwiftUI

/// Согласие на обработку данных после первого входа. Текст — «Часть 1» из docs/legal/consent.md
/// (черновик для юриста): две отдельные галочки, обычные данные и особая категория (здоровье и
/// интимная жизнь, статья 10 152-ФЗ). Обе выключены, дальше не пускает, пока не отмечены обе.
struct ConsentView: View {
    @Environment(AuthFlow.self) private var auth
    @State private var personalData = false
    @State private var specialCategory = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Card {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("В one-to-one вы записываете очень личное: секс и цикл. Эти записи шифруются на вашем телефоне. На сервер в России они попадают зашифрованными, и прочитать их можете только вы и ваш партнёр. Мы — нет.")
                            Text("Мы видим только вашу почту, то, что вы в паре, и технические данные для безопасности: IP-адрес и устройство.")
                            Text("Удалить аккаунт можно в любой момент в настройках. Общие записи пары при этом останутся у партнёра, если он остаётся в паре.")
                        }
                    }

                    Toggle("Даю согласие на обработку моих персональных данных: почты, данных аккаунта и пары.",
                           isOn: $personalData)
                        .toggleStyle(CheckboxToggleStyle())
                    Toggle("Даю согласие на обработку сведений о моём здоровье и интимной жизни: секс, месячные, самочувствие, симптомы.",
                           isOn: $specialCategory)
                        .toggleStyle(CheckboxToggleStyle())

                    VStack(alignment: .leading, spacing: 8) {
                        Link("Полный текст согласия", destination: BackendConfig.consentURL)
                        Link("Политика конфиденциальности", destination: BackendConfig.privacyPolicyURL)
                    }
                    .font(.body.weight(.semibold))

                    if let error = auth.errorMessage {
                        AuthFooter(error: error, hint: "")
                    }
                }
                .padding(20)
            }
            .background(Palette.background)
            .navigationTitle("Ваши данные")
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    GradientButton(title: auth.isWorking ? "Сохраняем…" : "Согласен(на), продолжить") {
                        Task { await auth.giveConsent(personalData: personalData, specialCategory: specialCategory) }
                    }
                    .disabled(!canContinue)
                    Text("Нажимая кнопку, вы подписываете согласие простой электронной подписью: вход по коду из письма подтверждает, что это вы.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
                .background(Palette.background)
            }
            .toolbar {
                // Не хочет соглашаться или вошёл не с той почты.
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Выйти") { Task { await auth.signOut() } }
                        .disabled(auth.isWorking)
                }
            }
        }
    }

    private var canContinue: Bool {
        AuthFlow.canGiveConsent(personalData: personalData, specialCategory: specialCategory) && !auth.isWorking
    }
}

/// Галочка слева от текста: для согласия привычнее переключателя.
private struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                    .font(.title2)
                    .foregroundStyle(configuration.isOn ? BrandColor.pink.color : .secondary)
                configuration.label
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .accessibilityRepresentation {
            Toggle(isOn: configuration.$isOn) { configuration.label }
        }
    }
}

#if DEBUG
#Preview {
    ConsentView()
        .environment(AuthFlow.preview(signedIn: true))
}
#endif
