import Core
import DesignSystem
import SwiftUI

/// Симптомы дня: готовые и свои. «+ Своё» добавляет новый симптом текстом.
struct SymptomPicker: View {
    let selected: Set<Symptom>
    let customSymptoms: [String]
    let toggle: (Symptom) -> Void
    let addCustom: (String) -> Void

    @State private var isAddingCustom = false
    @State private var customText = ""

    private let columns = [GridItem(.adaptive(minimum: 140), spacing: 8)]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Симптомы").font(.headline)
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(options, id: \.self) { symptom in
                    ChipButton(title: symptom.title, isOn: selected.contains(symptom), compact: true,
                               surface: Palette.background) {
                        toggle(symptom)
                    }
                }
                ChipButton(title: "+ Своё", isOn: false, compact: true,
                               surface: Palette.background) { isAddingCustom = true }
            }
        }
        .alert("Свой симптом", isPresented: $isAddingCustom) {
            TextField("Например, хочу сладкого", text: $customText)
            Button("Добавить") {
                addCustom(customText)
                customText = ""
            }
            Button("Отмена", role: .cancel) { customText = "" }
        }
    }

    /// Готовые, потом свои, которые она уже когда-то ставила.
    private var options: [Symptom] {
        PresetSymptom.allCases.map(Symptom.preset) + customSymptoms.map(Symptom.custom)
    }
}
