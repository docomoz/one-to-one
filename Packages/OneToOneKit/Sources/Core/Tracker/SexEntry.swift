import Foundation

/// Вид секса. Подписи на экране: «Классика», «Анал», «Куни», «Минет».
public enum SexType: String, Codable, CaseIterable, Sendable {
    case vaginal, anal, cunnilingus, blowjob
}

/// Одна отметка секса. Время не храним, только день: за день может быть сколько угодно записей.
public struct SexEntry: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var day: DayKey
    public var types: Set<SexType>
    public var orgasmsMan: Int
    public var orgasmsWoman: Int
    public let createdBy: UUID

    public init(id: UUID = UUID(), day: DayKey, types: Set<SexType>,
                orgasmsMan: Int, orgasmsWoman: Int, createdBy: UUID) {
        self.id = id
        self.day = day
        self.types = types
        self.orgasmsMan = orgasmsMan
        self.orgasmsWoman = orgasmsWoman
        self.createdBy = createdBy
    }
}
