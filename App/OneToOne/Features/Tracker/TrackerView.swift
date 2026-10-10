import Core
import DesignSystem
import SwiftUI

/// Вкладка «Трекер»: статистика, кнопка «Отметить» и список записей.
struct TrackerView: View {
    @Environment(AppModel.self) private var model
    @State private var isLogging = false
    @State private var editing: SexEntry?
    @State private var today = DayKey(.now)

    var body: some View {
        NavigationStack {
            List {
                Section {
                    StatsView(stats: StatsCalculator.stats(model.data.sexEntries, today: today, calendar: .current))
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
            // В полночь пересчитываем «сегодня», иначе серия и месяц застынут до следующей записи.
            .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged).receive(on: RunLoop.main)) { _ in
                today = DayKey(.now)
            }
        }
    }

    private var sortedEntries: [SexEntry] {
        model.data.sexEntries.sorted { $0.date > $1.date }
    }
}

/// Строка списка: дата, виды и оргазмы.
private struct EntryRow: View {
    let entry: SexEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.date, format: .dateTime.day().month(.wide).hour().minute())
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
