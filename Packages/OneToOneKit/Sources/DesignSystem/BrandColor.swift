import SwiftUI

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
