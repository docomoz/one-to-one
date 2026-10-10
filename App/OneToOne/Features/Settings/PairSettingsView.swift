import Core
import SwiftUI

/// Экран «Пара»: с какого дня вы вместе. Дата сохраняется сразу, по ней строится плашка годовщины.
struct PairSettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Form {
            Section {
                DateRow(title: "Вместе с", date: togetherSince, initial: DayKey(.now))
            }
            if model.data.togetherSince != nil {
                Section {
                    Button("Убрать дату", role: .destructive) {
                        model.setTogetherSince(nil)
                    }
                }
            }
        }
        .navigationTitle("Пара")
    }

    private var togetherSince: Binding<DayKey?> {
        Binding(
            get: { model.data.togetherSince },
            set: { model.setTogetherSince($0) }
        )
    }
}

#Preview {
    NavigationStack {
        PairSettingsView()
    }
    .environment(AppModel(store: InMemoryStore(.homePreview(meIsWoman: false))))
    .environment(\.locale, Locale(identifier: "ru_RU"))
}
