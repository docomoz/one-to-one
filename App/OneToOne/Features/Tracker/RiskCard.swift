import Core
import SwiftUI

/// Плашка «Сегодня» вверху трекера: риск забеременеть сегодня и честная приписка про календарь.
struct RiskCard: View {
    let risk: PregnancyRisk

    var body: some View {
        LabeledCard(title: "Сегодня") {
            HStack(spacing: 8) {
                Circle()
                    .fill(risk.dotColor)
                    .frame(width: 10, height: 10)
                    .accessibilityHidden(true)
                Text(risk.title)
                    .font(.headline)
            }
            Text(risk.detail)
                .font(.subheadline)
            Text("Календарь не защищает на 100%. От инфекций защищает только презерватив.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ScrollView {
        VStack {
            RiskCard(risk: .high)
            RiskCard(risk: .medium)
            RiskCard(risk: .late)
            RiskCard(risk: .low)
            RiskCard(risk: .unknown)
        }
        .padding()
    }
}
