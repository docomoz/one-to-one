import Core
import MovieAPI
import Observation

/// Поиск фильмов для экрана добавления: пауза в наборе, результаты и понятная ошибка.
@Observable @MainActor
final class MovieSearch {
    private(set) var results: [Movie] = []
    private(set) var errorMessage: String?
    private(set) var isLoading = false

    @ObservationIgnored private let catalog: any MovieCatalog
    @ObservationIgnored private let delay: Duration

    init(catalog: any MovieCatalog, delay: Duration = .milliseconds(600)) {
        self.catalog = catalog
        self.delay = delay
    }

    /// Запускай из `.task(id:)`: новый текст отменяет прошлый поиск. Отменённый поиск
    /// ничего не меняет, чтобы его ответ не затёр результаты нового.
    func run(_ query: String) async {
        let text = Self.normalized(query)
        errorMessage = nil
        guard text.count >= 2 else {
            results = []
            isLoading = false
            return
        }
        // Ждём паузу в наборе: каждый запрос тратит один из 200 бесплатных в день.
        do { try await Task.sleep(for: delay) } catch { return }
        guard !Task.isCancelled else { return }

        isLoading = true
        do {
            let movies = try await catalog.search(text)
            guard !Task.isCancelled else { return }
            results = movies
        } catch {
            guard !Task.isCancelled else { return }
            results = []
            errorMessage = MovieSearchError.message(for: error)
        }
        isLoading = false
    }

    static func normalized(_ query: String) -> String {
        query.trimmingCharacters(in: .whitespaces)
    }
}
