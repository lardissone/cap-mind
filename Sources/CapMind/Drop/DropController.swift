import AppKit
import Foundation

// MANUAL TEST: §14.9-14.14 checks
// §14.9  Drop a .png file onto the menu-bar icon → icon shows .aboutToReceive during hover,
//         reverts on exit, .sending during upload, .normal when done. Console: "Uploaded ✓".
// §14.10 Drop a .xyz file → console prints failure "Format not supported by MyMind (.xyz)",
//         NO network request is made (confirm with Charles/Proxyman).
// §14.11 Drop a file > 64 MB → console prints failure "File too large (64 MB max)", NO network.
// §14.12 Drop a web URL (e.g. https://example.com dragged from Safari address bar) →
//         createObjectFromURL is called; console: "Uploaded ✓".
// §14.13 Drop selected text → createObjectFromContent called; console: "Uploaded ✓".
// §14.14 Drop an image from Preview (bitmap, not a file) → PNG conversion, upload as
//         capmind-dropped-<timestamp>.png; console: "Uploaded ✓".
//         If conversion fails, console shows failure reason.

@MainActor
final class DropController {
    // MARK: - Progress / result closures (set by AppDelegate)

    /// Called with (completed, total) after each item finishes.
    var onProgress: (Int, Int) -> Void = { _, _ in }

    /// Called when all items have been processed.
    var onFinished: (_ succeeded: Int, _ failed: [String]) -> Void = { _, _ in }

    // MARK: - Private state

    private let client: MyMindClient
    private var isProcessing = false

    // MARK: - Init

    init(client: MyMindClient) {
        self.client = client
    }

    // MARK: - Public entry point

    /// Parse the pasteboard and process all items serially.
    func handle(_ pasteboard: NSPasteboard) {
        guard !isProcessing else { return }

        let items = parseItems(from: pasteboard)
        guard !items.isEmpty else {
            print("[DropController] Pasteboard contained no recognisable items.")
            return
        }

        let total = items.count
        isProcessing = true

        Task {
            var succeeded = 0
            var failures: [String] = []

            for (index, item) in items.enumerated() {
                do {
                    try await upload(item: item)
                    succeeded += 1
                } catch {
                    let reason = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    failures.append(reason)
                    print("[DropController] Item \(index + 1)/\(total) failed: \(reason)")
                }

                self.onProgress(index + 1, total)
            }

            let summary: String
            if failures.isEmpty {
                summary = total == 1 ? "Uploaded ✓" : "\(succeeded) uploaded ✓"
            } else {
                summary = "\(succeeded) uploaded, \(failures.count) failed"
            }
            print("[DropController] Done: \(summary)")
            self.isProcessing = false
            self.onFinished(succeeded, failures)
        }
    }

    // MARK: - Pasteboard parsing

    private func parseItems(from pasteboard: NSPasteboard) -> [DropPayload.Item] {
        // Branch 1: file URLs
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            let fileURLs = urls.filter { $0.isFileURL }
            if !fileURLs.isEmpty {
                return fileURLs.map { .file(url: $0) }
            }

            // Branch 2: web URLs (non-file) — return all of them
            let webURLs = urls.filter { !$0.isFileURL }
            if !webURLs.isEmpty {
                return webURLs.map { .url($0) }
            }
        }

        // Branch 3: image bitmap data (PNG first, then TIFF)
        if let data = pasteboard.data(forType: .png) {
            return [.imageBitmap(data)]
        }
        if let data = pasteboard.data(forType: .tiff) {
            return [.imageBitmap(data)]
        }

        // Branch 4: plain text fallback (also covers HTML-only drops via Cocoa's .string derivation)
        if let text = pasteboard.string(forType: .string), !text.isEmpty {
            return [.text(text)]
        }

        return []
    }

    // MARK: - Per-item upload

    private func upload(item: DropPayload.Item) async throws {
        switch item {
        case .file(let url):
            let ext = url.pathExtension
            guard DropPayload.isSupportedFileExtension(ext) else {
                throw DropError.unsupportedFormat(ext)
            }
            let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = (attrs[.size] as? Int) ?? 0
            guard !DropPayload.isOversize(bytes: fileSize) else { throw DropError.fileTooLarge }
            let data = try await Task.detached(priority: .userInitiated) { try Data(contentsOf: url) }.value
            let mime = DropPayload.mimeType(forExtension: ext)
            _ = try await client.createObjectFromFile(data, mimeType: mime, filename: url.lastPathComponent)

        case .url(let u):
            _ = try await client.createObjectFromURL(u)

        case .imageBitmap(let data):
            guard
                let rep = NSBitmapImageRep(data: data),
                let png = rep.representation(using: .png, properties: [:])
            else {
                throw DropError.imageBitmapConversionFailed
            }
            let timestamp = Int(Date().timeIntervalSince1970)
            let filename = "capmind-dropped-\(timestamp).png"
            _ = try await client.createObjectFromFile(png, mimeType: "image/png", filename: filename)

        case .text(let string):
            _ = try await client.createObjectFromContent(string)
        }
    }
}

// MARK: - DropError

private enum DropError: LocalizedError {
    case unsupportedFormat(String)
    case fileTooLarge
    case imageBitmapConversionFailed

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let ext):
            return "Format not supported by MyMind (.\(ext.lowercased()))"
        case .fileTooLarge:
            return "File too large (64 MB max)"
        case .imageBitmapConversionFailed:
            return "Could not convert dropped image to PNG"
        }
    }
}
