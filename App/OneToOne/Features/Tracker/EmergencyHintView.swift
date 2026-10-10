import Core
import DesignSystem
import SwiftUI

/// Спокойная карточка после секса без защиты в рискованный день. Запись уже сохранена,
/// «Понятно» просто закрывает шторку. Без дозировок и названий препаратов.
struct EmergencyHintView: View {
    let hint: EmergencyHint
    let done: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "heart.text.square")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text(hint.title)
                    .font(.title2.bold())
                    .accessibilityAddTraits(.isHeader)
                Text(hint.detail)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.top, 40)
        }
        .safeAreaInset(edge: .bottom) {
            GradientButton(title: "Понятно", action: done)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
        }
        .background(Palette.background)
    }
}

#Preview("Внутрь") {
    EmergencyHintView(hint: .strong) {}
}

#Preview("Не внутрь") {
    EmergencyHintView(hint: .soft) {}
}
