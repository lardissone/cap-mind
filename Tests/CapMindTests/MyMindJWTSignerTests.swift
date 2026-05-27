import XCTest
import CryptoKit
@testable import CapMind

final class MyMindJWTSignerTests: XCTestCase {
    func test_base64url_noPadding() {
        XCTAssertEqual(MyMindJWTSigner.base64url(Data([0xfb])), "-w")
        XCTAssertEqual(MyMindJWTSigner.base64url(Data([0xff, 0xff])), "__8")
        XCTAssertEqual(MyMindJWTSigner.base64url(Data()), "")
    }

    func test_token_has_three_parts_and_decodable_header_and_claims() throws {
        let signer = MyMindJWTSigner(keyID: "kid-123", secret: "supersecret")
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let token = try signer.sign(path: "/objects", method: "POST", now: now)
        let parts = token.split(separator: ".").map(String.init)
        XCTAssertEqual(parts.count, 3)
        let header = try JSONSerialization.jsonObject(with: decodeB64url(parts[0])) as! [String: Any]
        XCTAssertEqual(header["alg"] as? String, "HS256")
        XCTAssertEqual(header["kid"] as? String, "kid-123")
        let claims = try JSONSerialization.jsonObject(with: decodeB64url(parts[1])) as! [String: Any]
        XCTAssertEqual(claims["path"] as? String, "/objects")
        XCTAssertEqual(claims["method"] as? String, "POST")
        XCTAssertEqual(claims["iat"] as? Int, 1_700_000_000)
        XCTAssertEqual(claims["exp"] as? Int, 1_700_000_300)
    }

    func test_signature_matches_manual_hmac() throws {
        let signer = MyMindJWTSigner(keyID: "k", secret: "s")
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let token = try signer.sign(path: "/objects", method: "GET", now: now)
        let parts = token.split(separator: ".").map(String.init)
        let signingInput = "\(parts[0]).\(parts[1])"
        let key = SymmetricKey(data: Data("s".utf8))
        let mac = HMAC<SHA256>.authenticationCode(for: Data(signingInput.utf8), using: key)
        XCTAssertEqual(parts[2], MyMindJWTSigner.base64url(Data(mac)))
    }

    private func decodeB64url(_ s: String) -> Data {
        var t = s.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while t.count % 4 != 0 { t += "=" }
        return Data(base64Encoded: t)!
    }
}
