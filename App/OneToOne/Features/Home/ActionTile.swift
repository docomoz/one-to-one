import DesignSystem
import SwiftUI

/// Цветная плитка-кнопка на главной: иконка сверху, подпись снизу.
struct ActionTile: View {
    let title: String
    let systemImage: String
    let colors: [BrandColor]
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.headline)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 96)
        }
        .buttonStyle(ActionTileStyle(colors: colors))
    }
}

/// Темнеет и чуть сжимается при нажатии, как `GradientButton`.
private struct ActionTileStyle: ButtonStyle {
    let colors: [BrandColor]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .padding(12)
            .background(LinearGradient(colors: colors.map(\.color), startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    HStack {
        ActionTile(title: "Отметить секс", systemImage: "heart.fill", colors: [.orange, .pink]) {}
        ActionTile(title: "Выбрать фильм", systemImage: "film.fill", colors: [.pink, .purple]) {}
    }
    .padding()
}
