import Core
import DesignSystem
import SwiftUI

/// Сетка месяца: залитые дни — отмеченные месячные, обведённые — прогноз,
/// точка — есть симптомы. Нажатие выбирает день.
struct MonthGridView: View {
    @Binding var month: Month
    @Binding var selected: DayKey
    let today: DayKey
    let periodDays: Set<DayKey>
    let predictedDays: Set<DayKey>
    let symptomDays: Set<DayKey>

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    private let weekdays = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button("Предыдущий месяц", systemImage: "chevron.left") { month = month.adding(months: -1) }
                Spacer()
                Text(month.title).font(.headline)
                Spacer()
                Button("Следующий месяц", systemImage: "chevron.right") { month = month.adding(months: 1) }
            }
            .labelStyle(.iconOnly)

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(weekdays, id: \.self) { name in
                    Text(name).font(.caption).foregroundStyle(.secondary)
                }
                ForEach(Array(month.cells.enumerated()), id: \.offset) { _, day in
                    if let day {
                        DayCell(day: day,
                                isToday: day == today,
                                isSelected: day == selected,
                                isPeriod: periodDays.contains(day),
                                isPredicted: predictedDays.contains(day) && !periodDays.contains(day),
                                hasSymptoms: symptomDays.contains(day)) {
                            selected = day
                        }
                    } else {
                        Color.clear.frame(height: 44)
                    }
                }
            }
        }
    }
}

private struct DayCell: View {
    let day: DayKey
    let isToday: Bool
    let isSelected: Bool
    let isPeriod: Bool
    let isPredicted: Bool
    let hasSymptoms: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text("\(day.day)")
                    .font(.callout.weight(isToday ? .bold : .regular))
                    .foregroundStyle(isPeriod ? .white : .primary)
                    .frame(width: 34, height: 34)
                    .background {
                        if isPeriod {
                            Circle().fill(BrandGradient.primary)
                        } else if isPredicted {
                            Circle().strokeBorder(BrandGradient.primary, style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
                        }
                    }
                    .overlay {
                        if isSelected {
                            Circle().strokeBorder(.primary, lineWidth: 2).padding(-3)
                        }
                    }
                Circle()
                    .fill(hasSymptoms ? BrandColor.purple.color : .clear)
                    .frame(width: 5, height: 5)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var accessibilityText: String {
        var parts = [day.date().formatted(.dateTime.day().month(.wide))]
        if isToday { parts.append("сегодня") }
        if isPeriod { parts.append("месячные") }
        if isPredicted { parts.append("прогноз месячных") }
        if hasSymptoms { parts.append("есть симптомы") }
        return parts.joined(separator: ", ")
    }
}
