import SwiftUI

/// Фирменный градиент слева направо.
public enum BrandGradient {
    static let primaryStops: [BrandColor] = [.orange, .pink, .purple]
    static let textStops: [BrandColor] = [.yellow, .orange, .pink, .purple, .blue]

    /// Для кнопок и акцентных плашек: оранжевый → розовый → фиолетовый.
    public static var primary: LinearGradient { linear(primaryStops) }

    /// Для крупных цифр: вся радуга Instagram, от жёлтого до синего.
    public static var text: LinearGradient { linear(textStops) }

    private static func linear(_ stops: [BrandColor]) -> LinearGradient {
        LinearGradient(colors: stops.map(\.color), startPoint: .leading, endPoint: .trailing)
    }
}
