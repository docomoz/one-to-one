import SwiftUI

/// Плашка с подписью и значением: «Оргазмы · М 14 · Д 11».
public struct StatTile: View {
    let title: String
    let value: String

    public init(title: String, value: String) {
        self.title = title
        self.value = value
    }

    public var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline.bold())
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    HStack {
        StatTile(title: "Оргазмы", value: "М 14 · Д 11")
        StatTile(title: "Сегодня", value: "Скорее да 😏")
    }
    .padding()
}
