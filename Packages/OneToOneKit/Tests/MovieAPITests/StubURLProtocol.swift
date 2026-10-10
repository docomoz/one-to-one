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
        /// Ответы по куску адреса запроса (`similarMovies`); ни один не подошёл — отдаём `body`.
        let routes: [String: Data]
        private let lock = NSLock()
        private var _requests: [URLRequest] = []

        init(status: Int, body: Data, routes: [String: Data] = [:]) {
            self.status = status
            self.body = body
            self.routes = routes
        }

        func body(for request: URLRequest) -> Data {
            let url = request.url?.absoluteString ?? ""
            return routes.first { url.contains($0.key) }?.value ?? body
        }

        var requests: [URLRequest] { lock.withLock { _requests } }
        var lastURL: URL? { requests.last?.url }
        func record(_ request: URLRequest) { lock.withLock { _requests.append(request) } }
    }

    private static let idHeader = "X-Stub-ID"
    private static let lock = NSLock()
    nonisolated(unsafe) private static var stubs: [String: Stub] = [:]

    /// Сессия, которая отвечает `status` и телом из `Fixtures/<fixture>.json` (или `body`).
    /// `routes` — свои образцы для запросов, в адресе которых есть ключ: `["similarMovies": "similar"]`.
    static func session(status: Int = 200, fixture: String? = nil, body: Data = Data(),
                        routes: [String: String] = [:]) throws -> (URLSession, Stub) {
        let body = try fixture.map(load) ?? body
        let stub = Stub(status: status, body: body, routes: try routes.mapValues(load))
        let id = UUID().uuidString
        lock.withLock { stubs[id] = stub }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        config.httpAdditionalHeaders = [idHeader: id]
        return (URLSession(configuration: config), stub)
    }

    private static func load(_ fixture: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: fixture, withExtension: "json",
                                                 subdirectory: "Fixtures"))
        return try Data(contentsOf: url)
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
        client?.urlProtocol(self, didLoad: stub.body(for: request))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
