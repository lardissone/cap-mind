import Foundation
@testable import CapMind

final class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var responses: [(Int, [String: String], Data)] = []
    nonisolated(unsafe) static var requestCount = 0

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard !Self.responses.isEmpty else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        let idx = min(Self.requestCount, Self.responses.count - 1)
        Self.requestCount += 1
        let (status, headers, body) = Self.responses[idx]
        let resp = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: headers)!
        client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}

    static func reset() { responses = []; requestCount = 0 }
    static func session() -> URLSession {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: cfg)
    }
}

struct StubCredentials: CredentialsProviding {
    var creds: MyMindCredentials? = .init(keyID: "k", secret: "c2VjcmV0LWtleS1ieXRlcw==")
    func currentCredentials() -> MyMindCredentials? { creds }
}
