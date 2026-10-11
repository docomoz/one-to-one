#if DEBUG
import Core
import Sync
import SwiftUI
import UIKit

/// Отладка синхронизации без приглашения: ввести id пары (команда Appwrite) и общий ключ на двух симуляторах,
/// запустить, посмотреть состояние. Есть только в отладочной сборке.
struct DebugSyncView: View {
    @Environment(AppModel.self) private var model
    @State private var coupleID = ""
    @State private var keyHex = ""
    @State private var isStarted = false
    @State private var unsent: Int?
    @State private var inputError: String?

    var body: some View {
        Form {
            Section {
                TextField("id пары (id команды в Appwrite)", text: $coupleID)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Ключ пары: 64 hex-цифры", text: $keyHex, axis: .vertical)
                    .font(.footnote.monospaced())
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("Новый ключ") { keyHex = DebugSyncSettings.hex(CoupleKey()) }
                Button("Скопировать ключ") { UIPasteboard.general.string = keyHex }
                    .disabled(keyHex.isEmpty)
            } footer: {
                Text(inputError ?? "На обоих симуляторах один id пары и один ключ. Оба аккаунта — в команде с этим id.")
                    .foregroundStyle(inputError == nil ? Color.secondary : Color.red)
            }

            Section {
                Button("Запустить синхронизацию", action: start)
                Button("Синхронизировать сейчас") { Task { await syncNow() } }
                    .disabled(!isStarted)
                Button("Остановить", role: .destructive, action: stop)
                    .disabled(!isStarted)
            }

            Section("Состояние") {
                LabeledContent("Запущена", value: isStarted ? "да" : "нет")
                LabeledContent("Идёт", value: model.syncStatus.isSyncing ? "да" : "нет")
                LabeledContent("Последняя удачная", value: model.syncStatus.lastSuccess?
                    .formatted(date: .omitted, time: .standard) ?? "—")
                LabeledContent("Не отправлено записей", value: unsent.map(String.init) ?? "—")
                if let error = model.syncStatus.lastError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            // Второй телефон получает пару с сервера, но не знает, кто он в ней (в настоящем входе по коду — ChooseMeView).
            if let couple = model.data.couple, !model.data.isPaired {
                Section("Кто я в этой паре") {
                    Button(couple.man.name) { model.update { $0.meID = couple.man.id } }
                    Button(couple.woman.name) { model.update { $0.meID = couple.woman.id } }
                }
            }
        }
        .navigationTitle("Синхронизация")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if let saved = DebugSyncSettings.saved {
                coupleID = saved.coupleID
                keyHex = DebugSyncSettings.hex(saved.key)
            }
            await refresh()
        }
    }

    private func start() {
        let id = coupleID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty else { inputError = "Нужен id пары"; return }
        guard let key = DebugSyncSettings.key(fromHex: keyHex) else { inputError = "Ключ — ровно 64 hex-цифры"; return }
        inputError = DebugSyncSettings.save(coupleID: id, key: key)
            ? nil : "Ключ не сохранился в Keychain: после перезапуска введите снова"
        model.startSync(coupleID: id, key: key)
        isStarted = true
        Task { await syncNow() }
    }

    private func stop() {
        model.stopSync()
        DebugSyncSettings.clear()
        Task { await refresh() }
    }

    private func syncNow() async {
        await model.syncNow()
        await refresh()
    }

    private func refresh() async {
        isStarted = model.isSyncStarted
        unsent = await model.syncState?.outbox.count
    }
}

#Preview {
    NavigationStack { DebugSyncView() }
        .environment(AppModel(store: InMemoryStore()))
}
#endif
