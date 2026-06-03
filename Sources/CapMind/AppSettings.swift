import AppKit
import Foundation
import Observation

enum PanelPosition: String, CaseIterable, Identifiable {
    case lastUsed
    case centered
    case atCursor

    var id: String { rawValue }
}

/// `@unchecked Sendable` because all mutation happens on the main actor via
/// `@Observable`; `currentCredentials()` returns a value-type snapshot so
/// no mutable state crosses isolation boundaries.
@Observable
final class AppSettings: CredentialsProviding, @unchecked Sendable {
    // MARK: - Persisted properties

    var keyID: String {
        didSet { defaults.set(keyID, forKey: Keys.keyID) }
    }

    var panelPosition: PanelPosition {
        didSet { defaults.set(panelPosition.rawValue, forKey: Keys.panelPosition) }
    }

    var alwaysOnTop: Bool {
        didSet { defaults.set(alwaysOnTop, forKey: Keys.alwaysOnTop) }
    }

    /// Last window origin, persisted for the `lastUsed` panel position mode.
    var savedWindowOrigin: NSPoint? {
        get {
            guard let s = defaults.string(forKey: Keys.savedWindowOrigin) else { return nil }
            let parsed = NSPointFromString(s)
            return (parsed == .zero) ? nil : parsed
        }
        set {
            if let origin = newValue {
                defaults.set(NSStringFromPoint(origin), forKey: Keys.savedWindowOrigin)
            } else {
                defaults.removeObject(forKey: Keys.savedWindowOrigin)
            }
        }
    }

    /// Last note-panel content size, persisted so a resized window is restored across
    /// invocations and sessions.
    var savedWindowSize: NSSize? {
        get {
            guard let s = defaults.string(forKey: Keys.savedWindowSize) else { return nil }
            let parsed = NSSizeFromString(s)
            return (parsed.width <= 0 || parsed.height <= 0) ? nil : parsed
        }
        set {
            if let size = newValue {
                defaults.set(NSStringFromSize(size), forKey: Keys.savedWindowSize)
            } else {
                defaults.removeObject(forKey: Keys.savedWindowSize)
            }
        }
    }

    // MARK: - Keychain-backed secret

    /// Reads the API secret from the macOS Keychain. Returns `nil` when not set.
    var secret: String? {
        Keychain.get()
    }

    func setSecret(_ value: String?) {
        Keychain.set(value)
    }

    // MARK: - CredentialsProviding

    var isConfigured: Bool {
        !keyID.isEmpty && (secret ?? "").isEmpty == false
    }

    func currentCredentials() -> MyMindCredentials? {
        guard isConfigured, let s = secret else { return nil }
        return MyMindCredentials(keyID: keyID, secret: s)
    }

    // MARK: - Init

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        keyID = defaults.string(forKey: Keys.keyID) ?? ""
        panelPosition = PanelPosition(rawValue: defaults.string(forKey: Keys.panelPosition) ?? "")
            ?? .lastUsed
        alwaysOnTop = defaults.object(forKey: Keys.alwaysOnTop) as? Bool ?? true
    }

    // MARK: - Keys

    private enum Keys {
        static let keyID = "keyID"
        static let panelPosition = "panelPosition"
        static let alwaysOnTop = "alwaysOnTop"
        static let savedWindowOrigin = "savedWindowOrigin"
        static let savedWindowSize = "savedWindowSize"
    }
}
