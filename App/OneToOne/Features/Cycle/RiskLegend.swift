import Core
import SwiftUI

/// Строка под календарём: какие полоски что значат. Низкого риска тут нет, у него полоски нет.
struct RiskLegend: View {
    var body: some View {
        HStack(spacing: 16) {
            item(.high, "высокий риск")
            item(.medium, "средний риск")
        }
        .font(.footnote)
    }

    private func item(_ risk: PregnancyRisk, _ title: String) -> some View {
        HStack(spacing: 6) {
            RiskMark(color: risk.markColor)
            Text(title)
        }
    }
}

/// Короткая полоска риска: под числом дня в календаре и в легенде.
struct RiskMark: View {
    let color: Color?

    var body: some View {
        Capsule()
            .fill(color ?? .clear)
            .frame(width: 14, height: 4)
            .accessibilityHidden(true)
    }
}

#Preview {
    RiskLegend()
        .padding()
}
