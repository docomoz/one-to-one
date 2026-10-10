/// Пара: ровно мужчина и женщина.
public struct Couple: Codable, Equatable, Sendable {
    public let man: Person
    public let woman: Person

    /// Собирает пару из двух людей в любом порядке. Двое одного пола — ошибка.
    public static func make(_ a: Person, _ b: Person) throws(CoupleError) -> Couple {
        switch (a.sex, b.sex) {
        case (.male, .female): Couple(man: a, woman: b)
        case (.female, .male): Couple(man: b, woman: a)
        default: throw .sameSex
        }
    }

    private init(man: Person, woman: Person) {
        self.man = man
        self.woman = woman
    }
}

public enum CoupleError: Error, Equatable {
    case sameSex
}
