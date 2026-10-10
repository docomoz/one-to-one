import Core
import DesignSystem
import SwiftUI

/// Два необязательных вопроса при «Классике»: был ли презерватив и куда кончил.
/// Повторное нажатие снимает выбор: ничего не выбрано — «не знаем».
struct ProtectionPicker: View {
    @Binding var condom: Bool?
    @Binding var finish: SexFinish?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            row("Презерватив") {
                chip("Был", of: "Презерватив", isOn: condom == true) { condom = condom == true ? nil : true }
                chip("Не было", of: "Презерватив", isOn: condom == false) { condom = condom == false ? nil : false }
            }
            row("Кончил") {
                ForEach(SexFinish.allCases, id: \.self) { option in
                    chip(option.title, of: "Кончил", isOn: finish == option) {
                        finish = finish == option ? nil : option
                    }
                }
            }
        }
    }

    private func row(_ title: String, @ViewBuilder chips: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            HStack(spacing: 8, content: chips)
        }
    }

    /// VoiceOver читает и вопрос: просто «Был, кнопка» непонятно о чём.
    private func chip(_ title: String, of question: String, isOn: Bool,
                      action: @escaping () -> Void) -> some View {
        ChipButton(title: title, isOn: isOn, compact: true, surface: Palette.background, action: action)
            .accessibilityLabel("\(question): \(title)")
    }
}

#Preview {
    @Previewable @State var condom: Bool? = false
    @Previewable @State var finish: SexFinish?
    Card { ProtectionPicker(condom: $condom, finish: $finish) }
        .padding()
}
