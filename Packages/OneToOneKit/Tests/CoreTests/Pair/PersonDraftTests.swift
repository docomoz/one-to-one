import Foundation
import Testing
@testable import Core

private let today = DayKey(year: 2026, month: 10, day: 10)
private let adult = DayKey(year: 1996, month: 5, day: 12)

@Test func draftTrimsName() throws {
    let draft = PersonDraft(sex: .female, name: "  Даша ", birthDate: adult)
    let person = try draft.validated(today: today)
    #expect(person == Person(id: draft.id, name: "Даша", sex: .female, birthDate: adult))
}

@Test func draftRejectsEmptyOrSpacesName() {
    #expect(throws: OnboardingError.emptyName) {
        try PersonDraft(sex: .male, name: "   ", birthDate: adult).validated(today: today)
    }
    #expect(!PersonDraft(sex: .male, name: "   ", birthDate: adult).isFilled)
}

@Test func draftRequiresBirthDate() {
    #expect(throws: OnboardingError.noBirthDate) {
        try PersonDraft(sex: .male, name: "Максим").validated(today: today)
    }
    #expect(!PersonDraft(sex: .male, name: "Максим").isFilled)
    #expect(PersonDraft(sex: .male, name: "Максим", birthDate: adult).isFilled)
}

@Test func draftRejectsUnder18() throws {
    let almost = PersonDraft(sex: .male, name: "Максим", birthDate: DayKey(year: 2008, month: 10, day: 11))
    #expect(throws: OnboardingError.tooYoung) { try almost.validated(today: today) }
    let exactly = PersonDraft(sex: .male, name: "Максим", birthDate: DayKey(year: 2008, month: 10, day: 10))
    _ = try exactly.validated(today: today)
}

@Test func coupleFromDraftsRejectsSameSex() {
    let me = PersonDraft(sex: .female, name: "Даша", birthDate: adult)
    let partner = PersonDraft(sex: .female, name: "Аня", birthDate: adult)
    #expect(throws: OnboardingError.sameSex) { try Couple.make(me: me, partner: partner, today: today) }
}

@Test func coupleFromDraftsChecksPartnerAge() {
    let me = PersonDraft(sex: .female, name: "Даша", birthDate: adult)
    let partner = PersonDraft(sex: .male, name: "Максим", birthDate: DayKey(year: 2010, month: 1, day: 1))
    #expect(throws: OnboardingError.tooYoung) { try Couple.make(me: me, partner: partner, today: today) }
}

@Test func coupleFromDraftsKeepsIDs() throws {
    let me = PersonDraft(sex: .female, name: "Даша", birthDate: adult)
    let partner = PersonDraft(sex: .male, name: "Максим", birthDate: adult)
    let couple = try Couple.make(me: me, partner: partner, today: today)
    #expect(couple.woman.id == me.id)
    #expect(couple.man.id == partner.id)
}

@Test func onboardingErrorMessages() {
    #expect(OnboardingError.sameSex.message == "Пара — это мужчина и женщина")
    #expect(OnboardingError.tooYoung.message == "Приложением можно пользоваться с 18 лет")
}
