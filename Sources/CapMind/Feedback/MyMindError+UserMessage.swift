import Foundation

extension MyMindError {
    /// A short, human-readable description suitable for display in a toast or alert.
    var userMessage: String {
        switch self {
        case .unauthorized:
            return "Authentication failed. Check your access key."
        case .forbidden:
            return "Your key doesn't have permission for this action."
        case .payloadTooLarge:
            return "File too large (64 MB max)."
        case .unsupportedMime(let ext):
            return "MyMind doesn't accept .\(ext) files."
        case .unprocessable(let detail):
            return detail.isEmpty ? "MyMind couldn't process that." : detail
        case .rateLimited(let seconds):
            return "Rate limit hit. Retrying in \(seconds)s\u{2026}"
        case .server:
            return "MyMind is having issues. Try again in a minute."
        case .unavailable:
            return "MyMind is temporarily unavailable."
        case .network:
            return "No connection."
        case .notFound:
            return "Not found."
        case .badRequest(let detail):
            return detail.isEmpty ? "Bad request." : detail
        case .decoding:
            return "Unexpected response from MyMind."
        }
    }
}
