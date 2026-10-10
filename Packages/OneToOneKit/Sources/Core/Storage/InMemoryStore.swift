import Synchronization

/// Держит `AppData` в памяти, на диск не пишет. Для тестов и превью.
public final class InMemoryStore: Store {
    private let data: Mutex<AppData>

    public init(_ data: AppData = AppData()) {
        self.data = Mutex(data)
    }

    public func load() throws -> AppData {
        data.withLock { $0 }
    }

    public func save(_ data: AppData) throws {
        self.data.withLock { $0 = data }
    }
}
