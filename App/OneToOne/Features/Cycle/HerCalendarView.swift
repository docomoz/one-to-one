import Core
import DesignSystem
import SwiftUI

/// Вкладка «Цикл» для неё: фаза и прогноз, сетка месяца и карточка выбранного дня.
struct HerCalendarView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.locale) private var locale
    @State private var today = DayKey(.now)
    @State private var selected = DayKey(.now)
    @State private var month = Month(DayKey(.now))

    var body: some View {
        let forecast = CycleCalculator.forecast(periodDays: model.data.periodDays, today: today)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Card { ForecastSummary(forecast: forecast) }

                    MonthGridView(month: $month, selected: $selected, today: today,
                                  periodDays: model.data.periodDays,
                                  predictedDays: forecast.predictedPeriodDays,
                                  symptomDays: Set(model.data.symptoms.keys),
                                  risks: PregnancyRiskCalculator.risks(in: month, periodDays: model.data.periodDays, today: today))

                    RiskLegend()

                    Card { dayCard }
                }
                .padding(20)
            }
            .background(Palette.background)
            .navigationTitle("Цикл")
            // Без пересчёта «сегодня» фаза и прогноз застынут.
            .onDayChange(perform: refreshToday)
        }
    }

    /// Если был выбран старый «сегодня», переходим на новый вместе с месяцем.
    private func refreshToday() {
        let now = DayKey(.now)
        guard now != today else { return }
        if selected == today {
            selected = now
            month = Month(now)
        }
        today = now
    }

    private var dayCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(selected == today ? "Сегодня" : selected.date().formatted(.dateTime.weekday(.wide).day().month(.wide).locale(locale)))
                .font(.title3.bold())

            // Для любого дня, будущего — по прогнозу.
            let risk = PregnancyRiskCalculator.risk(on: selected, periodDays: model.data.periodDays, today: today)
            Text("Риск беременности: \(risk.shortTitle)")
                .font(.subheadline)

            if selected <= today {
                Toggle("Месячные", isOn: Binding(
                    get: { model.data.periodDays.contains(selected) },
                    set: { _ in model.togglePeriodDay(selected) }))
                    .font(.headline)
                    .tint(BrandColor.pink.color)
            }

            if selected == today {
                HerMoodPicker(mood: model.data.herMoods[today]) { model.setHerMood($0, for: today) }
            }

            SymptomPicker(selected: model.data.symptoms[selected] ?? [],
                          customSymptoms: model.data.customSymptoms,
                          toggle: { model.toggleSymptom($0, on: selected) },
                          addCustom: { model.addCustomSymptom($0, on: selected) })
        }
    }
}

/// «Сегодня: фолликулярная фаза, 10-й день» и «Месячные ≈ 29 октября».
private struct ForecastSummary: View {
    let forecast: CycleForecast
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let dayOfCycle = forecast.dayOfCycle, let next = forecast.nextPeriodStart {
                Text("Сегодня: \(forecast.phase.title), \(dayOfCycle)-й день")
                    .font(.headline)
                Text("Месячные ≈ \(next.date().formatted(.dateTime.day().month(.wide).locale(locale)))")
                    .foregroundStyle(.secondary)
            } else {
                Text("Отметь первый день месячных, и тут появится прогноз")
                    .font(.headline)
            }
        }
    }
}

#Preview {
    var data = AppData()
    let today = DayKey(.now)
    data.periodDays = Set((0..<5).map { today.adding(days: -12 + $0) })
    data.symptoms = [today.adding(days: -11): [.preset(.cramps)]]
    return HerCalendarView()
        .environment(AppModel(store: InMemoryStore(data)))
}
