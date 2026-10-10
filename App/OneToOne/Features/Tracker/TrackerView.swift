import Core
import DesignSystem
import SwiftUI

/// Вкладка «Трекер»: риск беременности на сегодня, статистика, кнопка «Отметить» и список записей.
struct TrackerView: View {
    @Environment(AppModel.self) private var model
    @State private var isLogging = false
    @State private var editing: SexEntry?
    @State private var today = DayKey(.now)

    var body: some View {
        NavigationStack {
            List {
                Section {
                    RiskCard(risk: PregnancyRiskCalculator.risk(on: today, periodDays: model.data.periodDays, today: today))
                        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 8, trailing: 20))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                Section {
                    StatsView(stats: StatsCalculator.stats(model.data.sexEntries, today: today))
                        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 8, trailing: 20))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                if !model.data.sexEntries.isEmpty {
                    Section("Записи") {
                        ForEach(sortedEntries) { entry in
                            Button { editing = entry } label: { EntryRow(entry: entry) }
                                .foregroundStyle(.primary)
                                .swipeActions {
                                    Button("Удалить", systemImage: "trash", role: .destructive) {
                                        model.deleteSex(id: entry.id)
                                    }
                                }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Palette.background)
            .safeAreaInset(edge: .bottom) {
                GradientButton(title: "Отметить") { isLogging = true }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            }
            .navigationTitle("Трекер")
            .sheet(isPresented: $isLogging) { LogSexView(defaults: model.orgasmDefaults) }
            .sheet(item: $editing) { LogSexView(entry: $0) }
            // В полночь и при возврате в приложение пересчитываем «сегодня», иначе серия, месяц и риск застынут.
            .onDayChange { today = DayKey(.now) }
        }
    }

    /// Новые дни сверху, внутри дня — последняя добавленная запись сверху.
    private var sortedEntries: [SexEntry] {
        model.data.sexEntries.reversed().sorted { $0.day > $1.day }
    }
}

/// Строка списка: день, виды и оргазмы.
private struct EntryRow: View {
    let entry: SexEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.day.date(), format: .dateTime.weekday(.wide).day().month(.wide))
                .font(.subheadline.bold())
            Text(SexType.allCases.filter(entry.types.contains).map(\.title).joined(separator: ", "))
                .font(.subheadline)
            Text("Оргазмы: он \(entry.orgasmsMan) · она \(entry.orgasmsWoman)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    TrackerView()
        .environment(AppModel(store: InMemoryStore()))
}
