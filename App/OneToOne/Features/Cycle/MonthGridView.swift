import Core
import DesignSystem
import SwiftUI

/// Сетка месяца: залитые дни — отмеченные месячные, обведённые — прогноз,
/// точка — есть симптомы, мягкая заливка — цвет фазы, полоска — высокий или средний риск беременности. Нажатие выбирает день;
/// без `selected` дни не нажимаются (только просмотр), а обведено «сегодня».
struct MonthGridView: View {
    @Binding var month: Month
    var selected: Binding<DayKey>?
    let today: DayKey
    let periodDays: Set<DayKey>
    var predictedDays: Set<DayKey> = []
    var symptomDays: Set<DayKey> = []
    var phases: [DayKey: CyclePhase] = [:]
    var risks: [DayKey: PregnancyRisk] = [:]

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
                                // Без выбора обводим «сегодня», иначе его легко потерять среди цветных дней.
                                isSelected: day == (selected?.wrappedValue ?? today),
                                isPeriod: periodDays.contains(day),
                                isPredicted: predictedDays.contains(day) && !periodDays.contains(day),
                                hasSymptoms: symptomDays.contains(day),
                                phase: phases[day],
                                risk: risks[day],
                                action: selected.map { binding in { binding.wrappedValue = day } })
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
    let phase: CyclePhase?
    let risk: PregnancyRisk?
    /// `nil` — день не нажимается.
    let action: (() -> Void)?
    @Environment(\.locale) private var locale
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if let action {
            Button(action: action) { content }
                .buttonStyle(.plain)
                .accessibilityLabel(accessibilityText)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
        } else {
            content
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityText)
        }
    }

    private var content: some View {
        // Кольцо выбора выступает на 3 пункта: без запаса оно касается полоски риска.
        VStack(spacing: 6) {
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
            HStack(spacing: 3) {
                // Зелёной полоски нет: «пустой» день не должен выглядеть разрешением.
                RiskMark(color: risk?.markColor)
                Circle()
                    .fill(hasSymptoms ? BrandColor.purple.color : .clear)
                    .frame(width: 5, height: 5)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .background {
            if let tint = phase?.tint(colorScheme) {
                RoundedRectangle(cornerRadius: 10, style: .continuous).fill(tint)
            }
        }
        .contentShape(Rectangle())
    }

    private var accessibilityText: String {
        var parts = [day.date().formatted(.dateTime.day().month(.wide).locale(locale))]
        if isToday { parts.append("сегодня") }
        if isPeriod { parts.append("месячные") }
        if isPredicted { parts.append("прогноз месячных") }
        if let phase, phase != .unknown { parts.append(phase.shortTitle.lowercased()) }
        if hasSymptoms { parts.append("есть симптомы") }
        if let riskText = risk?.dayAccessibility { parts.append(riskText) }
        return parts.joined(separator: ", ")
    }
}
