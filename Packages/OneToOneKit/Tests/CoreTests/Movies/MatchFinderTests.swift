import Foundation
import Testing
@testable import Core

private let man = Person(name: "Боря", sex: .male)
private let woman = Person(name: "Аня", sex: .female)
private let couple = try! Couple.make(man, woman)
private let session = UUID()

private func swipe(_ person: Person, _ movieID: Int, _ action: SwipeAction, hours: Double = 0) -> Swipe {
    Swipe(sessionID: session, personID: person.id, movieID: movieID, action: action,
          date: Date(timeIntervalSince1970: hours * 3600))
}

@Test func matchWhenBothYes() {
    let swipes = [swipe(man, 1, .yes), swipe(woman, 1, .yes)]
    #expect(MatchFinder.matches(swipes, couple: couple) == [1])
}

@Test func noMatchWhenOneNo() {
    let swipes = [swipe(man, 1, .yes), swipe(woman, 1, .no), swipe(man, 2, .yes), swipe(woman, 2, .later)]
    #expect(MatchFinder.matches(swipes, couple: couple).isEmpty)
}

@Test func matchAcrossDifferentTimes() {
    let swipes = [swipe(man, 1, .yes, hours: 0), swipe(woman, 1, .yes, hours: 6)]
    #expect(MatchFinder.matches(swipes, couple: couple) == [1])
}

@Test func multipleMatchesKeptInOrderTheyHappened() {
    let swipes = [swipe(man, 1, .yes, hours: 0), swipe(man, 2, .yes, hours: 1),
                  swipe(woman, 2, .yes, hours: 2), swipe(woman, 1, .yes, hours: 3)]
    #expect(MatchFinder.matches(swipes, couple: couple) == [2, 1])
}

@Test func repeatedYesGivesOneMatch() {
    let swipes = [swipe(man, 1, .yes), swipe(man, 1, .yes), swipe(woman, 1, .yes)]
    #expect(MatchFinder.matches(swipes, couple: couple) == [1])
}

@Test func lastSwipeOfPersonWins() {
    let swipes = [swipe(man, 1, .yes, hours: 0), swipe(woman, 1, .yes, hours: 1), swipe(man, 1, .no, hours: 2)]
    #expect(MatchFinder.matches(swipes, couple: couple).isEmpty)
}

@Test func strangerSwipesIgnored() {
    let stranger = Person(name: "Кто-то", sex: .female)
    let swipes = [swipe(man, 1, .yes), swipe(stranger, 1, .yes)]
    #expect(MatchFinder.matches(swipes, couple: couple).isEmpty)
}

@Test func likedByAnyoneFallback() {
    let swipes = [swipe(woman, 3, .yes, hours: 0), swipe(man, 1, .no, hours: 1),
                  swipe(man, 2, .yes, hours: 2), swipe(woman, 2, .yes, hours: 3), swipe(man, 4, .later, hours: 4)]
    #expect(MatchFinder.likedByAnyone(swipes) == [3, 2])
}

@Test func likedByAnyoneDropsChangedMind() {
    let swipes = [swipe(woman, 3, .yes, hours: 0), swipe(woman, 3, .no, hours: 1)]
    #expect(MatchFinder.likedByAnyone(swipes).isEmpty)
}

@Test func reswipeDoesNotReorderMatches() {
    let swipes = [swipe(man, 1, .yes, hours: 0), swipe(woman, 1, .yes, hours: 1),
                  swipe(man, 2, .yes, hours: 2), swipe(woman, 2, .yes, hours: 3), swipe(man, 1, .yes, hours: 4)]
    #expect(MatchFinder.matches(swipes, couple: couple) == [1, 2])
}

@Test func likedByAnyoneOrderedByFirstYes() {
    let swipes = [swipe(man, 1, .no, hours: 0), swipe(woman, 2, .yes, hours: 1), swipe(man, 1, .yes, hours: 2)]
    #expect(MatchFinder.likedByAnyone(swipes) == [2, 1])
}
