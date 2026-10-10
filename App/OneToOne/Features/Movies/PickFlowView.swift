import Core
import SwiftUI

/// Весь подбор поверх вкладки: настроение → свайпы → совпадение.
/// С уже идущим подбором открывается сразу на колоде.
struct PickFlowView: View {
    @State private var session: PickSession?
    @Environment(\.dismiss) private var dismiss

    init(session: PickSession?) {
        _session = State(initialValue: session)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let session {
                    SwipeDeckView(session: session)
                } else {
                    MoodPickerView { session = $0 }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Закрыть", systemImage: "xmark") { dismiss() }
                }
            }
        }
    }
}
