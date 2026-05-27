import Foundation

struct MyMindCredentials: Equatable {
    let keyID: String
    let secret: String  // base secret string as shown once by MyMind
}

protocol CredentialsProviding: Sendable {
    /// Returns current credentials, or nil if not configured.
    func currentCredentials() -> MyMindCredentials?
}
