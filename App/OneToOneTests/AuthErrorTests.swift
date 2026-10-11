import Testing
@testable import OneToOne

@Test func appwriteErrorsBecomeClearReasons() {
    #expect(AuthError(status: 401, type: "user_invalid_token", step: .confirm) == .wrongCode)
    #expect(AuthError(status: 400, type: "general_argument_invalid", step: .confirm) == .wrongCode)
    #expect(AuthError(status: 400, type: "general_argument_invalid", step: .sendCode) == .invalidEmail)
    #expect(AuthError(status: 429, type: "general_rate_limit_exceeded", step: .sendCode) == .tooManyAttempts)
    #expect(AuthError(status: 500, type: "general_unknown", step: .confirm) == .server)
    #expect(AuthError(status: 401, type: "user_invalid_token", step: .other) == .server)
}

@Test func everyAuthErrorHasRussianText() {
    for error in [AuthError.wrongCode, .invalidEmail, .tooManyAttempts, .network, .server] {
        #expect(!error.message.isEmpty)
    }
    #expect(AuthError.wrongCode.message.contains("Код"))
    #expect(AuthError.network.message.contains("интернет"))
}
