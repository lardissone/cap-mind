import Foundation

enum MyMindError: Error, Equatable {
    case badRequest(String)
    case unauthorized
    case forbidden
    case notFound
    case payloadTooLarge
    case unprocessable(String)
    case rateLimited(retryAfterSeconds: Int)
    case server(String)
    case unavailable
    case network(URLError)
    case decoding(String)
    case unsupportedMime(String)
}
