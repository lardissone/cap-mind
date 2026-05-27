import XCTest
@testable import CapMind

final class MyMindRequestsTests: XCTestCase {
    func test_note_body_is_nested_markdown() throws {
        let data = try MyMindRequests.noteJSONBody(markdown: "# Hi\n\nbody")
        let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let content = obj["content"] as! [String: Any]
        XCTAssertEqual(content["type"] as? String, "text/markdown")
        XCTAssertEqual(content["body"] as? String, "# Hi\n\nbody")
        XCTAssertNil(obj["tags"])
    }
    func test_url_body() throws {
        let data = try MyMindRequests.urlJSONBody(url: URL(string: "https://e.com/a")!)
        let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(obj["url"] as? String, "https://e.com/a")
    }
    func test_multipart_sanitizes_filename_with_quotes_and_newlines() {
        let (body, _) = MyMindRequests.multipart(
            boundary: "B", blob: Data("x".utf8), mimeType: "image/png",
            filename: "a\"b\r\nContent-Type: evil.png")
        let s = String(data: body, encoding: .utf8)!
        XCTAssertTrue(s.contains(#"filename="a_bContent-Type: evil.png""#))
        XCTAssertFalse(s.contains("\r\nContent-Type: evil"))  // no injected header line
    }
    func test_multipart_frames_metadata_and_blob() {
        let blob = Data("PNGDATA".utf8)
        let (body, contentType) = MyMindRequests.multipart(
            boundary: "BNDRY", blob: blob, mimeType: "image/png", filename: "shot.png")
        XCTAssertEqual(contentType, "multipart/form-data; boundary=BNDRY")
        let s = String(data: body, encoding: .utf8)!
        XCTAssertTrue(s.contains("--BNDRY\r\n"))
        XCTAssertTrue(s.contains(#"Content-Disposition: form-data; name="metadata""#))
        XCTAssertTrue(s.contains("Content-Type: application/json\r\n\r\n{}\r\n"))
        XCTAssertTrue(s.contains(#"name="blob"; filename="shot.png""#))
        XCTAssertTrue(s.contains("Content-Type: image/png\r\n\r\nPNGDATA\r\n"))
        XCTAssertTrue(s.hasSuffix("--BNDRY--\r\n"))
    }
}
