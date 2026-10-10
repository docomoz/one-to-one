import Core
import SwiftUI

/// Подсказка дня. Если она угадана по циклу, ниже честная подпись «Это прогноз по циклу».
struct TipCard: View {
    let tip: Tip

    var body: some View {
        LabeledCard(title: "Подсказка дня") {
            Text(tip.text)
                .font(.title3.weight(.semibold))
            if tip.isEstimate {
                Text("Это прогноз по циклу")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    VStack {
        TipCard(tip: Tip(text: "Скорее всего, она хочет. Действуй 😏", isEstimate: true))
        TipCard(tip: Tip(text: "Сегодня лучше не подходить. Серьёзно.", isEstimate: false))
    }
    .padding()
}
