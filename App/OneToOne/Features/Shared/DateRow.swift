import Core
import SwiftUI

/// Строка с датой («Дата рождения», «Вместе с»). Пока дата не выбрана, показывает «Выбрать».
/// Нажатие раскрывает колёсики и сразу выбирает `initial`, чтобы строка и колёсики совпадали.
struct DateRow: View {
    let title: String
    @Binding var date: DayKey?
    /// Дата, которую строка ставит при первом нажатии.
    let initial: DayKey
    @State private var isPicking = false
    @Environment(\.locale) private var locale

    var body: some View {
        Button {
            if date == nil {
                date = initial
            }
            withAnimation { isPicking.toggle() }
        } label: {
            LabeledContent(title) {
                Text(date.map { $0.date().formatted(.dateTime.day().month(.wide).year().locale(locale)) } ?? "Выбрать")
                    .foregroundStyle(date == nil ? Color.accentColor : .secondary)
            }
        }
        .tint(.primary)

        if isPicking {
            DatePicker(title, selection: selection, in: range, displayedComponents: .date)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)
        }
    }

    private var selection: Binding<Date> {
        Binding(
            get: { (date ?? DayKey(.now)).date() },
            set: { date = DayKey($0) }
        )
    }

    private var range: ClosedRange<Date> {
        DayKey(year: 1900, month: 1, day: 1).date()...Date.now
    }
}
