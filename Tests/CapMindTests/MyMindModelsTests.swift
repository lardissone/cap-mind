import XCTest
@testable import CapMind

final class MyMindModelsTests: XCTestCase {
    func test_objectRef_decodes_id_and_optional_fields() throws {
        let json = """
        {"id":"abc123","title":"X","url":"https://e.com","created":"2024-04-08T09:00:00Z",
         "modified":"2024-04-08T09:00:00Z","bumped":"2024-04-08T09:00:00Z"}
        """.data(using: .utf8)!
        let ref = try JSONDecoder().decode(ObjectRef.self, from: json)
        XCTAssertEqual(ref.id, "abc123")
        XCTAssertEqual(ref.title, "X")
    }
    func test_problemJSON_decodes_type_status_detail() throws {
        let json = #"{"type":"NotFound","status":404,"detail":"No object with that ID exists."}"#.data(using: .utf8)!
        let p = try JSONDecoder().decode(ProblemJSON.self, from: json)
        XCTAssertEqual(p.type, "NotFound")
        XCTAssertEqual(p.status, 404)
        XCTAssertEqual(p.detail, "No object with that ID exists.")
    }
    func test_rateLimit_picks_exhausted_policies_max_t() {
        let header = #""burst";r=0;t=42, "sustained";r=99641;t=2589945"#
        XCTAssertEqual(RateLimitHeader.maxResetForExhausted(header), 42)
    }
    func test_rateLimit_two_exhausted_takes_max() {
        let header = #""burst";r=0;t=42, "sustained";r=0;t=900"#
        XCTAssertEqual(RateLimitHeader.maxResetForExhausted(header), 900)
    }
    func test_rateLimit_none_exhausted_returns_nil() {
        let header = #""burst";r=10;t=42"#
        XCTAssertNil(RateLimitHeader.maxResetForExhausted(header))
    }
}
