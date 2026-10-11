import Foundation
import Testing
@testable import OneToOne

@Test func consentVersionReadsIntOrDouble() {
    #expect(ConsentPrefs.version(in: [:]) == nil)
    #expect(ConsentPrefs.version(in: ["consentVersion": 1]) == 1)
    #expect(ConsentPrefs.version(in: ["consentVersion": 2.0]) == 2)
    #expect(ConsentPrefs.version(in: ["consentVersion": "1"]) == nil)
}

@Test func savingConsentKeepsOtherPrefs() {
    let date = Date(timeIntervalSince1970: 1_800_000_000)

    let prefs = ConsentPrefs.merged(["theme": "dark"], version: 1, date: date)

    #expect(prefs["theme"] as? String == "dark")
    #expect(prefs["consentVersion"] as? Int == 1)
    #expect(prefs["consentDate"] as? String == "2027-01-15T08:00:00Z")
}
