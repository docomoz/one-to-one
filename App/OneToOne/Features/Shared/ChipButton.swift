import DesignSystem
import SwiftUI

/// Кнопка-переключатель: выбранная залита градиентом, остальные — сиреневые.
/// `compact` — поменьше, для длинных списков вроде симптомов.
struct ChipButton: View {
    let title: String
    let isOn: Bool
    var compact = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(compact ? .subheadline : .headline)
                .multilineTextAlignment(.center)
                .foregroundStyle(isOn ? .white : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, compact ? 10 : 18)
                .padding(.horizontal, 8)
                .background {
                    let shape = RoundedRectangle(cornerRadius: compact ? 12 : 16, style: .continuous)
                    if isOn {
                        shape.fill(BrandGradient.primary)
                    } else {
                        shape.fill(Palette.tile)
                    }
                }
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isOn)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
