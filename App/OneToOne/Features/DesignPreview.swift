#if DEBUG
import DesignSystem
import SwiftUI

/// Витрина дизайн-системы: главный экран варианта B и все цвета. Есть только в отладочной сборке.
struct DesignPreview: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Вы вдвоём · октябрь")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("12")
                    .font(.system(size: 96, weight: .heavy))
                    .foregroundStyle(BrandGradient.text)
                Text("раз в этом месяце")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    StatTile(title: "Оргазмы", value: "М 14 · Д 11")
                    StatTile(title: "Сегодня", value: "Скорее да 😏")
                }
                GradientButton(title: "Выбрать фильм") {}
                    .padding(.top, 8)

                Text("Цвета")
                    .font(.headline)
                    .padding(.top, 24)
                HStack(spacing: 8) {
                    ForEach(BrandColor.allCases, id: \.self) { brand in
                        Circle().fill(brand.color).frame(width: 44, height: 44)
                    }
                }
                Card {
                    Text("Card: сюда кладём любое содержимое")
                }
            }
            .padding(20)
        }
        .background(Palette.background)
        .navigationTitle("Витрина")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Светлая") {
    NavigationStack { DesignPreview() }
}

#Preview("Тёмная") {
    NavigationStack { DesignPreview() }
        .preferredColorScheme(.dark)
}
#endif
