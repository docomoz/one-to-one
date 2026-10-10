import SwiftUI

extension View {
    /// Зовёт `action` в полночь и при возврате в приложение, чтобы экран пересчитал «сегодня».
    func onDayChange(perform action: @escaping () -> Void) -> some View {
        modifier(DayChangeModifier(action: action))
    }
}

private struct DayChangeModifier: ViewModifier {
    let action: () -> Void
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged).receive(on: RunLoop.main)) { _ in
                action()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { action() }
            }
    }
}
