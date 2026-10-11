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
    cache.setConsentVersion(1, for: "u1")

    #expect(cache.userID == "u1")
    #expect(cache.consentVersion(for: "u1") == 1)
    #expect(cache.consentVersion(for: "u2") == nil)
}

@Test func clearForgetsUserAndConsent() {
    let cache = makeCache()
    cache.userID = "u1"
    cache.setConsentVersion(1, for: "u1")

    cache.clear()

    #expect(cache.userID == nil)
    #expect(cache.consentVersion(for: "u1") == nil)
}
