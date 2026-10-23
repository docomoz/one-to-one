import Core
import Testing
@testable import OneToOne

private let anya = Person(name: "Аня", sex: .female)

@Test func partnerBirthdayTexts() {
    #expect(UpcomingBirthday(person: anya, isMe: false, daysLeft: 12).text == "🎂 Аня: День рождения через 12 дней")
    #expect(UpcomingBirthday(person: anya, isMe: false, daysLeft: 1).text == "🎂 Аня: День рождения завтра")
    #expect(UpcomingBirthday(person: anya, isMe: false, daysLeft: 0).text == "🎉 Аня: День рождения сегодня!")
}

@Test func myBirthdayTexts() {
    #expect(UpcomingBirthday(person: anya, isMe: true, daysLeft: 21).text == "🎂 Твой день рождения через 21 день")
    #expect(UpcomingBirthday(person: anya, isMe: true, daysLeft: 1).text == "🎂 Твой день рождения завтра")
    #expect(UpcomingBirthday(person: anya, isMe: true, daysLeft: 0).text == "🎉 С днём рождения!")
}
