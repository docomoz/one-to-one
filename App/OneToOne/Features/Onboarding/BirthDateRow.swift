import Core
import SwiftUI

/// Строка «Дата рождения». Пока дата не выбрана, показывает «Выбрать».
/// Нажатие раскрывает колёсики; дата записывается, только когда их покрутили.
struct BirthDateRow: View {
    @Binding var date: DayKey?
    @State private var isPicking = false
    @Environment(\.locale) private var locale

    var body: some View {
        Button {
            withAnimation { isPicking.toggle() }
        } label: {
            LabeledContent("Дата рождения") {
                Text(date.map { $0.date().formatted(.dateTime.day().month(.wide).year().locale(locale)) } ?? "Выбрать")
                    .foregroundStyle(date == nil ? Color.accentColor : .secondary)
            }
        }
        .tint(.primary)

        if isPicking {
            DatePicker("Дата рождения", selection: selection, in: range, displayedComponents: .date)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)
        }
    }

    private var selection: Binding<Date> {
        Binding(
            get: { (date ?? DayKey(year: DayKey(.now).year - 25, month: 1, day: 1)).date() },
            set: { date = DayKey($0) }
        )
    }

    private var range: ClosedRange<Date> {
        DayKey(year: 1900, month: 1, day: 1).date()...Date.now
    }
}
