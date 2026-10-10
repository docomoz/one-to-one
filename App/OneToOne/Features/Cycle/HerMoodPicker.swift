import Core
import DesignSystem
import SwiftUI

/// Три кнопки «как я сегодня». Повторное нажатие снимает выбор.
struct HerMoodPicker: View {
    let mood: HerMood?
    let select: (HerMood?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Как я сегодня").font(.headline)
            HStack(spacing: 8) {
                ForEach(HerMood.allCases, id: \.self) { option in
                    ChipButton(title: option.title, isOn: mood == option, compact: true,
                               surface: Palette.background) {
                        select(mood == option ? nil : option)
                    }
                }
            }
        }
    }
}
