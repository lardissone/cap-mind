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
        let key = SymmetricKey(data: Data(secret.utf8))
        let mac = HMAC<SHA256>.authenticationCode(for: Data(signingInput.utf8), using: key)
        return "\(signingInput).\(Self.base64url(Data(mac)))"
    }

    static func base64url(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
