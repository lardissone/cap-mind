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
}
