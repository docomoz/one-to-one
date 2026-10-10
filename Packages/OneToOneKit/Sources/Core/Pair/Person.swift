import Foundation

/// Один человек из пары.
public struct Person: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var sex: Sex
    /// День рождения. Пусто в данных, сохранённых до появления этого поля.
    public var birthDate: DayKey?

    public init(id: UUID = UUID(), name: String, sex: Sex, birthDate: DayKey? = nil) {
        self.id = id
        self.name = name
        self.sex = sex
        self.birthDate = birthDate
    }
}
