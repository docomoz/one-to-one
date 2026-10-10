import Foundation

/// Вид секса. Подписи на экране: «Классика», «Анал», «Куни», «Минет».
public enum SexType: String, Codable, CaseIterable, Sendable {
    case vaginal, anal, cunnilingus, blowjob
}

/// Одна отметка секса.
public struct SexEntry: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var date: Date
    public var types: Set<SexType>
    public var orgasmsMan: Int
    public var orgasmsWoman: Int
    public let createdBy: UUID

    public init(id: UUID = UUID(), date: Date, types: Set<SexType>,
                orgasmsMan: Int, orgasmsWoman: Int, createdBy: UUID) {
        self.id = id
        self.date = date
        self.types = types
        self.orgasmsMan = orgasmsMan
        self.orgasmsWoman = orgasmsWoman
        self.createdBy = createdBy
    }
}
