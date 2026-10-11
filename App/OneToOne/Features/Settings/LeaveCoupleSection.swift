import SwiftUI

/// «Выйти из пары»: сервер перестаёт отдавать записи пары, с телефона они стираются вместе с ключом,
/// и человек возвращается в знакомство. Новая пара начнётся с нового ключа.
struct LeaveCoupleSection: View {
    @Environment(PairingFlow.self) private var pairing
    @State private var confirms = false

    var body: some View {
        Section {
            Button(pairing.isWorking ? "Выходим…" : "Выйти из пары", role: .destructive) { confirms = true }
                .disabled(pairing.isWorking)
                .confirmationDialog("Выйти из пары?", isPresented: $confirms, titleVisibility: .visible) {
                    Button("Выйти из пары", role: .destructive) {
                        Task { await pairing.leaveCouple() }
                    }
                } message: {
                    Text(pairing.partnerJoined && !pairing.partnerLeft ? Self.coupleMessage : Self.soloMessage)
                }
        }
    }

    static let coupleMessage = "Записи пары сотрутся с этого телефона, вы перестанете видеть правки друг друга. У партнёра записи останутся. Отменить нельзя."
    static let soloMessage = "Записи сотрутся с этого телефона и с сервера. Отменить нельзя."
}
