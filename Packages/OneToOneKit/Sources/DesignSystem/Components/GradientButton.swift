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
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(BrandGradient.primary, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .opacity(opacity(isPressed: configuration.isPressed))
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }

    private func opacity(isPressed: Bool) -> Double {
        if !isEnabled { return 0.4 }
        return isPressed ? 0.8 : 1
    }
}

#Preview {
    VStack {
        GradientButton(title: "Выбрать фильм") {}
        GradientButton(title: "Недоступна") {}
            .disabled(true)
    }
    .padding()
}
