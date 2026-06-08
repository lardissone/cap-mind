import AppKit
import Foundation

enum DropPayload {
    /// Parsed result of a single dropped item; produced by DropController from the pasteboard.
    enum Item {
        case file(url: URL)
        case url(URL)
        case imageBitmap(Data)   // raw bitmap (tiff/png) needing PNG conversion
        case text(String)
    }

    static let supportedExtensions: Set<String> = [
        "jpg", "jpeg", "png", "gif", "webp", "avif", "heif", "heic", "jxl",
        "bmp", "tif", "tiff", "psd", "svg", "txt", "md", "pdf",
    ]

    static func isSupportedFileExtension(_ ext: String) -> Bool {
        supportedExtensions.contains(ext.lowercased())
    }

    static func isOversize(bytes: Int) -> Bool { bytes > AppConstants.maxUploadBytes }

    /// Returns a web URL when `text` is, on its own, a single http(s) link.
    /// Used to route URL-shaped text through MyMind's link unfurling instead of
    /// storing it as a plain note.
    static func detectURL(in text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https"
        else {
            return nil
        }
        return url
    }

    /// Flattens a formatted (rich-text) selection into Markdown, preserving the
    /// inline emphasis MyMind notes render: bold, italic, and links. Block-level
    /// structure (headings, lists) is not inferred — rich text carries no reliable
    /// semantic markers for it.
    static func markdown(from attributed: NSAttributedString) -> String {
        var result = ""
        let full = NSRange(location: 0, length: attributed.length)
        attributed.enumerateAttributes(in: full, options: []) { attributes, range, _ in
            let text = attributed.attributedSubstring(from: range).string
            let traits = (attributes[.font] as? NSFont)?.fontDescriptor.symbolicTraits ?? []
            var marker = ""
            if traits.contains(.bold) { marker += "**" }
            if traits.contains(.italic) { marker += "*" }
            var emphasised = marker + text + String(marker.reversed())
            if let href = linkHref(from: attributes[.link]) {
                emphasised = "[\(emphasised)](\(href))"
            }
            result += emphasised
        }
        return result
    }

    /// Normalises the `.link` attribute value (an NSURL or a String) to its string form.
    private static func linkHref(from value: Any?) -> String? {
        switch value {
        case let url as URL: return url.absoluteString
        case let string as String: return string
        default: return nil
        }
    }

    static func mimeType(forExtension ext: String) -> String {
        switch ext.lowercased() {
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "gif": return "image/gif"
        case "webp": return "image/webp"
        case "avif": return "image/avif"
        case "heif", "heic": return "image/heif"
        case "jxl": return "image/jxl"
        case "bmp": return "image/bmp"
        case "tif", "tiff": return "image/tiff"
        case "psd": return "image/vnd.adobe.photoshop"
        case "svg": return "image/svg+xml"
        case "txt": return "text/plain"
        case "md": return "text/markdown"
        case "pdf": return "application/pdf"
        default: return "application/octet-stream"
        }
    }
}
