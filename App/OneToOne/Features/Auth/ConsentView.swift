import DesignSystem
import SwiftUI

/// Согласие на обработку данных, включая особую категорию (здоровье и интимная жизнь, 152-ФЗ).
/// Без галочки дальше не пускает. Текст — черновик, юрист посмотрит его в #88.
struct ConsentView: View {
    @Environment(AuthFlow.self) private var auth
    @State private var agreed = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Чтобы приложение работало, нужно ваше согласие на обработку персональных данных.")

                    Card {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Что обрабатываем").font(.headline)
                            Text("• Почту — чтобы вы могли войти.")
                            Text("• Имена и даты рождения пары.")
                            Text("• Сведения о здоровье и интимной жизни: цикл, симптомы, настроение, записи о сексе. По закону это особая категория персональных данных.")
                        }
                    }

                    Card {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Как храним").font(.headline)
                            Text("• Записи пары шифруются на телефоне. Ключ есть только у вас двоих, мы прочитать записи не можем.")
                            Text("• Сервер находится в России.")
                            Text("• Согласие можно отозвать в любой момент, удалив аккаунт.")
                        }
                    }

                    Link("Политика конфиденциальности", destination: BackendConfig.privacyPolicyURL)
                        .font(.body.weight(.semibold))

                    Toggle(isOn: $agreed) {
                        Text("Я даю согласие на обработку моих персональных данных, включая сведения о здоровье и интимной жизни, на условиях политики конфиденциальности.")
                    }
                    .toggleStyle(CheckboxToggleStyle())

                    if let error = auth.errorMessage {
                        AuthFooter(error: error, hint: "")
                    }
                }
                .padding(20)
            }
            .background(Palette.background)
            .navigationTitle("Согласие")
            .safeAreaInset(edge: .bottom) {
                GradientButton(title: auth.isWorking ? "Сохраняем…" : "Согласен") {
                    Task { await auth.giveConsent() }
                }
                .disabled(!agreed || auth.isWorking)
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
        .environment(AuthFlow.preview())
}
#endif
