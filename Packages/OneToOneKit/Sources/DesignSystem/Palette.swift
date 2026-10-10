import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Фирменные цвета «Яркого градиента» (вариант B из docs/design/visual-style.html).
public enum BrandColor: CaseIterable, Sendable {
    case yellow, orange, pink, purple, blue

    var hex: UInt32 {
        switch self {
        case .yellow: 0xFEDA75
        case .orange: 0xFA7E1E
        case .pink: 0xD62976
        case .purple: 0x962FBF
        case .blue: 0x4F5BD5
        }
    }

    public var color: Color { Color(hex: hex) }
}

/// Цвета поверхностей. Фон экрана берём системный, чтобы тёмная тема работала сама.
public enum Palette {
    static let tileLight: UInt32 = 0xF4F0F7
    static let tileDark: UInt32 = 0x2A2231

    /// Фон экрана: белый в светлой теме, чёрный в тёмной.
    public static var background: Color {
        #if canImport(UIKit)
        Color(uiColor: .systemBackground)
        #else
        Color(nsColor: .windowBackgroundColor)
        #endif
    }

    /// Фон плашек и карточек: светло-сиреневый днём, тёмно-сливовый ночью.
    public static var tile: Color { adaptive(light: tileLight, dark: tileDark) }

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        #if canImport(UIKit)
        Color(uiColor: UIColor { traits in
            UIColor(Color(hex: traits.userInterfaceStyle == .dark ? dark : light))
        })
        #else
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(Color(hex: isDark ? dark : light))
        })
        #endif
    }
}

extension Color {
    init(hex: UInt32) {
        let rgb = RGB(hex: hex)
        self.init(.sRGB, red: rgb.red, green: rgb.green, blue: rgb.blue)
    }
}
