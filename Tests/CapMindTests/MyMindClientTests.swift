import XCTest
@testable import CapMind

final class MyMindClientTests: XCTestCase {
    override func setUp() { MockURLProtocol.reset() }
    private func makeClient() -> MyMindClient {
        MyMindClient(credentialsProvider: StubCredentials(), urlSession: MockURLProtocol.session())
    }
    func test_createNote_success_returns_objectRef() async throws {
        MockURLProtocol.responses = [(201, [:], Data(#"{"id":"obj1"}"#.utf8))]
        let ref = try await makeClient().createObjectFromContent("hello")
        XCTAssertEqual(ref.id, "obj1")
    }
    func test_missing_credentials_throws_unauthorized() async {
        let client = MyMindClient(credentialsProvider: StubCredentials(creds: nil), urlSession: MockURLProtocol.session())
        await assertThrows(MyMindError.unauthorized) { try await client.createObjectFromContent("x") }
    }
    func test_401_maps_to_unauthorized() async {
        MockURLProtocol.responses = [(401, [:], Data(#"{"type":"Unauthorized","status":401}"#.utf8))]
        await assertThrows(MyMindError.unauthorized) { try await makeClient().createObjectFromContent("x") }
    }
    func test_413_maps_to_payloadTooLarge() async {
        MockURLProtocol.responses = [(413, [:], Data(#"{"type":"PayloadTooLarge","status":413}"#.utf8))]
        await assertThrows(MyMindError.payloadTooLarge) {
            try await makeClient().createObjectFromFile(Data([0]), mimeType: "image/png", filename: "a.png")
        }
    }
    func test_429_retries_once_then_succeeds() async throws {
        MockURLProtocol.responses = [
            (429, ["RateLimit": #""burst";r=0;t=0"#], Data(#"{"type":"RateLimited","status":429}"#.utf8)),
            (201, [:], Data(#"{"id":"obj2"}"#.utf8)),
        ]
        let ref = try await makeClient().createObjectFromContent("retry me")
        XCTAssertEqual(ref.id, "obj2")
        XCTAssertEqual(MockURLProtocol.requestCount, 2)
    }
    func test_429_twice_surfaces_rateLimited() async {
        MockURLProtocol.responses = [
            (429, ["RateLimit": #""burst";r=0;t=0"#], Data(#"{"type":"RateLimited","status":429}"#.utf8)),
            (429, ["RateLimit": #""burst";r=0;t=0"#], Data(#"{"type":"RateLimited","status":429}"#.utf8)),
        ]
        await assertThrows(MyMindError.rateLimited(retryAfterSeconds: 0)) {
            try await makeClient().createObjectFromContent("x")
        }
    }
    private func assertThrows(_ expected: MyMindError, _ block: () async throws -> Void,
                              file: StaticString = #filePath, line: UInt = #line) async {
        do { try await block(); XCTFail("expected throw", file: file, line: line) }
        catch let e as MyMindError { XCTAssertEqual(e, expected, file: file, line: line) }
        catch { XCTFail("wrong error \(error)", file: file, line: line) }
    }
}
