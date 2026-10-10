import Core
import SwiftUI

/// Шаг 1: «Кто ты?», две крупные кнопки. Нажатие сразу ведёт дальше.
struct SexStepView: View {
    let selected: Sex?
    let onChoose: (Sex) -> Void

    var body: some View {
        VStack(spacing: 12) {
            SexChoiceButton(title: "Мужчина", isSelected: selected == .male) { onChoose(.male) }
            SexChoiceButton(title: "Женщина", isSelected: selected == .female) { onChoose(.female) }
            Spacer()
        }
        .padding(20)
        .navigationTitle("Кто ты?")
    }
}

#Preview {
    NavigationStack {
        SexStepView(selected: .female) { _ in }
    }
}
