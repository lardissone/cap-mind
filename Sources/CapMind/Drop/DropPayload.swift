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
