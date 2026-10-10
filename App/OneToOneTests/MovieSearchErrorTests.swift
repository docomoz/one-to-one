import Foundation
import MovieAPI
import Testing
@testable import OneToOne

@Test func searchErrorExplainsMissingKeyLimitAndOffline() {
    #expect(MovieSearchError.message(for: KinopoiskError.unauthorized).contains("ключа"))
    #expect(MovieSearchError.message(for: KinopoiskError.forbidden).contains("завтра"))
    #expect(MovieSearchError.message(for: URLError(.notConnectedToInternet)).contains("интернета"))
    #expect(MovieSearchError.message(for: KinopoiskError.http(status: 500)).contains("не ответил"))
}

@Test func serverTimeoutIsNotOffline() {
    #expect(MovieSearchError.message(for: URLError(.timedOut)).contains("не ответил"))
}
