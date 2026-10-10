import Core

extension AppModel {
    /// Запоминает, с какого дня пара вместе. `nil` убирает дату: плашки годовщины не будет.
    func setTogetherSince(_ day: DayKey?) {
        update { $0.togetherSince = day }
    }
}
