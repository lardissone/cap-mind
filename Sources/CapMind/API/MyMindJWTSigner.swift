import Foundation
import CryptoKit

struct MyMindJWTSigner {
    let keyID: String
    let secret: String

    func sign(path: String, method: String, now: Date = Date()) throws -> String {
        let iat = Int(now.timeIntervalSince1970)
        let header = ["alg": "HS256", "kid": keyID]
        let claims: [String: Any] = ["path": path, "method": method, "iat": iat, "exp": iat + 300]
        let headerData = try JSONSerialization.data(withJSONObject: header, options: [.sortedKeys])
        let claimsData = try JSONSerialization.data(withJSONObject: claims, options: [.sortedKeys])
        let signingInput = "\(Self.base64url(headerData)).\(Self.base64url(claimsData))"
        // MyMind issues the secret as a base64-encoded 128-bit value; decode it to
        // the raw key bytes before signing — using the base64 text as the HMAC key
        // produces an invalid signature the server rejects with 401.
        guard let keyData = Self.decodeBase64(secret) else { throw MyMindError.unauthorized }
        let key = SymmetricKey(data: keyData)
        let mac = HMAC<SHA256>.authenticationCode(for: Data(signingInput.utf8), using: key)
        return "\(signingInput).\(Self.base64url(Data(mac)))"
    }

    /// Decodes a base64 string, tolerating URL-safe alphabet and missing padding.
    static func decodeBase64(_ string: String) -> Data? {
        var s = string.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while s.count % 4 != 0 { s += "=" }
        return Data(base64Encoded: s)
    }

    static func base64url(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
