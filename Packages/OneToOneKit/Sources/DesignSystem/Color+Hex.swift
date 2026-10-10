import SwiftUI

/// Перевод hex-кода вроде 0xFA7E1E в доли красного, зелёного и синего (0…1).
struct RGB: Equatable {
    let red: Double
    let green: Double
    let blue: Double

    init(hex: UInt32) {
        red = Double((hex >> 16) & 0xFF) / 255
        green = Double((hex >> 8) & 0xFF) / 255
        blue = Double(hex & 0xFF) / 255
    }
}

extension Color {
    init(hex: UInt32) {
        let rgb = RGB(hex: hex)
        self.init(.sRGB, red: rgb.red, green: rgb.green, blue: rgb.blue)
    }
}
