import Foundation

/// То, что человек ввёл в знакомстве, но ещё не проверено.
public struct PersonDraft: Equatable, Sendable {
    /// С какого возраста можно пользоваться приложением.
    public static let minimumAge = 18

    public let id: UUID
    public var sex: Sex
    public var name: String
    public var birthDate: DayKey?

    public init(id: UUID = UUID(), sex: Sex, name: String = "", birthDate: DayKey? = nil) {
        self.id = id
        self.sex = sex
        self.name = name
        self.birthDate = birthDate
    }

    /// Всё заполнено, можно нажимать «Дальше». Возраст проверяет `validated`.
    public var isFilled: Bool {
        !trimmedName.isEmpty && birthDate != nil
    }

    /// Проверяет черновик и собирает из него человека с тем же `id`.
    public func validated(today: DayKey) throws(OnboardingError) -> Person {
        guard !trimmedName.isEmpty else { throw .emptyName }
        guard let birthDate else { throw .noBirthDate }
        guard birthDate.age(on: today) >= Self.minimumAge else { throw .tooYoung }
        return Person(id: id, name: trimmedName, sex: sex, birthDate: birthDate)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension Couple {
    /// Пара из знакомства: сначала проверяем меня, потом партнёра, потом пол.
    public static func make(me: PersonDraft, partner: PersonDraft, today: DayKey) throws(OnboardingError) -> Couple {
        let mePerson = try me.validated(today: today)
        let partnerPerson = try partner.validated(today: today)
        do {
            return try make(mePerson, partnerPerson)
        } catch {
            throw .sameSex
        }
    }
}
