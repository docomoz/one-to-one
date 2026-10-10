import SwiftUI

struct TrackerView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView("Скоро здесь что-то будет", systemImage: "heart")
                .navigationTitle("Трекер")
        }
    }
}

#Preview {
    TrackerView()
}
