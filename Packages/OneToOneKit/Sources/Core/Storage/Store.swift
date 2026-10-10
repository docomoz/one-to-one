/// Где лежит `AppData`. На телефоне — `LocalStore`, в тестах и превью — `InMemoryStore`.
public protocol Store: Sendable {
    func load() throws -> AppData
    func save(_ data: AppData) throws
}
