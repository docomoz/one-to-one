import DesignSystem
import SwiftUI

/// Крупная градиентная цифра «раз в этом месяце». Одна на трекере и на главной, чтобы не разъехались.
struct MonthCounter: View {
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(count)")
                .font(.system(size: 96, weight: .heavy))
                .foregroundStyle(BrandGradient.text)
            Text("раз в этом месяце")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    MonthCounter(count: 12)
}
