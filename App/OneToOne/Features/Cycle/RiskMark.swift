import SwiftUI

/// Короткая полоска риска: под числом дня в календаре и в легенде.
struct RiskMark: View {
    let color: Color

    var body: some View {
        Capsule()
            .fill(color)
            .frame(width: 14, height: 4)
            .accessibilityHidden(true)
    }
}
