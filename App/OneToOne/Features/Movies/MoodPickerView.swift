import Core
import DesignSystem
import SwiftUI

/// Шаг 1 подбора: одно настроение на двоих.
struct MoodPickerView: View {
    let onStart: (PickSession) -> Void
    @Environment(AppModel.self) private var model
    @State private var mood: Mood?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Договоритесь вслух и выберите одно на двоих.")
                    .foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(Mood.allCases, id: \.self) { item in
                        ChipButton(title: "\(item.emoji)\n\(item.title)", isOn: mood == item) {
                            mood = item
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(Palette.background)
        .navigationTitle("Какое настроение?")
        .safeAreaInset(edge: .bottom) {
            GradientButton(title: "Свайпать") {
                if let mood, let session = model.startPick(mood: mood) { onStart(session) }
            }
            .disabled(mood == nil)
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
    }
}

#Preview {
    NavigationStack {
        MoodPickerView { _ in }
    }
    .environment(AppModel(store: InMemoryStore()))
}
