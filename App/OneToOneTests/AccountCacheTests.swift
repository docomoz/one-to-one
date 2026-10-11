import Foundation
import Testing
@testable import OneToOne

private func makeCache() -> AccountCache {
    let name = "AccountCacheTests-\(UUID())"
    return AccountCache(defaults: UserDefaults(suiteName: name)!)
}

@Test func cacheRemembersUserAndHisConsent() {
    let cache = makeCache()

    cache.userID = "u1"
    cache.consentVersion = 1

    #expect(cache.userID == "u1")
    #expect(cache.consentVersion == 1)
}

@Test func otherUserDoesNotInheritConsent() {
    let cache = makeCache()
    cache.userID = "u1"
    cache.consentVersion = 1

    cache.userID = "u1"
    #expect(cache.consentVersion == 1)

    cache.userID = "u2"
    #expect(cache.consentVersion == nil)
}

@Test func withdrawnConsentIsForgotten() {
    let cache = makeCache()
    cache.userID = "u1"
    cache.consentVersion = 1

    cache.consentVersion = nil

    #expect(cache.consentVersion == nil)
}

@Test func clearForgetsUserAndConsent() {
    let cache = makeCache()
    cache.userID = "u1"
    cache.consentVersion = 1

    cache.clear()

    #expect(cache.userID == nil)
    #expect(cache.consentVersion == nil)
}
