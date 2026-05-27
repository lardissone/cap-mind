# CapMind Fase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a macOS 15 menu-bar app that writes notes, region screenshots, and dragged files/URLs/text to the MyMind public API with zero organization steps.

**Architecture:** A custom `NSStatusItem` (menu + drag destination) drives three `@MainActor` capture coordinators (note panel, region capture, drop handler) that all funnel into one stateless `MyMindClient` (URLSession + HS256 JWT signer + hand-built multipart + single-retry rate-limit backoff) talking to `https://api.mymind.com`. No local DB; `UserDefaults` holds settings + Key ID, Keychain holds the secret.

**Tech Stack:** Swift + SwiftUI/AppKit interop, Swift Package Manager (no committed `.xcodeproj`), CryptoKit (JWT), ScreenCaptureKit (capture), `sindresorhus/KeyboardShortcuts` (global hotkeys), `sparkle-project/Sparkle` (auto-update). Min macOS 15.0. No sandbox.

**Source spec:** Approved plan at `/Users/lardissone/.claude/plans/ayudame-a-armar-el-delegated-catmull.md` and the v0.1 PRD (committed to `docs/PRD.md` in Task 0.1). The PRD is the product source of truth; the spec's "API corrections" override the PRD's inline JSON examples.

> **Rebrand mode:** `CapMind` / `io.lardissone.capmind` are placeholders. Never bake the name into asset filenames or string concatenation; route the bundle id and Keychain service id through the constants in `AppConstants.swift` (Task 0.2).

> **CapNote calque:** `cap-note` is not local. Task 0.3 clones it read-only into `/tmp/cap-note-ref` as a pattern reference (UI panels, `PlainTextEditor`, Keychain wrapper, CI workflow). Mirror patterns; do not vendor code.

---

## File Structure

```
Sources/CapMind/
  CapMindApp.swift                 # @main, AppDelegate, .accessory policy, wires controllers
  AppConstants.swift               # bundleID, keychainService, apiBaseURL, defaults (rebrand seam)
  AppSettings.swift                # @Observable UserDefaults + Keychain bridge
  AppState.swift                   # @Observable runtime status + last error
  HotkeyName.swift                 # KeyboardShortcuts.Name + default shortcuts
  StatusItemController.swift       # owns NSStatusItem, menu, icon states
  Note/
    NotePanel.swift                # NSPanel subclass
    NotePanelController.swift      # show/hide, positioning, flip, submit pipeline
    NoteInputView.swift            # SwiftUI editor + footer
    PlainTextEditor.swift          # NSTextView wrapper (calque CapNote)
    SendStatus.swift               # enum idle/sending/sent/error
  Capture/
    RegionCaptureController.swift  # coordinator, one overlay per screen
    OverlayWindow.swift            # borderless NSWindow per display
    OverlayView.swift              # crosshair + live rect + dims, event handling
    ScreenshotCaptureService.swift # ScreenCaptureKit one-frame -> PNG
  Drop/
    StatusItemDropView.swift       # NSView w/ NSDraggingDestination
    DropController.swift           # pasteboard parsing -> client calls
    DropPayload.swift              # enum of parsed drop items (testable)
  API/
    MyMindClient.swift             # public async surface
    MyMindJWTSigner.swift          # HS256 via CryptoKit
    MyMindRequests.swift           # JSON + multipart builders (testable)
    MyMindModels.swift             # ObjectRef, ProblemJSON, RateLimit parser
    MyMindError.swift              # error enum
    CredentialsProviding.swift     # protocol for kid+secret (injectable in tests)
  Storage/
    Keychain.swift                 # generic-password wrapper
    LaunchAtLogin.swift            # SMAppService wrapper
  Settings/
    SettingsView.swift             # root + section switch
    AccountSection.swift
    ShortcutsSection.swift
    GeneralSection.swift
    UpdatesSection.swift
  Updates/
    Updater.swift                  # Sparkle wrapper
  Feedback/
    ToastController.swift          # menu-bar-anchored status popover
Tests/CapMindTests/
  MyMindJWTSignerTests.swift
  MyMindRequestsTests.swift
  MyMindModelsTests.swift          # ProblemJSON + RateLimit parsing
  MyMindClientTests.swift          # MockURLProtocol: retry + error mapping
  DropPayloadTests.swift           # pasteboard branch classification
  MockURLProtocol.swift            # test helper
```

---

## Phase 0 — Scaffold & Build Pipeline

### Task 0.1: Initialize SPM package and commit the PRD

**Files:**
- Create: `Package.swift`
- Create: `docs/PRD.md`
- Create: `.gitignore`

- [ ] **Step 1: Write `Package.swift`**

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CapMind",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.2.0"),
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0"),
    ],
    targets: [
        .executableTarget(
            name: "CapMind",
            dependencies: [
                "KeyboardShortcuts",
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Sources/CapMind"
        ),
        .testTarget(
            name: "CapMindTests",
            dependencies: ["CapMind"],
            path: "Tests/CapMindTests"
        ),
    ]
)
```

- [ ] **Step 2: Create `.gitignore`**

```
.DS_Store
.build/
*.xcodeproj
.swiftpm/
DerivedData/
*.app
*.zip
```

- [ ] **Step 3: Commit the PRD**

Save the full v0.1 PRD text (from the originating conversation) to `docs/PRD.md` verbatim.

- [ ] **Step 4: Verify the package resolves**

Run: `swift package resolve && swift build`
Expected: dependencies fetched; build succeeds (empty target is fine — add a stub `main.swift` if SPM complains about no entry point, removed in Task 1.1).

- [ ] **Step 5: Commit**

```bash
git add Package.swift .gitignore docs/PRD.md
git commit -m "chore: initialize SPM package, deps, and PRD"
```

### Task 0.2: Centralize rebrand constants

**Files:**
- Create: `Sources/CapMind/AppConstants.swift`

- [ ] **Step 1: Write the constants**

```swift
import Foundation

enum AppConstants {
    static let appName = "CapMind"
    static let bundleID = "io.lardissone.capmind"
    static let keychainService = "io.lardissone.capmind.api-secret"
    static let keychainAccount = "default"
    static let apiBaseURL = URL(string: "https://api.mymind.com")!
    static let manageKeysURL = URL(string: "https://access.mymind.com/extensions")!
    static let maxUploadBytes = 64 * 1024 * 1024  // 64 MB
    static var userAgent: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
        return "\(appName)/\(v) (macOS)"
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Sources/CapMind/AppConstants.swift
git commit -m "feat: add centralized app constants (rebrand seam)"
```

### Task 0.3: Clone CapNote as read-only reference

- [ ] **Step 1: Clone**

Run: `git clone --depth 1 https://github.com/lardissone/cap-note /tmp/cap-note-ref`
Expected: clone succeeds. (If the repo is private and clone fails, ask Leandro for access; do not block other phases — Phase 2 has zero CapNote dependency.)

- [ ] **Step 2: Note the reference files to mirror later**

Record paths for: `MenuBarExtra`/status item setup, `NSPanel` subclass + controller, `PlainTextEditor.swift`, `Storage/Keychain.swift`, GitHub Actions sign/notarize workflow, Sparkle appcast setup. No commit (read-only reference outside repo).

### Task 0.4: App bundle config + CI workflow

**Files:**
- Create: `Sources/CapMind/Info.plist` (or `Resources/Info.plist`, wired via build settings)
- Create: `.github/workflows/release.yml`

- [ ] **Step 1: Info.plist keys**

Include: `LSUIElement = true`, `NSScreenCaptureUsageDescription = "CapMind captures the screen region you select to send it to your mind."`, `CFBundleIdentifier = io.lardissone.capmind`, `SUFeedURL` (→ `gh-pages` appcast URL), `SUPublicEDKey` (Sparkle EdDSA public key), `LSMinimumSystemVersion = 15.0`.

- [ ] **Step 2: Port CapNote's release workflow**

Mirror `/tmp/cap-note-ref/.github/workflows/*.yml`: build → codesign with hardened runtime → notarize (`xcrun notarytool`) → staple → zip → create GitHub Release → generate + push appcast to `gh-pages` (Sparkle `generate_appcast`). Reuse the same secret names (signing cert, notarization Apple ID/team, Sparkle EdDSA private key) — document required repo secrets in the workflow header.

- [ ] **Step 3: Verify locally**

Run: `swift build -c release`
Expected: release build succeeds. (Full signing/notarization verified on CI + §14.17 clean-Mac test at the end.)

- [ ] **Step 4: Commit**

```bash
git add Sources/CapMind/Info.plist .github/workflows/release.yml
git commit -m "ci: add bundle config and signed/notarized release workflow"
```

---

## Phase 2 — MyMindClient core (TDD) — *do this before the UI phases; nothing here needs AppKit*

> Phase 2 is numbered to match the spec. Implement it right after Phase 0 so the UI phases can call a working client.

### Task 2.1: Credentials protocol + test mock

**Files:**
- Create: `Sources/CapMind/API/CredentialsProviding.swift`

- [ ] **Step 1: Define the protocol**

```swift
import Foundation

struct MyMindCredentials: Equatable {
    let keyID: String
    let secret: String  // base secret string as shown once by MyMind
}

protocol CredentialsProviding: Sendable {
    /// Returns current credentials, or nil if not configured.
    func currentCredentials() -> MyMindCredentials?
}
```

- [ ] **Step 2: Commit**

```bash
git add Sources/CapMind/API/CredentialsProviding.swift
git commit -m "feat: add CredentialsProviding protocol"
```

### Task 2.2: JWT signer (HS256)

**Files:**
- Create: `Tests/CapMindTests/MyMindJWTSignerTests.swift`
- Create: `Sources/CapMind/API/MyMindJWTSigner.swift`

- [ ] **Step 1: Write the failing tests**

```swift
import XCTest
import Crypto
@testable import CapMind

final class MyMindJWTSignerTests: XCTestCase {
    // RFC 7515 Appendix A.1 HS256 vector: known key + payload -> known signature.
    func test_base64url_noPadding() {
        XCTAssertEqual(MyMindJWTSigner.base64url(Data([0xfb])), "-w")      // would be "+w==" in std b64
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
        XCTAssertEqual(claims["exp"] as? Int, 1_700_000_300)  // iat + 300
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter MyMindJWTSignerTests`
Expected: FAIL — `MyMindJWTSigner` not defined.

- [ ] **Step 3: Implement the signer**

```swift
import Foundation
import Crypto

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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter MyMindJWTSignerTests`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/CapMind/API/MyMindJWTSigner.swift Tests/CapMindTests/MyMindJWTSignerTests.swift
git commit -m "feat: add HS256 JWT signer with path/method binding"
```

### Task 2.3: Error enum + models (ProblemJSON, ObjectRef, RateLimit parser)

**Files:**
- Create: `Sources/CapMind/API/MyMindError.swift`
- Create: `Tests/CapMindTests/MyMindModelsTests.swift`
- Create: `Sources/CapMind/API/MyMindModels.swift`

- [ ] **Step 1: Write the error enum**

```swift
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
    case unsupportedMime(String)   // pre-flight, never from server
}
```

- [ ] **Step 2: Write the failing model tests**

```swift
import XCTest
@testable import CapMind

final class MyMindModelsTests: XCTestCase {
    func test_objectRef_decodes_id_and_optional_fields() throws {
        let json = """
        {"id":"abc123","title":"X","url":"https://e.com","created":"2024-04-08T09:00:00Z",
         "modified":"2024-04-08T09:00:00Z","bumped":"2024-04-08T09:00:00Z"}
        """.data(using: .utf8)!
        let ref = try JSONDecoder().decode(ObjectRef.self, from: json)
        XCTAssertEqual(ref.id, "abc123")
        XCTAssertEqual(ref.title, "X")
    }

    func test_problemJSON_decodes_type_status_detail() throws {
        let json = #"{"type":"NotFound","status":404,"detail":"No object with that ID exists."}"#
            .data(using: .utf8)!
        let p = try JSONDecoder().decode(ProblemJSON.self, from: json)
        XCTAssertEqual(p.type, "NotFound")
        XCTAssertEqual(p.status, 404)
        XCTAssertEqual(p.detail, "No object with that ID exists.")
    }

    func test_rateLimit_picks_exhausted_policies_max_t() {
        let header = #""burst";r=0;t=42, "sustained";r=99641;t=2589945"#
        XCTAssertEqual(RateLimitHeader.maxResetForExhausted(header), 42)
    }

    func test_rateLimit_two_exhausted_takes_max() {
        let header = #""burst";r=0;t=42, "sustained";r=0;t=900"#
        XCTAssertEqual(RateLimitHeader.maxResetForExhausted(header), 900)
    }

    func test_rateLimit_none_exhausted_returns_nil() {
        let header = #""burst";r=10;t=42"#
        XCTAssertNil(RateLimitHeader.maxResetForExhausted(header))
    }
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `swift test --filter MyMindModelsTests`
Expected: FAIL — `ObjectRef`/`ProblemJSON`/`RateLimitHeader` not defined.

- [ ] **Step 4: Implement the models**

```swift
import Foundation

struct ObjectRef: Decodable, Equatable {
    let id: String
    let title: String?
    let url: String?
    let created: String?
    let modified: String?
    let bumped: String?
}

struct ProblemJSON: Decodable, Equatable {
    let type: String
    let status: Int
    let detail: String?
}

enum RateLimitHeader {
    /// Parses a `RateLimit` header value, returns the max `t` among policies with `r=0`, else nil.
    static func maxResetForExhausted(_ value: String) -> Int? {
        var maxT: Int?
        for policy in value.split(separator: ",") {
            var r: Int?
            var t: Int?
            for field in policy.split(separator: ";") {
                let kv = field.split(separator: "=", maxSplits: 1)
                guard kv.count == 2 else { continue }
                let k = kv[0].trimmingCharacters(in: .whitespaces)
                let v = Int(kv[1].trimmingCharacters(in: .whitespaces))
                if k == "r" { r = v }
                if k == "t" { t = v }
            }
            if r == 0, let t { maxT = max(maxT ?? 0, t) }
        }
        return maxT
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `swift test --filter MyMindModelsTests`
Expected: PASS (5 tests).

- [ ] **Step 6: Commit**

```bash
git add Sources/CapMind/API/MyMindError.swift Sources/CapMind/API/MyMindModels.swift Tests/CapMindTests/MyMindModelsTests.swift
git commit -m "feat: add MyMind error enum, models, and RateLimit header parser"
```

### Task 2.4: Request builders (JSON + multipart)

**Files:**
- Create: `Tests/CapMindTests/MyMindRequestsTests.swift`
- Create: `Sources/CapMind/API/MyMindRequests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
import XCTest
@testable import CapMind

final class MyMindRequestsTests: XCTestCase {
    func test_note_body_is_nested_markdown() throws {
        let data = try MyMindRequests.noteJSONBody(markdown: "# Hi\n\nbody")
        let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let content = obj["content"] as! [String: Any]
        XCTAssertEqual(content["type"] as? String, "text/markdown")
        XCTAssertEqual(content["body"] as? String, "# Hi\n\nbody")
        XCTAssertNil(obj["tags"])  // fase 1: no tags
    }

    func test_url_body() throws {
        let data = try MyMindRequests.urlJSONBody(url: URL(string: "https://e.com/a")!)
        let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(obj["url"] as? String, "https://e.com/a")
    }

    func test_multipart_frames_metadata_and_blob() {
        let blob = Data("PNGDATA".utf8)
        let (body, contentType) = MyMindRequests.multipart(
            boundary: "BNDRY", blob: blob, mimeType: "image/png", filename: "shot.png")
        XCTAssertEqual(contentType, "multipart/form-data; boundary=BNDRY")
        let s = String(data: body, encoding: .utf8)!
        XCTAssertTrue(s.contains("--BNDRY\r\n"))
        XCTAssertTrue(s.contains(#"Content-Disposition: form-data; name="metadata""#))
        XCTAssertTrue(s.contains("Content-Type: application/json\r\n\r\n{}\r\n"))
        XCTAssertTrue(s.contains(#"name="blob"; filename="shot.png""#))
        XCTAssertTrue(s.contains("Content-Type: image/png\r\n\r\nPNGDATA\r\n"))
        XCTAssertTrue(s.hasSuffix("--BNDRY--\r\n"))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter MyMindRequestsTests`
Expected: FAIL — `MyMindRequests` not defined.

- [ ] **Step 3: Implement the builders**

```swift
import Foundation

enum MyMindRequests {
    static func noteJSONBody(markdown: String) throws -> Data {
        let payload: [String: Any] = ["content": ["type": "text/markdown", "body": markdown]]
        return try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
    }

    static func urlJSONBody(url: URL) throws -> Data {
        try JSONSerialization.data(withJSONObject: ["url": url.absoluteString], options: [.sortedKeys])
    }

    /// Builds multipart body with empty metadata `{}` and the binary blob. Returns (body, Content-Type).
    static func multipart(boundary: String = UUID().uuidString,
                          blob: Data, mimeType: String, filename: String) -> (Data, String) {
        var body = Data()
        func append(_ s: String) { body.append(Data(s.utf8)) }

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"metadata\"\r\n")
        append("Content-Type: application/json\r\n\r\n")
        append("{}\r\n")

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"blob\"; filename=\"\(filename)\"\r\n")
        append("Content-Type: \(mimeType)\r\n\r\n")
        body.append(blob)
        append("\r\n")

        append("--\(boundary)--\r\n")
        return (body, "multipart/form-data; boundary=\(boundary)")
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter MyMindRequestsTests`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/CapMind/API/MyMindRequests.swift Tests/CapMindTests/MyMindRequestsTests.swift
git commit -m "feat: add JSON + multipart request builders"
```

### Task 2.5: MyMindClient with retry + error mapping

**Files:**
- Create: `Tests/CapMindTests/MockURLProtocol.swift`
- Create: `Tests/CapMindTests/MyMindClientTests.swift`
- Create: `Sources/CapMind/API/MyMindClient.swift`

- [ ] **Step 1: Write the MockURLProtocol helper**

```swift
import Foundation

final class MockURLProtocol: URLProtocol {
    /// Each call returns (status, headers, body). Queue multiple to simulate retry.
    nonisolated(unsafe) static var responses: [(Int, [String: String], Data)] = []
    nonisolated(unsafe) static var requestCount = 0

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let idx = min(Self.requestCount, Self.responses.count - 1)
        Self.requestCount += 1
        let (status, headers, body) = Self.responses[idx]
        let resp = HTTPURLResponse(url: request.url!, statusCode: status,
                                   httpVersion: nil, headerFields: headers)!
        client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}

    static func reset() { responses = []; requestCount = 0 }
    static func session() -> URLSession {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: cfg)
    }
}

struct StubCredentials: CredentialsProviding {
    var creds: MyMindCredentials? = .init(keyID: "k", secret: "s")
    func currentCredentials() -> MyMindCredentials? { creds }
}
```

- [ ] **Step 2: Write the failing client tests**

```swift
import XCTest
@testable import CapMind

final class MyMindClientTests: XCTestCase {
    override func setUp() { MockURLProtocol.reset() }

    private func makeClient() -> MyMindClient {
        MyMindClient(credentialsProvider: StubCredentials(), urlSession: MockURLProtocol.session())
    }

    func test_createNote_success_returns_objectRef() async throws {
        MockURLProtocol.responses = [(201, [:], Data(#"{"id":"obj1"}"#.utf8))]
        let ref = try await makeClient().createObjectFromContent("hello")
        XCTAssertEqual(ref.id, "obj1")
    }

    func test_missing_credentials_throws_unauthorized() async {
        let client = MyMindClient(credentialsProvider: StubCredentials(creds: nil),
                                  urlSession: MockURLProtocol.session())
        await assertThrows(MyMindError.unauthorized) { try await client.createObjectFromContent("x") }
    }

    func test_401_maps_to_unauthorized() async {
        MockURLProtocol.responses = [(401, [:], Data(#"{"type":"Unauthorized","status":401}"#.utf8))]
        await assertThrows(MyMindError.unauthorized) { try await makeClient().createObjectFromContent("x") }
    }

    func test_413_maps_to_payloadTooLarge() async {
        MockURLProtocol.responses = [(413, [:], Data(#"{"type":"PayloadTooLarge","status":413}"#.utf8))]
        await assertThrows(MyMindError.payloadTooLarge) {
            try await makeClient().createObjectFromFile(Data([0]), mimeType: "image/png", filename: "a.png")
        }
    }

    func test_429_retries_once_then_succeeds() async throws {
        MockURLProtocol.responses = [
            (429, ["RateLimit": #""burst";r=0;t=0"#], Data(#"{"type":"RateLimited","status":429}"#.utf8)),
            (201, [:], Data(#"{"id":"obj2"}"#.utf8)),
        ]
        let ref = try await makeClient().createObjectFromContent("retry me")
        XCTAssertEqual(ref.id, "obj2")
        XCTAssertEqual(MockURLProtocol.requestCount, 2)  // original + one retry
    }

    func test_429_twice_surfaces_rateLimited() async {
        MockURLProtocol.responses = [
            (429, ["RateLimit": #""burst";r=0;t=0"#], Data(#"{"type":"RateLimited","status":429}"#.utf8)),
            (429, ["RateLimit": #""burst";r=0;t=0"#], Data(#"{"type":"RateLimited","status":429}"#.utf8)),
        ]
        await assertThrows(MyMindError.rateLimited(retryAfterSeconds: 0)) {
            try await makeClient().createObjectFromContent("x")
        }
    }

    // Helper: assert a specific MyMindError is thrown.
    private func assertThrows(_ expected: MyMindError,
                              _ block: () async throws -> Void,
                              file: StaticString = #filePath, line: UInt = #line) async {
        do { try await block(); XCTFail("expected throw", file: file, line: line) }
        catch let e as MyMindError { XCTAssertEqual(e, expected, file: file, line: line) }
        catch { XCTFail("wrong error \(error)", file: file, line: line) }
    }
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `swift test --filter MyMindClientTests`
Expected: FAIL — `MyMindClient` not defined.

- [ ] **Step 4: Implement the client**

```swift
import Foundation

final class MyMindClient {
    private let credentials: CredentialsProviding
    private let session: URLSession

    init(credentialsProvider: CredentialsProviding, urlSession: URLSession = .shared) {
        self.credentials = credentialsProvider
        self.session = urlSession
    }

    func createObjectFromContent(_ markdown: String) async throws -> ObjectRef {
        let body = try MyMindRequests.noteJSONBody(markdown: markdown)
        return try await postJSON(path: "/objects", body: body)
    }

    func createObjectFromURL(_ url: URL) async throws -> ObjectRef {
        let body = try MyMindRequests.urlJSONBody(url: url)
        return try await postJSON(path: "/objects", body: body)
    }

    func createObjectFromFile(_ data: Data, mimeType: String, filename: String) async throws -> ObjectRef {
        let (body, contentType) = MyMindRequests.multipart(blob: data, mimeType: mimeType, filename: filename)
        return try await send(path: "/objects", method: "POST", body: body, contentType: contentType)
    }

    func testConnection() async throws {
        _ = try await request(path: "/objects?limit=1", signPath: "/objects", method: "GET",
                              body: nil, contentType: nil, allowRetry: false)
    }

    // MARK: - Internals

    private func postJSON(path: String, body: Data) async throws -> ObjectRef {
        try await send(path: path, method: "POST", body: body, contentType: "application/json")
    }

    private func send(path: String, method: String, body: Data?, contentType: String?) async throws -> ObjectRef {
        let data = try await request(path: path, signPath: path, method: method,
                                     body: body, contentType: contentType, allowRetry: true)
        do { return try JSONDecoder().decode(ObjectRef.self, from: data) }
        catch { throw MyMindError.decoding(String(describing: error)) }
    }

    /// Performs the request; on 429 with retry allowed, sleeps to reset and retries once.
    private func request(path: String, signPath: String, method: String,
                         body: Data?, contentType: String?, allowRetry: Bool) async throws -> Data {
        guard let creds = credentials.currentCredentials() else { throw MyMindError.unauthorized }

        let signer = MyMindJWTSigner(keyID: creds.keyID, secret: creds.secret)
        let jwt = try signer.sign(path: signPath, method: method)

        var req = URLRequest(url: AppConstants.apiBaseURL.appendingPathComponent(path.hasPrefix("/") ? String(path.dropFirst()) : path))
        // Use the exact path (including query) — build URL from base + path string:
        if let full = URL(string: AppConstants.apiBaseURL.absoluteString + path) { req.url = full }
        req.httpMethod = method
        req.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        req.setValue(AppConstants.userAgent, forHTTPHeaderField: "User-Agent")
        if let contentType { req.setValue(contentType, forHTTPHeaderField: "Content-Type") }
        req.httpBody = body

        let (data, response): (Data, URLResponse)
        do { (data, response) = try await session.data(for: req) }
        catch let urlError as URLError { throw MyMindError.network(urlError) }

        guard let http = response as? HTTPURLResponse else { throw MyMindError.unavailable }

        if (200...299).contains(http.statusCode) { return data }

        let problem = try? JSONDecoder().decode(ProblemJSON.self, from: data)
        let mapped = Self.mapError(status: http.statusCode, problem: problem,
                                   rateLimitHeader: http.value(forHTTPHeaderField: "RateLimit"))

        if case .rateLimited(let secs) = mapped, allowRetry {
            if secs > 0 { try await Task.sleep(nanoseconds: UInt64(secs) * 1_000_000_000) }
            return try await request(path: path, signPath: signPath, method: method,
                                     body: body, contentType: contentType, allowRetry: false)
        }
        throw mapped
    }

    static func mapError(status: Int, problem: ProblemJSON?, rateLimitHeader: String?) -> MyMindError {
        let detail = problem?.detail ?? ""
        switch status {
        case 400: return .badRequest(detail)
        case 401: return .unauthorized
        case 403: return .forbidden
        case 404: return .notFound
        case 413: return .payloadTooLarge
        case 422: return .unprocessable(detail)
        case 429:
            let secs = rateLimitHeader.flatMap(RateLimitHeader.maxResetForExhausted) ?? 1
            return .rateLimited(retryAfterSeconds: secs)
        case 503: return .unavailable
        case 500...599: return .server(detail)
        default: return .server(detail)
        }
    }
}
```

> Note: simplify the URL construction in review — keep only the `URL(string: base + path)` line; the first `appendingPathComponent` line is redundant. Left explicit here so the engineer sees query strings (`?limit=1`) must survive.

- [ ] **Step 5: Run tests to verify they pass**

Run: `swift test --filter MyMindClientTests`
Expected: PASS (6 tests).

- [ ] **Step 6: Run the full suite**

Run: `swift test`
Expected: all Phase 2 tests PASS (§14.19 unit coverage for JWT, multipart, models, client).

- [ ] **Step 7: Commit**

```bash
git add Sources/CapMind/API/MyMindClient.swift Tests/CapMindTests/MockURLProtocol.swift Tests/CapMindTests/MyMindClientTests.swift
git commit -m "feat: add MyMindClient with single-retry backoff and error mapping"
```

---

## Phase 1 — App shell, status item, settings storage

### Task 1.1: Keychain wrapper + LaunchAtLogin

**Files:**
- Create: `Sources/CapMind/Storage/Keychain.swift`
- Create: `Sources/CapMind/Storage/LaunchAtLogin.swift`

- [ ] **Step 1: Keychain wrapper** (calque `/tmp/cap-note-ref/.../Keychain.swift`; service from `AppConstants`)

```swift
import Foundation
import Security

enum Keychain {
    static func set(_ value: String?) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: AppConstants.keychainService,
            kSecAttrAccount as String: AppConstants.keychainAccount,
        ]
        SecItemDelete(query as CFDictionary)
        guard let value, let data = value.data(using: .utf8) else { return }
        var add = query
        add[kSecValueData as String] = data
        SecItemAdd(add as CFDictionary, nil)
    }

    static func get() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: AppConstants.keychainService,
            kSecAttrAccount as String: AppConstants.keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
```

- [ ] **Step 2: LaunchAtLogin**

```swift
import ServiceManagement

enum LaunchAtLogin {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }
    static func set(_ enabled: Bool) throws {
        if enabled { try SMAppService.mainApp.register() }
        else { try SMAppService.mainApp.unregister() }
    }
}
```

- [ ] **Step 3: Verify build**

Run: `swift build`
Expected: succeeds.

- [ ] **Step 4: Commit**

```bash
git add Sources/CapMind/Storage/
git commit -m "feat: add Keychain and LaunchAtLogin wrappers"
```

### Task 1.2: AppSettings, AppState, HotkeyName

**Files:**
- Create: `Sources/CapMind/AppSettings.swift`
- Create: `Sources/CapMind/AppState.swift`
- Create: `Sources/CapMind/HotkeyName.swift`

- [ ] **Step 1: HotkeyName with defaults**

```swift
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let openNote = Self("openNote", default: .init(.m, modifiers: [.command, .shift, .option]))
    static let captureRegion = Self("captureRegion", default: .init(.s, modifiers: [.command, .shift, .option]))
}
```

- [ ] **Step 2: AppSettings** (UserDefaults-backed; conforms to `CredentialsProviding`)

```swift
import Foundation
import Observation

enum PanelPosition: String, CaseIterable { case lastUsed, centered, atCursor }
enum IconStyle: String, CaseIterable { case outline, filled }

@Observable
final class AppSettings: CredentialsProviding {
    var keyID: String {
        didSet { UserDefaults.standard.set(keyID, forKey: "keyID") }
    }
    var panelPosition: PanelPosition {
        didSet { UserDefaults.standard.set(panelPosition.rawValue, forKey: "panelPosition") }
    }
    var alwaysOnTop: Bool { didSet { UserDefaults.standard.set(alwaysOnTop, forKey: "alwaysOnTop") } }
    var iconStyle: IconStyle { didSet { UserDefaults.standard.set(iconStyle.rawValue, forKey: "iconStyle") } }

    init() {
        let d = UserDefaults.standard
        keyID = d.string(forKey: "keyID") ?? ""
        panelPosition = PanelPosition(rawValue: d.string(forKey: "panelPosition") ?? "") ?? .centered
        alwaysOnTop = d.object(forKey: "alwaysOnTop") as? Bool ?? true
        iconStyle = IconStyle(rawValue: d.string(forKey: "iconStyle") ?? "") ?? .outline
    }

    var secret: String? { Keychain.get() }
    func setSecret(_ value: String?) { Keychain.set(value) }
    var isConfigured: Bool { !keyID.isEmpty && (secret?.isEmpty == false) }

    func currentCredentials() -> MyMindCredentials? {
        guard !keyID.isEmpty, let s = secret, !s.isEmpty else { return nil }
        return MyMindCredentials(keyID: keyID, secret: s)
    }
}
```

- [ ] **Step 3: AppState**

```swift
import Observation

@MainActor
@Observable
final class AppState {
    enum Status: Equatable { case ready, sending, error(String) }
    var status: Status = .ready
    var isConfigured: Bool = false
}
```

- [ ] **Step 4: Verify build**

Run: `swift build`
Expected: succeeds.

- [ ] **Step 5: Commit**

```bash
git add Sources/CapMind/AppSettings.swift Sources/CapMind/AppState.swift Sources/CapMind/HotkeyName.swift
git commit -m "feat: add settings, runtime state, and hotkey definitions"
```

### Task 1.3: App entry, AppDelegate, StatusItemController

**Files:**
- Create: `Sources/CapMind/CapMindApp.swift`
- Create: `Sources/CapMind/StatusItemController.swift`
- Delete stub `main.swift` if created in Task 0.1.

- [ ] **Step 1: StatusItemController** (custom `NSStatusItem`; drop view wired in Phase 5)

```swift
import AppKit

@MainActor
final class StatusItemController {
    enum Icon { case normal, attention, sending, aboutToReceive }

    let statusItem: NSStatusItem
    private let settings: AppSettings
    var onNewNote: () -> Void = {}
    var onCaptureRegion: () -> Void = {}
    var onOpenSettings: () -> Void = {}
    var onCheckForUpdates: () -> Void = {}

    init(settings: AppSettings) {
        self.settings = settings
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        setIcon(settings.isConfigured ? .normal : .attention)
        buildMenu()
    }

    func setIcon(_ icon: Icon) {
        let name: String
        switch icon {
        case .normal:          name = settings.iconStyle == .filled ? "tray.fill" : "tray"
        case .attention:       name = "tray.and.arrow.down"   // tinted red via image template off
        case .sending:         name = "tray.and.arrow.up"
        case .aboutToReceive:  name = "tray.and.arrow.down.fill"
        }
        statusItem.button?.image = NSImage(systemSymbolName: name, accessibilityDescription: AppConstants.appName)
        statusItem.button?.contentTintColor = (icon == .attention) ? .systemRed : nil
    }

    private func buildMenu() {
        let menu = NSMenu()
        let status = NSMenuItem(title: "Ready", action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        menu.addItem(NSMenuItem(title: "New note", action: #selector(newNote), keyEquivalent: "n").targeting(self))
        menu.addItem(NSMenuItem(title: "Capture region", action: #selector(capture), keyEquivalent: "").targeting(self))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Open Settings…", action: #selector(openSettings), keyEquivalent: ",").targeting(self))
        menu.addItem(NSMenuItem(title: "Check for Updates…", action: #selector(checkUpdates), keyEquivalent: "").targeting(self))
        menu.addItem(NSMenuItem(title: "About \(AppConstants.appName)", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    @objc private func newNote() { onNewNote() }
    @objc private func capture() { onCaptureRegion() }
    @objc private func openSettings() { onOpenSettings() }
    @objc private func checkUpdates() { onCheckForUpdates() }
}

private extension NSMenuItem {
    func targeting(_ target: AnyObject) -> NSMenuItem { self.target = target; return self }
}
```

> Note: assigning `statusItem.menu` makes click-to-open-menu work but **disables** the button's drag-destination. Phase 5 replaces this with a custom button view that shows the menu on plain click and accepts drops; revisit `buildMenu`/`statusItem.menu` wiring there.

- [ ] **Step 2: CapMindApp + AppDelegate**

```swift
import SwiftUI
import KeyboardShortcuts

@main
struct CapMindApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene { Settings { EmptyView() } }  // no main window
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings = AppSettings()
    let appState = AppState()
    private var statusController: StatusItemController!
    private(set) var client: MyMindClient!
    // Controllers added in later phases:
    // var notePanelController: NotePanelController!
    // var regionCaptureController: RegionCaptureController!
    // var dropController: DropController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        client = MyMindClient(credentialsProvider: settings)
        appState.isConfigured = settings.isConfigured

        statusController = StatusItemController(settings: settings)
        statusController.onOpenSettings = { /* Phase 6: open settings panel */ }
        statusController.onNewNote = { /* Phase 3 */ }
        statusController.onCaptureRegion = { /* Phase 4 */ }

        KeyboardShortcuts.onKeyDown(for: .openNote) { /* Phase 3 */ }
        KeyboardShortcuts.onKeyDown(for: .captureRegion) { /* Phase 4 */ }
    }
}
```

- [ ] **Step 3: Verify §14.1 + §14.16 manually**

Run: `swift run`
Expected: no Dock icon, no app in ⌘-Tab, an icon appears in the menu bar (red tint since unconfigured). Click → menu shows. Quit via menu.
Then run: `pgrep -fl CapMind` → should print nothing after quit (§14.16).

- [ ] **Step 4: Commit**

```bash
git add Sources/CapMind/CapMindApp.swift Sources/CapMind/StatusItemController.swift
git commit -m "feat: add app shell, accessory policy, and status item menu"
```

---

## Phase 3 — Note panel

### Task 3.1: PlainTextEditor + SendStatus

**Files:**
- Create: `Sources/CapMind/Note/SendStatus.swift`
- Create: `Sources/CapMind/Note/PlainTextEditor.swift`

- [ ] **Step 1: SendStatus**

```swift
enum SendStatus: Equatable {
    case idle, sending, sent, error(String)
}
```

- [ ] **Step 2: PlainTextEditor** (calque `/tmp/cap-note-ref/.../PlainTextEditor.swift`)

`NSViewRepresentable` over `NSTextView`. Must: disable `isAutomaticQuoteSubstitutionEnabled`, `isAutomaticDashSubstitutionEnabled`, `isAutomaticTextReplacementEnabled`; use a monospaced/system font; bind text; intercept `⌘↩` via a custom `NSTextView` subclass overriding `keyDown` → call an `onSubmit` closure; intercept `Esc` → `onCancel`. Expose `@Binding var text`, `onSubmit`, `onCancel`.

- [ ] **Step 3: Verify build**

Run: `swift build`
Expected: succeeds.

- [ ] **Step 4: Commit**

```bash
git add Sources/CapMind/Note/SendStatus.swift Sources/CapMind/Note/PlainTextEditor.swift
git commit -m "feat: add plain text editor and send status"
```

### Task 3.2: NotePanel + NotePanelController + NoteInputView

**Files:**
- Create: `Sources/CapMind/Note/NotePanel.swift`
- Create: `Sources/CapMind/Note/NoteInputView.swift`
- Create: `Sources/CapMind/Note/NotePanelController.swift`
- Modify: `Sources/CapMind/CapMindApp.swift` (wire `onNewNote` + hotkey)

- [ ] **Step 1: NotePanel**

```swift
import AppKit

final class NotePanel: NSPanel {
    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 480, height: 260),
                   styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
                   backing: .buffered, defer: false)
        level = .floating
        hidesOnDeactivate = false
        isFloatingPanel = true
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = true
    }
    override var canBecomeKey: Bool { true }
}
```

- [ ] **Step 2: NoteInputView** — SwiftUI: `PlainTextEditor` with placeholder "Drop a thought into your mind…", a footer showing `SendStatus` (Sending…/Sent/inline error) and the send affordance. `⌘↩` → submit, `Esc` → cancel, `⌘⌥t` → toggle always-on-top, `⌘,` → flip to Settings.

- [ ] **Step 3: NotePanelController** (`@MainActor` singleton): owns `NotePanel` + `NSHostingView`. Methods: `show()` (positions per `settings.panelPosition`: centered on active `NSScreen`, at `NSEvent.mouseLocation`, or last-used frame; sets `level` per always-on-top), `hide()`, `submit()` (sets status sending → `client.createObjectFromContent` → on success status sent for 600ms then hide + clear buffer; on failure keep open, set `.error`, keep text), `flipToSettings()`. Manage status timing: 200ms sending min, 600ms sent.

- [ ] **Step 4: Wire into AppDelegate**

```swift
notePanelController = NotePanelController(client: client, settings: settings, appState: appState)
statusController.onNewNote = { [weak self] in self?.notePanelController.show() }
KeyboardShortcuts.onKeyDown(for: .openNote) { [weak self] in self?.notePanelController.show() }
```

- [ ] **Step 5: Verify §14.3 / §14.4 / §14.5 manually** (requires a real key configured — do after Phase 6, or temporarily hardcode credentials in a throwaway build)

`⌘⇧⌥M` opens the panel over the active app without stealing background focus. Type "Hello from CapMind", `⌘↩` → object appears in MyMind web. `Esc` closes and discards.

- [ ] **Step 6: Commit**

```bash
git add Sources/CapMind/Note/ Sources/CapMind/CapMindApp.swift
git commit -m "feat: add floating note panel with submit pipeline"
```

---

## Phase 4 — Region capture

### Task 4.1: ScreenshotCaptureService

**Files:**
- Create: `Sources/CapMind/Capture/ScreenshotCaptureService.swift`

- [ ] **Step 1: Implement one-frame ScreenCaptureKit capture → PNG**

```swift
import ScreenCaptureKit
import CoreImage
import AppKit

enum CaptureError: Error { case noDisplay, noPermission, captureFailed }

final class ScreenshotCaptureService {
    /// Captures `rect` (in the display's points) from `display` at native resolution, returns PNG data.
    func capturePNG(display: SCDisplay, rect: CGRect, scale: CGFloat) async throws -> Data {
        guard CGPreflightScreenCaptureAccess() else { throw CaptureError.noPermission }

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.sourceRect = rect
        config.width = Int(rect.width * scale)
        config.height = Int(rect.height * scale)
        config.captureResolution = .best
        config.showsCursor = false

        let cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        let ci = CIImage(cgImage: cgImage)
        let ctx = CIContext()
        guard let png = ctx.pngRepresentation(of: ci, format: .RGBA8,
              colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!) else { throw CaptureError.captureFailed }
        return png
    }

    static func requestPermissionIfNeeded() -> Bool {
        if CGPreflightScreenCaptureAccess() { return true }
        return CGRequestScreenCaptureAccess()
    }
}
```

> `SCScreenshotManager.captureImage` (macOS 14+) is the simplest one-shot path; prefer it over building an `SCStream`. Map `SCDisplay` from the target `NSScreen` via `SCShareableContent.current`.

- [ ] **Step 2: Verify build**

Run: `swift build`
Expected: succeeds.

- [ ] **Step 3: Commit**

```bash
git add Sources/CapMind/Capture/ScreenshotCaptureService.swift
git commit -m "feat: add ScreenCaptureKit screenshot service"
```

### Task 4.2: Overlay window/view + RegionCaptureController

**Files:**
- Create: `Sources/CapMind/Capture/OverlayWindow.swift`
- Create: `Sources/CapMind/Capture/OverlayView.swift`
- Create: `Sources/CapMind/Capture/RegionCaptureController.swift`
- Modify: `Sources/CapMind/CapMindApp.swift`

- [ ] **Step 1: OverlayWindow** — borderless `NSWindow` per `NSScreen`, `level = .screenSaver`, `backgroundColor = .clear`, `isOpaque = false`, `ignoresMouseEvents = false`, covers the screen frame.

- [ ] **Step 2: OverlayView** — `NSView` (layer-backed): dim `CALayer` (black ~0.25 alpha), crosshair, and a `CAShapeLayer` rect updated on `mouseDragged` with a "punch-through" clear region + a px-dimensions label near the cursor. Handle `mouseDown` (anchor), `mouseDragged` (update rect + label), `mouseUp` (finalize → callback with rect in screen points), `keyDown` (Esc → cancel callback). Override `acceptsFirstResponder = true`.

- [ ] **Step 3: RegionCaptureController** — `begin()`: enumerate `NSScreen.screens`, create one `OverlayWindow` each, make key, set crosshair cursor. On any overlay's `mouseUp`: close ALL overlays, resolve the origin display's `SCDisplay` + scale, convert the selection rect to that display's coordinate space, call `ScreenshotCaptureService.capturePNG`, then `client.createObjectFromFile(png, mimeType: "image/png", filename: "capmind-<timestamp>.png")`, driving the toast. On Esc from any overlay: close all, no upload. On permission denial: alert with button opening `x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture`.

- [ ] **Step 4: Wire into AppDelegate** (`onCaptureRegion` + `.captureRegion` hotkey → `regionCaptureController.begin()`).

- [ ] **Step 5: Verify §14.6 / §14.7 / §14.8 manually**

`⌘⇧⌥S` → overlay on all displays, live px dims while dragging. Release → overlay closes, PNG uploads at native res, toast `Uploaded ✓`, object correct in MyMind. `Esc` mid-drag cancels with no upload. Also verify the screen-recording-denied alert + deep link on first run / after revoking permission.

- [ ] **Step 6: Commit**

```bash
git add Sources/CapMind/Capture/ Sources/CapMind/CapMindApp.swift
git commit -m "feat: add multi-display region capture overlay and pipeline"
```

---

## Phase 5 — Drag-and-drop onto the icon

### Task 5.1: DropPayload classification (TDD-able core)

**Files:**
- Create: `Tests/CapMindTests/DropPayloadTests.swift`
- Create: `Sources/CapMind/Drop/DropPayload.swift`

- [ ] **Step 1: Write the failing tests**

```swift
import XCTest
@testable import CapMind

final class DropPayloadTests: XCTestCase {
    func test_supported_extension_check() {
        XCTAssertTrue(DropPayload.isSupportedFileExtension("png"))
        XCTAssertTrue(DropPayload.isSupportedFileExtension("PDF"))   // case-insensitive
        XCTAssertTrue(DropPayload.isSupportedFileExtension("heic"))
        XCTAssertFalse(DropPayload.isSupportedFileExtension("xyz"))
        XCTAssertFalse(DropPayload.isSupportedFileExtension("mp4"))  // video out of scope fase 1
    }

    func test_mimeType_for_extension() {
        XCTAssertEqual(DropPayload.mimeType(forExtension: "png"), "image/png")
        XCTAssertEqual(DropPayload.mimeType(forExtension: "jpg"), "image/jpeg")
        XCTAssertEqual(DropPayload.mimeType(forExtension: "md"), "text/markdown")
        XCTAssertEqual(DropPayload.mimeType(forExtension: "pdf"), "application/pdf")
    }

    func test_oversize_check() {
        XCTAssertTrue(DropPayload.isOversize(bytes: 70 * 1024 * 1024))
        XCTAssertFalse(DropPayload.isOversize(bytes: 10 * 1024 * 1024))
    }
}
```

- [ ] **Step 2: Run to verify fail**

Run: `swift test --filter DropPayloadTests`
Expected: FAIL — `DropPayload` not defined.

- [ ] **Step 3: Implement**

```swift
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
        "jpg","jpeg","png","gif","webp","avif","heif","heic","jxl",
        "bmp","tif","tiff","psd","svg","txt","md","pdf",
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
```

- [ ] **Step 4: Run to verify pass**

Run: `swift test --filter DropPayloadTests`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/CapMind/Drop/DropPayload.swift Tests/CapMindTests/DropPayloadTests.swift
git commit -m "feat: add drop payload classification helpers"
```

### Task 5.2: StatusItemDropView + DropController + status-item rewire

**Files:**
- Create: `Sources/CapMind/Drop/StatusItemDropView.swift`
- Create: `Sources/CapMind/Drop/DropController.swift`
- Modify: `Sources/CapMind/StatusItemController.swift` (use a custom button view that both shows the menu on click and accepts drops)
- Modify: `Sources/CapMind/CapMindApp.swift`

- [ ] **Step 1: StatusItemDropView** — `NSView` registering `[.fileURL, .string, .URL, .tiff, .png, .pdf]`. `draggingEntered` → `onAboutToReceive(true)` (icon `.aboutToReceive`) + return `.copy`; `draggingExited`/`draggingEnded` → `onAboutToReceive(false)`; `performDragOperation` → hand the `NSPasteboard` to `DropController`. On plain `mouseDown` (no drag), pop the menu (`statusItem.menu` or `NSMenu.popUp`).

- [ ] **Step 2: DropController.handle(pasteboard:)** — extract items in branch order and produce `[DropPayload.Item]`:
  1. `.fileURL` items → `.file(url)` each.
  2. else `.URL` (web) → `.url`.
  3. else image bitmap (`.png`/`.tiff` data) → `.imageBitmap`.
  4. else `.string` → `.text` (plain-text fallback; if only HTML present, read `NSPasteboard.PasteboardType.string` which Cocoa derives from HTML).

  Then process **serially**: for each item, drive toast progress `n/m`; for `.file`, pre-flight extension + size (`isSupportedFileExtension`, `isOversize`) → on fail emit per-item error (unsupported → "Format not supported by MyMind (.xyz)"; oversize → "File too large (64 MB max)") and continue; else read data + `mimeType` → `client.createObjectFromFile`. `.url` → `createObjectFromURL`. `.imageBitmap` → convert to PNG via `NSBitmapImageRep` → `createObjectFromFile(mime:"image/png")`. `.text` → `createObjectFromContent`. Collect successes/failures; final toast "N uploaded, M failed" (clickable to list failures).

- [ ] **Step 3: Rewire StatusItemController** — replace `statusItem.menu =` assignment with the custom `StatusItemDropView` as `statusItem.button`'s subview (or set the button's `target`/`action` to a handler that pops the menu, and add the drop view on top). Verify clicking still shows the menu AND drops are received (the §16 risk; the custom view is the committed path).

- [ ] **Step 4: Wire AppDelegate** — construct `DropController(client:appState:toast:)`, pass to status controller.

- [ ] **Step 5: Verify §14.9–§14.14 manually** — png file from Finder (icon changes on hover, uploads); URL from Safari address bar → sent as URL not text; plain text from TextEdit → markdown content; 3 files → 3 serial requests + progress + final count; `.xyz` → error toast, no upload; 70 MB file → rejected pre-flight (confirm no network via Charles/Console or by watching it reject instantly).

- [ ] **Step 6: Commit**

```bash
git add Sources/CapMind/Drop/ Sources/CapMind/StatusItemController.swift Sources/CapMind/CapMindApp.swift
git commit -m "feat: add menu-bar drag-and-drop upload (serial, pre-flight validated)"
```

---

## Phase 6 — Feedback, error surfacing, Settings UI, Updates

### Task 6.1: ToastController

**Files:**
- Create: `Sources/CapMind/Feedback/ToastController.swift`
- Modify: capture/drop/note controllers to drive it.

- [ ] **Step 1: Implement** — an `NSPopover` (or small borderless `NSWindow`) anchored to `statusItem.button`. API: `show(_ message:, style: .progress|.success|.error, autoDismiss: TimeInterval?)`, `update(progress: "n/m")`, `dismiss()`. Success auto-dismiss 1.5s; error persists with a manual dismiss (click). Drive from `RegionCaptureController` and `DropController`.

- [ ] **Step 2: Verify build** → `swift build` succeeds.

- [ ] **Step 3: Commit**

```bash
git add Sources/CapMind/Feedback/ToastController.swift
git commit -m "feat: add menu-bar toast feedback"
```

### Task 6.2: Error → UI mapping

**Files:**
- Create: `Sources/CapMind/Feedback/MyMindError+UserMessage.swift`

- [ ] **Step 1: Implement** the PRD §12 table as a computed `userMessage` on `MyMindError` (e.g. `.unauthorized` → "Authentication failed. Check your access key.", `.payloadTooLarge` → "File too large (64 MB max).", `.unprocessable(let d)` → d, `.rateLimited(let s)` → "Rate limit hit. Retrying in \(s)s…", `.server` → "MyMind is having issues. Try again in a minute.", `.network` → "No connection.", `.unsupportedMime(let e)` → "MyMind doesn't accept .\(e) files."). For the no-key case, the controller (not the error) shows "Set up your MyMind access key in Settings" + opens Settings + sets the red icon.

- [ ] **Step 2: Commit**

```bash
git add Sources/CapMind/Feedback/MyMindError+UserMessage.swift
git commit -m "feat: map MyMindError to user-facing messages"
```

### Task 6.3: Settings panel + sections

**Files:**
- Create: `Sources/CapMind/Settings/SettingsView.swift` (+ `AccountSection.swift`, `ShortcutsSection.swift`, `GeneralSection.swift`, `UpdatesSection.swift`)
- Create: `Sources/CapMind/Updates/Updater.swift`
- Modify: `NotePanelController` (flip-to-Settings shares the panel) and `AppDelegate`/`StatusItemController` (`onOpenSettings`).

- [ ] **Step 1: Updater** — Sparkle wrapper exposing `checkForUpdates()`, plus bindings for auto-check / beta channel / background download backed by `SPUStandardUpdaterController` + `UserDefaults`.

- [ ] **Step 2: AccountSection** — Key ID `TextField` (binds `settings.keyID`); Secret: `SecureField` when empty, else `••••••••` + "Replace" button (clears to allow re-entry); "Test connection" button → `Task { try await client.testConnection() }`, show green "Connected" or `error.userMessage` (+ `type`/`detail`); "Manage access keys in MyMind" link → `NSWorkspace.shared.open(AppConstants.manageKeysURL)`. On successful save, set `appState.isConfigured = true` and status icon `.normal`.

- [ ] **Step 3: ShortcutsSection** — two `KeyboardShortcuts.Recorder` (`.openNote`, `.captureRegion`) + "Reset to defaults" (`KeyboardShortcuts.reset(...)`).

- [ ] **Step 4: GeneralSection** — `Picker` panel position; `Toggle` always-on-top; `Toggle` launch-at-login → `LaunchAtLogin.set`; `Picker` icon style → `statusController.setIcon`.

- [ ] **Step 5: UpdatesSection** — three toggles + "Check now" → `updater.checkForUpdates()`.

- [ ] **Step 6: SettingsView** — root that hosts the four sections; presented in the shared note panel (flip animation) or a dedicated `NSPanel`. Wire `onOpenSettings`/`⌘,`.

- [ ] **Step 7: Verify §14.2 / §14.15 manually**

Paste Key ID + secret, Test connection → green. Then:
Run: `security find-generic-password -s io.lardissone.capmind.api-secret`
Expected: the item exists (§14.2). Delete it (`security delete-generic-password -s io.lardissone.capmind.api-secret`) while running, trigger an upload → auth error surfaced + suggests Settings (§14.15).

- [ ] **Step 8: Commit**

```bash
git add Sources/CapMind/Settings/ Sources/CapMind/Updates/Updater.swift Sources/CapMind/CapMindApp.swift Sources/CapMind/Note/NotePanelController.swift
git commit -m "feat: add settings panel, sections, and Sparkle updater"
```

---

## Final Verification (whole-app acceptance)

- [ ] **All unit tests green** — Run: `swift test` → all of §14.19 pass.
- [ ] **Manual acceptance pass** — Walk PRD §14 items 1–16 in order against a real MyMind key; confirm each object appears in the MyMind web library.
- [ ] **§14.17 Gatekeeper** — On a clean Mac/VM, download the CI-produced signed+notarized zip; confirm it opens without Gatekeeper warnings.
- [ ] **§14.18 Sparkle** — Bump the appcast to a higher version; "Check for Updates" detects and applies it.
- [ ] **README** — Document: install (DMG/zip from Releases), generate access key, default shortcuts + the Raycast/Alfred/CleanShot collision caveat, screen-recording permission. Commit.

---

## Self-Review notes (resolved)
- **Spec coverage:** every PRD §9 flow → Phases 3/4/5; §10 Settings → Task 6.3; §11 components → mapped 1:1 to files; §12 errors → Tasks 6.1/6.2; §14 criteria → per-phase verify steps; §16 open questions → resolved in the approved plan header.
- **Type consistency:** `MyMindClient` method names match `MyMindClientTests`; `ObjectRef`/`ProblemJSON`/`RateLimitHeader.maxResetForExhausted` consistent across Tasks 2.3/2.5; `DropPayload` helpers consistent across 5.1/5.2; `CredentialsProviding` defined 2.1, implemented by `AppSettings` 1.2, consumed 2.5.
- **Phase order:** Phase 2 intentionally precedes Phases 1/3/4/5 in execution so the UI has a working client to call.
```
