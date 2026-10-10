import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView("Скоро здесь что-то будет", systemImage: "house")
                .navigationTitle("Главная")
                #if DEBUG
                .toolbar {
                    NavigationLink("Витрина") { DesignPreview() }
                }
                #endif
        }
    }
}

#Preview {
    HomeView()
}
