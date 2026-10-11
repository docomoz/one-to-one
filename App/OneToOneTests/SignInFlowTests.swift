import Foundation
import Testing
@testable import OneToOne

private let start = Date(timeIntervalSince1970: 1_800_000_000)

@MainActor
private func makeFlow(_ service: FakeAuthService, now: @escaping () -> Date = { start }) -> AuthFlow {
    AuthFlow(auth: service, consent: service, now: now)
}

@MainActor
@Test func noSessionShowsSignIn() async {
    let flow = makeFlow(FakeAuthService())

    #expect(flow.screen(isPaired: true) == .checking)
    await flow.start()

    #expect(flow.screen(isPaired: true) == .signIn)
}

@MainActor
@Test func sendCodeTrimsEmailAndWaitsForCode() async {
    let service = FakeAuthService()
    let flow = makeFlow(service)
    await flow.start()

    await flow.sendCode(to: "  Dasha@Mail.RU ")

    #expect(service.sentTo == ["dasha@mail.ru"])
    #expect(flow.pending?.email == "dasha@mail.ru")
    #expect(flow.pending?.userID == "user-dasha@mail.ru")
    #expect(flow.errorMessage == nil)
}

@MainActor
@Test func sendCodeFailureShowsErrorAndStaysOnEmail() async {
    let service = FakeAuthService()
    service.sendError = .network
    let flow = makeFlow(service)
    await flow.start()

    await flow.sendCode(to: "dasha@mail.ru")

    #expect(flow.pending == nil)
    #expect(flow.errorMessage == AuthError.network.message)
}

@MainActor
@Test func wrongCodeShowsError() async {
    let service = FakeAuthService()
    let flow = makeFlow(service)
    await flow.start()
    await flow.sendCode(to: "dasha@mail.ru")

    await flow.confirm(code: "000000")

    #expect(flow.errorMessage == AuthError.wrongCode.message)
    #expect(flow.screen(isPaired: false) == .signIn)
    #expect(flow.pending != nil)

    await flow.confirm(code: "123456")
    #expect(flow.errorMessage == nil)
    #expect(flow.screen(isPaired: false) == .consent)
}

@MainActor
@Test func consentRequiredBeforeOnboarding() async {
    let service = FakeAuthService()
    let flow = makeFlow(service)
    await flow.start()
    await flow.sendCode(to: "dasha@mail.ru")
    await flow.confirm(code: "123456")

    #expect(flow.screen(isPaired: false) == .consent)
    #expect(flow.screen(isPaired: true) == .consent)

    await flow.giveConsent(personalData: true, specialCategory: true)

    #expect(service.savedConsent?.version == BackendConfig.consentVersion)
    #expect(service.savedConsent?.date == start)
    #expect(flow.screen(isPaired: false) == .onboarding)
}

@MainActor
@Test func consentNeedsBothCheckboxes() async {
    let service = FakeAuthService(signedInUserID: "u1")
    let flow = makeFlow(service)
    await flow.start()

    await flow.giveConsent(personalData: true, specialCategory: false)
    await flow.giveConsent(personalData: false, specialCategory: true)

    #expect(service.savedConsent == nil)
    #expect(flow.screen(isPaired: false) == .consent)
    #expect(!AuthFlow.canGiveConsent(personalData: true, specialCategory: false))
    #expect(AuthFlow.canGiveConsent(personalData: true, specialCategory: true))
}

@MainActor
@Test func consentSaveFailureKeepsConsentScreen() async {
    let service = FakeAuthService(signedInUserID: "u1")
    let flow = makeFlow(service)
    await flow.start()
    service.consentError = .network

    await flow.giveConsent(personalData: true, specialCategory: true)

    #expect(flow.screen(isPaired: false) == .consent)
    #expect(flow.errorMessage == AuthError.network.message)
}

@MainActor
@Test func olderConsentVersionAsksAgain() async {
    let flow = makeFlow(FakeAuthService(signedInUserID: "u1", consent: BackendConfig.consentVersion - 1))

    await flow.start()

    #expect(flow.screen(isPaired: true) == .consent)
}

@MainActor
@Test func signedInUserWithCoupleGoesToTabs() async {
    let flow = makeFlow(FakeAuthService(signedInUserID: "u1", consent: BackendConfig.consentVersion))

    await flow.start()

    #expect(flow.screen(isPaired: true) == .tabs)
    #expect(flow.screen(isPaired: false) == .onboarding)
}

@MainActor
@Test func resendWaitsSixtySeconds() async {
    var now = start
    let service = FakeAuthService()
    let flow = makeFlow(service, now: { now })
    await flow.start()
    await flow.sendCode(to: "dasha@mail.ru")

    #expect(flow.resendDelay(at: now) == 60)
    now = start.addingTimeInterval(59.5)
    #expect(flow.resendDelay(at: now) == 1)
    await flow.resendCode()
    #expect(service.sentTo.count == 1)

    now = start.addingTimeInterval(60)
    #expect(flow.resendDelay(at: now) == 0)
    await flow.resendCode()
    #expect(service.sentTo.count == 2)
    #expect(flow.resendDelay(at: now) == 60)
}

@MainActor
@Test func changeEmailReturnsToEmailStep() async {
    let flow = makeFlow(FakeAuthService())
    await flow.start()
    await flow.sendCode(to: "dasha@mail.ru")
    await flow.confirm(code: "000000")

    flow.changeEmail()

    #expect(flow.pending == nil)
    #expect(flow.errorMessage == nil)
}

@MainActor
@Test func signOutReturnsToSignIn() async {
    let service = FakeAuthService(signedInUserID: "u1", consent: BackendConfig.consentVersion)
    let flow = makeFlow(service)
    await flow.start()

    await flow.signOut()

    #expect(flow.screen(isPaired: true) == .signIn)
    #expect(service.signedInUserID == nil)
}

@MainActor
@Test func signOutFailureKeepsUserInside() async {
    let service = FakeAuthService(signedInUserID: "u1", consent: BackendConfig.consentVersion)
    service.signOutError = .network
    let flow = makeFlow(service)
    await flow.start()

    await flow.signOut()

    #expect(flow.screen(isPaired: true) == .tabs)
    #expect(flow.errorMessage == AuthError.network.message)
}

@Test func emailNeedsAtAndDomain() {
    #expect(AuthFlow.isPlausibleEmail("dasha@mail.ru"))
    #expect(AuthFlow.isPlausibleEmail(" Dasha@Mail.ru "))
    #expect(!AuthFlow.isPlausibleEmail("dasha"))
    #expect(!AuthFlow.isPlausibleEmail("dasha@mail"))
    #expect(!AuthFlow.isPlausibleEmail("@mail.ru"))
    #expect(!AuthFlow.isPlausibleEmail("da sha@mail.ru"))
}

@Test func codeKeepsOnlySixDigits() {
    #expect(AuthFlow.cleanCode("12 34-56") == "123456")
    #expect(AuthFlow.cleanCode("1234567") == "123456")
    #expect(AuthFlow.cleanCode("abc") == "")
}
