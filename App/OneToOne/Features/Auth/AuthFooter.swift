import DesignSystem
import SwiftUI

/// Подпись под полем на экранах входа: ошибка розовым или серая подсказка.
struct AuthFooter: View {
    let error: String?
    let hint: String

    var body: some View {
        if let error {
            Text(error)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(BrandColor.pink.color)
        } else {
            Text(hint)
        }
    }
}
