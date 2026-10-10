import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Цвета поверхностей. Фон экрана берём системный, чтобы тёмная тема работала сама.
public enum Palette {
    static let tileLight: UInt32 = 0xF4F0F7
    static let tileDark: UInt32 = 0x2A2231

    /// Фон экрана: системный фон, на iPhone белый в светлой теме и чёрный в тёмной.
    public static var background: Color {
        #if canImport(UIKit)
        Color(uiColor: .systemBackground)
        #else
        Color(nsColor: .windowBackgroundColor)
        #endif
    }

    /// Фон плашек и карточек: светло-сиреневый днём, тёмно-сливовый ночью.
    public static var tile: Color { adaptive(tileHex) }

    static func tileHex(isDark: Bool) -> UInt32 {
        isDark ? tileDark : tileLight
    }

    /// Цвет, который сам перекрашивается при смене темы.
    private static func adaptive(_ hex: @escaping @Sendable (_ isDark: Bool) -> UInt32) -> Color {
        #if canImport(UIKit)
        Color(uiColor: UIColor { traits in
            UIColor(Color(hex: hex(traits.userInterfaceStyle == .dark)))
        })
        #else
        Color(nsColor: NSColor(name: nil) { appearance in
            NSColor(Color(hex: hex(appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua)))
        })
        #endif
    }
}
