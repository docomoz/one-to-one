import Core
import DesignSystem
import SwiftUI

/// После входа по коду: партнёр уже вписал вас обоих, здесь человек выбирает себя и при желании поправляет
/// имя и дату рождения. Пол менять нельзя: по нему построена вся пара.
struct ChooseMeView: View {
    @Environment(AppModel.self) private var model
    @State private var draft: PersonDraft?

    var body: some View {
        NavigationStack {
            Group {
                if let couple = model.data.couple {
                    choice(couple)
                } else {
                    loading
                }
            }
            .navigationTitle("Кто ты?")
            .navigationDestination(isPresented: isEditing) {
                PersonFormView(title: "Это ты", draft: draftBinding, buttonTitle: "Готово") { () throws(OnboardingError) in
                    if let draft { try model.claimPerson(draft) }
                }
            }
        }
        // Профиль пары приходит с первой синхронизацией: пока его нет, спрашиваем сервер чаще, чем раз в минуту.
        .task {
            while model.data.couple == nil, !Task.isCancelled {
                await model.syncNow()
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }

    private func choice(_ couple: Couple) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Партнёр уже вписал вас обоих. Выбери себя:")
                .foregroundStyle(.secondary)
            ForEach([couple.woman, couple.man]) { person in
                SexChoiceButton(title: person.name, isSelected: false) {
                    draft = PersonDraft(id: person.id, sex: person.sex, name: person.name, birthDate: person.birthDate)
                }
            }
            Spacer()
            Label(LossWarning.couple, systemImage: "lock.shield")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(20)
    }

    private var loading: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Загружаем записи пары…")
                .foregroundStyle(.secondary)
            if model.syncStatus.lastError != nil {
                Text("Пока не получилось связаться с сервером. Пробуем ещё раз.")
                    .font(.footnote)
                    .foregroundStyle(BrandColor.pink.color)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var isEditing: Binding<Bool> {
        Binding(get: { draft != nil }, set: { if !$0 { draft = nil } })
    }

    private var draftBinding: Binding<PersonDraft> {
        Binding(get: { draft ?? PersonDraft(sex: .male) }, set: { draft = $0 })
    }
}
