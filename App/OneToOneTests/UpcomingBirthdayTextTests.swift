import Core
import Testing
@testable import OneToOne

private let dasha = Person(name: "Даша", sex: .female)

@Test func partnerBirthdayTexts() {
    #expect(UpcomingBirthday(person: dasha, isMe: false, daysLeft: 12).text == "🎂 Даша: День рождения через 12 дней")
    #expect(UpcomingBirthday(person: dasha, isMe: false, daysLeft: 1).text == "🎂 Даша: День рождения завтра")
    #expect(UpcomingBirthday(person: dasha, isMe: false, daysLeft: 0).text == "🎉 Даша: День рождения сегодня!")
}

@Test func myBirthdayTexts() {
    #expect(UpcomingBirthday(person: dasha, isMe: true, daysLeft: 21).text == "🎂 Твой день рождения через 21 день")
    #expect(UpcomingBirthday(person: dasha, isMe: true, daysLeft: 1).text == "🎂 Твой день рождения завтра")
    #expect(UpcomingBirthday(person: dasha, isMe: true, daysLeft: 0).text == "🎉 С днём рождения!")
}
