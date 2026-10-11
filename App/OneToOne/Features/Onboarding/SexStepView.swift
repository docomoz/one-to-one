import Core
import DesignSystem
import SwiftUI

/// Шаг 1: «Кто ты?», две крупные кнопки. Нажатие сразу ведёт дальше.
/// Внизу — вход по коду, если партнёр уже создал пару.
struct SexStepView: View {
    let selected: Sex?
    let onChoose: (Sex) -> Void
    var onJoin: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            SexChoiceButton(title: "Мужчина", isSelected: selected == .male) { onChoose(.male) }
            SexChoiceButton(title: "Женщина", isSelected: selected == .female) { onChoose(.female) }
            Spacer()
            if let onJoin {
                VStack(spacing: 4) {
                    Text("Партнёр уже в one-to-one?")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button("У меня есть код приглашения", action: onJoin)
                        .font(.body.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(20)
        .navigationTitle("Кто ты?")
    }
}

#Preview {
    NavigationStack {
        SexStepView(selected: .female, onChoose: { _ in }, onJoin: {})
    }
}
