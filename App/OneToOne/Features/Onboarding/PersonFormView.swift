import Core
import DesignSystem
import SwiftUI

/// Шаги 2 и 3: имя и дата рождения. Если передан `onSexPicked`, сверху ещё выбор пола (для партнёра).
struct PersonFormView: View {
    let title: String
    @Binding var draft: PersonDraft
    let buttonTitle: String
    var onSexPicked: (() -> Void)?
    let onSubmit: () throws(OnboardingError) -> Void

    @State private var error: OnboardingError?

    var body: some View {
        Form {
            if let onSexPicked {
                Section {
                    Picker("Пол", selection: Binding(
                        get: { draft.sex },
                        set: { draft.sex = $0; onSexPicked() }
                    )) {
                        Text("Мужчина").tag(Sex.male)
                        Text("Женщина").tag(Sex.female)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
            }
            Section {
                TextField("Имя", text: $draft.name)
                    .textContentType(.givenName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                BirthDateRow(date: $draft.birthDate)
            } footer: {
                if let error {
                    Text(error.message)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(BrandColor.pink.color)
                }
            }
        }
        .navigationTitle(title)
        .safeAreaInset(edge: .bottom) {
            GradientButton(title: buttonTitle, action: submit)
                .disabled(!draft.isFilled)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
        }
        .onChange(of: draft) { error = nil }
    }

    private func submit() {
        do {
            try onSubmit()
        } catch {
            self.error = error
        }
    }
}

#Preview {
    @Previewable @State var draft = PersonDraft(sex: .male, name: "Максим")
    NavigationStack {
        PersonFormView(title: "Партнёр", draft: $draft, buttonTitle: "Создать пару", onSexPicked: {}) { () throws(OnboardingError) in
            throw .sameSex
        }
    }
}
