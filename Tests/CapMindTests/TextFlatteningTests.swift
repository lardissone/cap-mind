import XCTest
import AppKit
@testable import CapMind

final class TextFlatteningTests: XCTestCase {
    func test_plain_text_passes_through() {
        let attributed = NSAttributedString(string: "just a note")
        XCTAssertEqual(DropPayload.markdown(from: attributed), "just a note")
    }
    func test_bold_run_becomes_double_asterisks() {
        let attributed = NSAttributedString(
            string: "hi",
            attributes: [.font: NSFont.boldSystemFont(ofSize: 13)]
        )
        XCTAssertEqual(DropPayload.markdown(from: attributed), "**hi**")
    }
    func test_italic_run_becomes_single_asterisks() {
        let italic = NSFontManager.shared.convert(.systemFont(ofSize: 13), toHaveTrait: .italicFontMask)
        let attributed = NSAttributedString(string: "hi", attributes: [.font: italic])
        XCTAssertEqual(DropPayload.markdown(from: attributed), "*hi*")
    }
    func test_bold_italic_run_becomes_triple_asterisks() {
        var font = NSFontManager.shared.convert(.systemFont(ofSize: 13), toHaveTrait: .italicFontMask)
        font = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
        let attributed = NSAttributedString(string: "hi", attributes: [.font: font])
        XCTAssertEqual(DropPayload.markdown(from: attributed), "***hi***")
    }
    func test_link_run_becomes_markdown_link() {
        let attributed = NSAttributedString(
            string: "the docs",
            attributes: [.link: URL(string: "https://example.com")!]
        )
        XCTAssertEqual(DropPayload.markdown(from: attributed), "[the docs](https://example.com)")
    }
    func test_link_with_string_value() {
        let attributed = NSAttributedString(
            string: "the docs",
            attributes: [.link: "https://example.com"]
        )
        XCTAssertEqual(DropPayload.markdown(from: attributed), "[the docs](https://example.com)")
    }
    func test_mixed_runs_concatenate() {
        let result = NSMutableAttributedString(string: "see ")
        result.append(NSAttributedString(string: "this",
                                         attributes: [.font: NSFont.boldSystemFont(ofSize: 13)]))
        result.append(NSAttributedString(string: " now"))
        XCTAssertEqual(DropPayload.markdown(from: result), "see **this** now")
    }
}
