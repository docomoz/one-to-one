import Foundation
import Testing

/// Подменяет сеть в тестах: вместо запроса в интернет отдаёт заранее заданный ответ
/// и запоминает, какой запрос пришёл.
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    struct Stub: Sendable {
        var status: Int = 200
        var body: Data = Data()
    }

    nonisolated(unsafe) static var stub = Stub()
    nonisolated(unsafe) static var requests: [URLRequest] = []

    static func session(status: Int = 200, fixture: String? = nil) throws -> URLSession {
        var body = Data()
        if let fixture {
            let url = try #require(Bundle.module.url(forResource: fixture, withExtension: "json",
                                                     subdirectory: "Fixtures"))
            body = try Data(contentsOf: url)
        }
        stub = Stub(status: status, body: body)
        requests = []
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: config)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.requests.append(request)
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.stub.status,
                                       httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.stub.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
