import SwiftUI

/// Главная кнопка экрана: во всю ширину, белый текст на фирменном градиенте.
public struct GradientButton: View {
    let title: String
    let action: () -> Void

    public init(title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        Button(title, action: action)
            .buttonStyle(GradientButtonStyle())
    }
}

/// Отдельный стиль, чтобы кнопка темнела при нажатии, как родные кнопки iPhone.
private struct GradientButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(BrandGradient.primary, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    GradientButton(title: "Выбрать фильм") {}
        .padding()
}
