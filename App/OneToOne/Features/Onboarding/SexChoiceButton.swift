import DesignSystem
import SwiftUI

/// Крупная кнопка выбора пола: сиреневая плашка, выбранная — на фирменном градиенте.
struct SexChoiceButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.title3.bold())
                .foregroundStyle(isSelected ? .white : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .background {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(isSelected ? AnyShapeStyle(BrandGradient.primary) : AnyShapeStyle(Palette.tile))
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    VStack {
        SexChoiceButton(title: "Мужчина", isSelected: false) {}
        SexChoiceButton(title: "Женщина", isSelected: true) {}
    }
    .padding()
}
