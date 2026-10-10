import Core
import DesignSystem
import SwiftUI

/// Вкладка «Главная»: счётчик за месяц, оргазмы и серия, кнопки «Отметить секс» и «Выбрать фильм»,
/// карточка дня и плашка ближайшего дня рождения.
struct HomeView: View {
    /// Что делать по «Выбрать фильм»: открыть подбор (идущий или выбор настроения).
    let pickMovie: () -> Void

    @Environment(AppModel.self) private var model
    @Environment(\.locale) private var locale
    @State private var today = DayKey(.now)
    @State private var isLogging = false

    private let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

    var body: some View {
        let stats = StatsCalculator.stats(model.data.sexEntries, today: today)
        let forecast = CycleCalculator.forecast(periodDays: model.data.periodDays, today: today)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    header(thisMonth: stats.thisMonth)

                    LazyVGrid(columns: columns, spacing: 8) {
                        StatTile(title: "Оргазмы", value: "Он \(stats.orgasmsMan) · Она \(stats.orgasmsWoman)")
                        StatTile(title: "Серия", value: streakText(stats.currentStreak))
                        ActionTile(title: "Отметить секс", systemImage: "heart.fill", colors: [.orange, .pink]) {
                            isLogging = true
                        }
                        ActionTile(title: "Выбрать фильм", systemImage: "film.fill", colors: [.pink, .purple],
                                   action: pickMovie)
                    }

                    DayCard(forecast: forecast, herMood: model.data.herMoods[today], isWoman: model.data.meIsWoman)

                    if let couple = model.data.couple,
                       let birthday = BirthdayCalculator.upcoming(couple: couple, meID: model.data.meID, today: today) {
                        Card {
                            Text(birthday.text)
                                .font(.headline)
                        }
                    }
                }
                .padding(20)
            }
            .background(Palette.background)
            .sheet(isPresented: $isLogging) { LogSexView(defaults: model.orgasmDefaults) }
            // В полночь пересчитываем «сегодня»: месяц, серия, подсказка и дни рождения.
            .onDayChange { today = DayKey(.now) }
            #if DEBUG
            .toolbar {
                NavigationLink("Витрина") { DesignPreview() }
            }
            #endif
        }
    }

    /// «Вы вдвоём · октябрь», большая цифра и «раз в этом месяце».
    private func header(thisMonth: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Вы вдвоём · \(today.date().formatted(.dateTime.month(.wide).locale(locale)))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            MonthCounter(count: thisMonth)
        }
    }

    private func streakText(_ streak: Int) -> String {
        streak > 0 ? "\(daysText(streak)) 🔥" : daysText(0)
    }
}

#Preview("Он") {
    HomeView(pickMovie: {})
        .environment(AppModel(store: InMemoryStore(.homePreview(meIsWoman: false))))
        .environment(\.locale, Locale(identifier: "ru_RU"))
}

#Preview("Она, тёмная") {
    HomeView(pickMovie: {})
        .environment(AppModel(store: InMemoryStore(.homePreview(meIsWoman: true))))
        .environment(\.locale, Locale(identifier: "ru_RU"))
        .preferredColorScheme(.dark)
}
