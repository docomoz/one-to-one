import Core
import DesignSystem
import SwiftUI

/// Вкладка «Цикл» для него: подсказка дня и календарь, где каждый день закрашен цветом фазы,
/// а дни высокого и среднего риска беременности отмечены полоской.
/// Только просмотр: без её настроения по дням и без симптомов.
struct HisCalendarView: View {
    @Environment(AppModel.self) private var model
    @State private var today = DayKey(.now)
    @State private var month = Month(DayKey(.now))

    var body: some View {
        let periodDays = model.data.periodDays
        let forecast = CycleCalculator.forecast(periodDays: periodDays, today: today)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    TipCard(tip: TipProvider.tip(forecast: forecast, herMood: model.data.herMoods[today]))

                    MonthGridView(month: $month, today: today, periodDays: periodDays,
                                  phases: phases(in: month, periodDays: periodDays),
                                  risks: PregnancyRiskCalculator.risks(in: month, periodDays: periodDays, today: today))

                    PhaseLegend()
                    RiskLegend()
                }
                .padding(20)
            }
            .background(Palette.background)
            .navigationTitle("Цикл")
            .onDayChange {
                let now = DayKey(.now)
                guard now != today else { return }
                if month == Month(today) { month = Month(now) }
                today = now
            }
        }
    }

    private func phases(in month: Month, periodDays: Set<DayKey>) -> [DayKey: CyclePhase] {
        let days = month.cells.compactMap { $0 }
        return Dictionary(uniqueKeysWithValues: days.map { ($0, CycleCalculator.phase(on: $0, periodDays: periodDays)) })
    }
}

/// Какой цвет какой фазе соответствует.
private struct PhaseLegend: View {
    private let phases: [CyclePhase] = [.menstruation, .follicular, .ovulation, .luteal]
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// При крупном шрифте «Фолликулярная» в полколонки рвётся посреди слова, поэтому одна колонка.
    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), alignment: .leading), count: dynamicTypeSize.isAccessibilitySize ? 1 : 2)
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(phases, id: \.self) { phase in
                Label {
                    Text(phase.shortTitle)
                } icon: {
                    RoundedRectangle(cornerRadius: 5, style: .continuous).fill(phase.tint(colorScheme) ?? .clear)
                        .frame(width: 18, height: 18)
                }
                .font(.footnote)
            }
        }
    }
}

#Preview("Крупный шрифт") {
    var data = AppData()
    let today = DayKey(.now)
    data.periodDays = Set((0..<5).map { today.adding(days: -12 + $0) })
    return HisCalendarView()
        .environment(AppModel(store: InMemoryStore(data)))
        .dynamicTypeSize(.accessibility3)
}

#Preview {
    var data = AppData()
    let today = DayKey(.now)
    data.periodDays = Set((0..<5).map { today.adding(days: -12 + $0) })
    return HisCalendarView()
        .environment(AppModel(store: InMemoryStore(data)))
}
