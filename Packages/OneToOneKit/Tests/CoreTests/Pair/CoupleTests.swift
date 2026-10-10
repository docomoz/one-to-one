import Foundation
import Testing
@testable import Core

private let man1 = Person(id: UUID(), name: "Максим", sex: .male)
private let man2 = Person(id: UUID(), name: "Иван", sex: .male)
private let woman1 = Person(id: UUID(), name: "Даша", sex: .female)
private let woman2 = Person(id: UUID(), name: "Аня", sex: .female)

@Test func coupleRejectsSameSex() {
    #expect(throws: CoupleError.sameSex) { try Couple.make(man1, man2) }
    #expect(throws: CoupleError.sameSex) { try Couple.make(woman1, woman2) }
}

@Test func coupleOrdersManWoman() throws {
    let couple = try Couple.make(woman1, man1)
    #expect(couple.man == man1)
    #expect(couple.woman == woman1)
}
