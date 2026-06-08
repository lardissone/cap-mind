import XCTest
@testable import CapMind

final class DropPayloadTests: XCTestCase {
    func test_supported_extension_check() {
        XCTAssertTrue(DropPayload.isSupportedFileExtension("png"))
        XCTAssertTrue(DropPayload.isSupportedFileExtension("PDF"))
        XCTAssertTrue(DropPayload.isSupportedFileExtension("heic"))
        XCTAssertFalse(DropPayload.isSupportedFileExtension("xyz"))
        XCTAssertFalse(DropPayload.isSupportedFileExtension("mp4"))
    }
    func test_mimeType_for_extension() {
        XCTAssertEqual(DropPayload.mimeType(forExtension: "png"), "image/png")
        XCTAssertEqual(DropPayload.mimeType(forExtension: "jpg"), "image/jpeg")
        XCTAssertEqual(DropPayload.mimeType(forExtension: "md"), "text/markdown")
        XCTAssertEqual(DropPayload.mimeType(forExtension: "pdf"), "application/pdf")
    }
    func test_oversize_check() {
        XCTAssertTrue(DropPayload.isOversize(bytes: 70 * 1024 * 1024))
        XCTAssertFalse(DropPayload.isOversize(bytes: 10 * 1024 * 1024))
    }

    func test_detectURL_returns_url_for_bare_https_string() {
        XCTAssertEqual(DropPayload.detectURL(in: "https://example.com"),
                       URL(string: "https://example.com"))
    }
    func test_detectURL_trims_surrounding_whitespace() {
        XCTAssertEqual(DropPayload.detectURL(in: "  https://example.com\n"),
                       URL(string: "https://example.com"))
    }
    func test_detectURL_is_nil_for_prose_containing_a_link() {
        XCTAssertNil(DropPayload.detectURL(in: "check this https://example.com out"))
    }
    func test_detectURL_is_nil_for_plain_text() {
        XCTAssertNil(DropPayload.detectURL(in: "just a note"))
    }
    func test_detectURL_is_nil_for_non_web_scheme() {
        XCTAssertNil(DropPayload.detectURL(in: "mailto:hi@example.com"))
        XCTAssertNil(DropPayload.detectURL(in: "ftp://example.com/file"))
    }
}
