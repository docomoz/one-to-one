import Core
import SwiftUI

/// «▬ высокий риск ▬ средний риск» под сеткой календаря, цветами полосок.
/// Низкого в легенде нет: такие дни не отмечаются.
struct RiskLegend: View {
    var body: some View {
        HStack(spacing: 16) {
            item(.high, "высокий риск")
            item(.medium, "средний риск")
        }
        .font(.footnote)
    }

    private func item(_ risk: PregnancyRisk, _ title: String) -> some View {
        Label {
            Text(title)
        } icon: {
            Capsule().fill(risk.markColor ?? .clear)
                .frame(width: 18, height: 5)
        }
    }
}

#Preview {
    RiskLegend()
        .padding()
}
