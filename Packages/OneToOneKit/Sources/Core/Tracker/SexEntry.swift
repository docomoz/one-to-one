import Foundation

/// Вид секса. Подписи на экране: «Классика», «Анал», «Куни», «Минет».
public enum SexType: String, Codable, CaseIterable, Sendable {
    case vaginal, anal, cunnilingus, blowjob
}

/// Куда кончил. Не `none`: такой случай путается с `nil` («не ответили»).
public enum SexFinish: String, Codable, CaseIterable, Sendable {
    case inside, outside, didNotFinish
}

/// Одна отметка секса. Время не храним, только день: за день может быть сколько угодно записей.
public struct SexEntry: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var day: DayKey
    public var types: Set<SexType>
    public var orgasmsMan: Int
    public var orgasmsWoman: Int
    /// Был ли презерватив. Спрашиваем только при «Классике»; `nil` — не ответили или старая запись.
    public var condom: Bool?
    /// Куда кончил. Тоже только при «Классике», `nil` — не ответили.
    public var finish: SexFinish?
    public let createdBy: UUID

    public init(id: UUID = UUID(), day: DayKey, types: Set<SexType>,
                orgasmsMan: Int, orgasmsWoman: Int,
                condom: Bool? = nil, finish: SexFinish? = nil, createdBy: UUID) {
        self.id = id
        self.day = day
        self.types = types
        self.orgasmsMan = orgasmsMan
        self.orgasmsWoman = orgasmsWoman
        self.condom = condom
        self.finish = finish
        self.createdBy = createdBy
    }
}

extension SexEntry {
    /// Про защиту спрашиваем только при «Классике». Сняли её — ответы стираем, иначе останется
    /// незаметная запись «без презерватива», и подсказка про таблетку сработает зря.
    public var withProtectionOnlyIfVaginal: SexEntry {
        guard !types.contains(.vaginal) else { return self }
        var entry = self
        entry.condom = nil
        entry.finish = nil
        return entry
    }
}
