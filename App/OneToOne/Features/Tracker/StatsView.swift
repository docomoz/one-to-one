import Core
import DesignSystem
import SwiftUI

/// Счётчики трекера: крупная цифра за месяц и плашки со всем остальным.
struct StatsView: View {
    let stats: Stats

    private let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                Text("\(stats.thisMonth)")
                    .font(.system(size: 96, weight: .heavy))
                    .foregroundStyle(BrandGradient.text)
                Text("раз в этом месяце")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)

            LazyVGrid(columns: columns, spacing: 8) {
                StatTile(title: "Серия, дней", value: "\(stats.currentStreak)")
                StatTile(title: "Лучшая серия", value: "\(stats.bestStreak)")
                StatTile(title: "Оргазмы", value: "Он \(stats.orgasmsMan) · Она \(stats.orgasmsWoman)")
                StatTile(title: "Всего", value: "\(stats.total)")
            }

            Card {
                VStack(alignment: .leading, spacing: 6) {
                    Text("По видам")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(SexType.allCases, id: \.self) { type in
                        HStack {
                            Text(type.title)
                            Spacer()
                            Text("\(stats.typeCounts[type, default: 0])")
                                .bold()
                                .monospacedDigit()
                        }
                        .font(.subheadline)
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }
}

#Preview {
    StatsView(stats: Stats(total: 42, thisMonth: 12, orgasmsMan: 14, orgasmsWoman: 11,
                           typeCounts: [.vaginal: 10, .anal: 1, .cunnilingus: 6, .blowjob: 5],
                           currentStreak: 3, bestStreak: 5))
        .padding()
}
