import Core
import DesignSystem
import SwiftUI

/// Отметка секса за 3 касания: открыть, выбрать вид, «Сохранить».
/// Если передать `entry`, экран правит эту запись и умеет её удалить.
struct LogSexView: View {
    let entry: SexEntry?

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var types: Set<SexType>
    @State private var orgasmsMan: Int
    @State private var orgasmsWoman: Int
    @State private var date: Date
    @State private var isConfirmingDelete = false

    /// Новая запись: виды не выбраны, оргазмы как в прошлый раз, день — сегодня.
    init(defaults: OrgasmDefaults) {
        entry = nil
        _types = State(initialValue: [])
        _orgasmsMan = State(initialValue: defaults.man)
        _orgasmsWoman = State(initialValue: defaults.woman)
        _date = State(initialValue: .now)
    }

    /// Правка записи: форма сразу заполнена её значениями.
    init(entry: SexEntry) {
        self.entry = entry
        _types = State(initialValue: entry.types)
        _orgasmsMan = State(initialValue: entry.orgasmsMan)
        _orgasmsWoman = State(initialValue: entry.orgasmsWoman)
        _date = State(initialValue: entry.day.date())
    }

    private let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(SexType.allCases, id: \.self) { type in
                            ChipButton(title: type.title, isOn: types.contains(type)) {
                                types.formSymmetricDifference([type])
                            }
                        }
                    }

                    Card {
                        VStack(spacing: 4) {
                            Stepper("Оргазмы у него: \(orgasmsMan)", value: $orgasmsMan, in: 0...20)
                            Divider()
                            Stepper("Оргазмы у неё: \(orgasmsWoman)", value: $orgasmsWoman, in: 0...20)
                        }
                    }

                    Card {
                        DatePicker("Когда", selection: $date, in: ...Date.now, displayedComponents: .date)
                    }

                    if entry != nil {
                        Button("Удалить запись", role: .destructive) { isConfirmingDelete = true }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 8)
                    }
                }
                .padding(20)
            }
            .safeAreaInset(edge: .bottom) {
                GradientButton(title: "Сохранить", action: save)
                    .disabled(types.isEmpty)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            }
            .background(Palette.background)
            .navigationTitle(entry == nil ? "Отметить" : "Запись")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена", role: .cancel) { dismiss() }
                }
            }
            .confirmationDialog("Удалить запись?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
                Button("Удалить", role: .destructive, action: delete)
            }
        }
    }

    private func save() {
        if var edited = entry {
            edited.types = types
            edited.orgasmsMan = orgasmsMan
            edited.orgasmsWoman = orgasmsWoman
            edited.day = DayKey(date)
            model.updateSex(edited)
        } else {
            model.logSex(types: types, orgasmsMan: orgasmsMan, orgasmsWoman: orgasmsWoman, day: DayKey(date))
        }
        dismiss()
    }

    private func delete() {
        guard let entry else { return }
        model.deleteSex(id: entry.id)
        dismiss()
    }
}

#Preview("Новая") {
    LogSexView(defaults: OrgasmDefaults(man: 1, woman: 1))
        .environment(AppModel(store: InMemoryStore()))
}
