import DesignSystem
import SwiftUI

/// Плашка с градиентной подписью сверху: «Подсказка дня», «Сегодня».
struct LabeledCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BrandGradient.primary)
                content
            }
        }
    }
}

#Preview {
    LabeledCard(title: "Сегодня") { Text("Овуляция, 14-й день") }
        .padding()
}
