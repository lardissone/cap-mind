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
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
        return "\(appName)/\(version) (macOS)"
    }
}
