import XCTest
@testable import CapMind

final class MyMindErrorMessageTests: XCTestCase {

    func test_unauthorized_message() {
        XCTAssertEqual(MyMindError.unauthorized.userMessage, "Authentication failed. Check your access key.")
    }

    func test_payloadTooLarge_message() {
        XCTAssertEqual(MyMindError.payloadTooLarge.userMessage, "File too large (64 MB max).")
    }

    func test_unsupportedMime_contains_extension() {
        let msg = MyMindError.unsupportedMime("xyz").userMessage
        XCTAssertTrue(msg.contains(".xyz"), "Expected '.xyz' in \"\(msg)\"")
    }

    func test_rateLimited_contains_seconds() {
        let msg = MyMindError.rateLimited(retryAfterSeconds: 3).userMessage
        XCTAssertTrue(msg.contains("3"), "Expected '3' in \"\(msg)\"")
    }

    func test_forbidden_message() {
        XCTAssertEqual(MyMindError.forbidden.userMessage, "Your key doesn't have permission for this action.")
    }

    func test_unprocessable_empty_fallback() {
        XCTAssertEqual(MyMindError.unprocessable("").userMessage, "MyMind couldn't process that.")
    }

    func test_unprocessable_with_detail() {
        XCTAssertEqual(MyMindError.unprocessable("Custom detail").userMessage, "Custom detail")
    }

    func test_network_message() {
        let urlError = URLError(.notConnectedToInternet)
        XCTAssertEqual(MyMindError.network(urlError).userMessage, "No connection.")
    }

    func test_decoding_message() {
        XCTAssertEqual(MyMindError.decoding("some error").userMessage, "Unexpected response from MyMind.")
    }

    func test_server_message() {
        XCTAssertEqual(MyMindError.server("internal").userMessage, "MyMind is having issues. Try again in a minute.")
    }

    func test_unavailable_message() {
        XCTAssertEqual(MyMindError.unavailable.userMessage, "MyMind is temporarily unavailable.")
    }

    func test_notFound_message() {
        XCTAssertEqual(MyMindError.notFound.userMessage, "Not found.")
    }

    func test_badRequest_empty_fallback() {
        XCTAssertEqual(MyMindError.badRequest("").userMessage, "Bad request.")
    }

    func test_badRequest_with_detail() {
        XCTAssertEqual(MyMindError.badRequest("Missing field").userMessage, "Missing field")
    }
}
