import Foundation

/// Один человек из пары.
public struct Person: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var sex: Sex

    public init(id: UUID = UUID(), name: String, sex: Sex) {
        self.id = id
        self.name = name
        self.sex = sex
    }
}
