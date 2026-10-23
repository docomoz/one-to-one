import Foundation
import Testing
@testable import Core

@Test func personDecodesWithoutBirthDate() throws {
    let json = #"{"id": "\#(UUID())", "name": "Аня", "sex": "female"}"#
    let person = try JSONDecoder().decode(Person.self, from: Data(json.utf8))
    #expect(person.birthDate == nil)
}

@Test func personRoundTripsBirthDate() throws {
    let person = Person(name: "Аня", sex: .female, birthDate: DayKey(year: 1996, month: 5, day: 12))
    let decoded = try JSONDecoder().decode(Person.self, from: JSONEncoder().encode(person))
    #expect(decoded == person)
}
