import Core
import Testing
@testable import OneToOne

@Test func anniversaryTexts() {
    #expect(UpcomingAnniversary(years: 3, daysLeft: 12).text == "💞 Годовщина через 12 дней")
    #expect(UpcomingAnniversary(years: 3, daysLeft: 1).text == "💞 Годовщина завтра")
    #expect(UpcomingAnniversary(years: 3, daysLeft: 0).text == "💞 3 года вместе! С годовщиной!")
    #expect(UpcomingAnniversary(years: 1, daysLeft: 0).text == "💞 1 год вместе! С годовщиной!")
    #expect(UpcomingAnniversary(years: 5, daysLeft: 0).text == "💞 5 лет вместе! С годовщиной!")
}

@Test func eventTextDelegates() {
    let birthday = UpcomingBirthday(person: Person(name: "Аня", sex: .female), isMe: false, daysLeft: 12)
    let anniversary = UpcomingAnniversary(years: 3, daysLeft: 12)

    #expect(UpcomingEvent.birthday(birthday).text == birthday.text)
    #expect(UpcomingEvent.anniversary(anniversary).text == anniversary.text)
}
