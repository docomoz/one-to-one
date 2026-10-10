import Foundation
import Testing

/// Подменяет сеть в тестах: вместо запроса в интернет отдаёт заранее заданный ответ
/// и запоминает, какие запросы пришли. У каждой сессии свой ответ, поэтому тесты
/// можно запускать параллельно.
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    /// Подменённая сеть одного теста.
    final class Stub: @unchecked Sendable {
        let status: Int
        let body: Data
        private let lock = NSLock()
        private var _requests: [URLRequest] = []

        init(status: Int, body: Data) {
            self.status = status
            self.body = body
        }

        var requests: [URLRequest] { lock.withLock { _requests } }
        var lastURL: URL? { requests.last?.url }
        func record(_ request: URLRequest) { lock.withLock { _requests.append(request) } }
    }

    private static let idHeader = "X-Stub-ID"
    private static let lock = NSLock()
    nonisolated(unsafe) private static var stubs: [String: Stub] = [:]

    /// Сессия, которая отвечает `status` и телом из `Fixtures/<fixture>.json` (или `body`).
    static func session(status: Int = 200, fixture: String? = nil,
                        body: Data = Data()) throws -> (URLSession, Stub) {
        var body = body
        if let fixture {
            let url = try #require(Bundle.module.url(forResource: fixture, withExtension: "json",
                                                     subdirectory: "Fixtures"))
            body = try Data(contentsOf: url)
        }
        let stub = Stub(status: status, body: body)
        let id = UUID().uuidString
        lock.withLock { stubs[id] = stub }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        config.httpAdditionalHeaders = [idHeader: id]
        return (URLSession(configuration: config), stub)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let id = request.value(forHTTPHeaderField: Self.idHeader) ?? ""
        guard let stub = Self.lock.withLock({ Self.stubs[id] }) else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        stub.record(request)
        let response = HTTPURLResponse(url: request.url!, statusCode: stub.status,
                                       httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stub.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
