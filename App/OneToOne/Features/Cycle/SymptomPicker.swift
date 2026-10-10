import Core
import SwiftUI

/// Симптомы дня: готовые и свои. «+ Своё» добавляет новый симптом текстом.
struct SymptomPicker: View {
    let selected: Set<Symptom>
    let customSymptoms: [String]
    let toggle: (Symptom) -> Void

    @State private var isAddingCustom = false
    @State private var customText = ""

    private let columns = [GridItem(.adaptive(minimum: 140), spacing: 8)]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Симптомы").font(.headline)
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(options, id: \.self) { symptom in
                    ChipButton(title: symptom.title, isOn: selected.contains(symptom), compact: true) {
                        toggle(symptom)
                    }
                }
                ChipButton(title: "+ Своё", isOn: false, compact: true) { isAddingCustom = true }
            }
        }
        .alert("Свой симптом", isPresented: $isAddingCustom) {
            TextField("Например, хочу сладкого", text: $customText)
            Button("Добавить") {
                toggle(.custom(customText))
                customText = ""
            }
            Button("Отмена", role: .cancel) { customText = "" }
        }
    }

    /// Готовые, потом свои из прошлых дней, потом свои, которые стоят только на этом дне.
    private var options: [Symptom] {
        let presets = PresetSymptom.allCases.map(Symptom.preset)
        let customs = Set(customSymptoms).union(selected.compactMap { symptom -> String? in
            if case .custom(let text) = symptom { text } else { nil }
        })
        return presets + customs.sorted().map(Symptom.custom)
    }
}
