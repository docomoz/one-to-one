import Core
import SwiftUI

/// Строка под календарём: какие полоски что значат. Низкого риска тут нет, у него полоски нет.
struct RiskLegend: View {
    var body: some View {
        // При крупном шрифте в строку не влезает — ставим друг под другом.
        ViewThatFits {
            HStack(spacing: 16) { items }
            VStack(alignment: .leading, spacing: 6) { items }
        }
        .font(.footnote)
    }

    @ViewBuilder private var items: some View {
        item(.high, "высокий риск")
        item(.medium, "средний риск")
    }

    private func item(_ risk: PregnancyRisk, _ title: String) -> some View {
        HStack(spacing: 6) {
            RiskMark(color: risk.markColor ?? .clear)
            Text(title)
        }
    }
}

#Preview {
    RiskLegend()
        .padding()
}
