import Foundation
import Observation

enum PanelPosition: String, CaseIterable, Identifiable {
    case lastUsed
    case centered
    case atCursor

    var id: String { rawValue }
}

enum IconStyle: String, CaseIterable, Identifiable {
    case outline
    case filled

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

    var iconStyle: IconStyle {
        didSet { defaults.set(iconStyle.rawValue, forKey: Keys.iconStyle) }
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
        iconStyle = IconStyle(rawValue: defaults.string(forKey: Keys.iconStyle) ?? "")
            ?? .outline
    }

    // MARK: - Keys

    private enum Keys {
        static let keyID = "keyID"
        static let panelPosition = "panelPosition"
        static let alwaysOnTop = "alwaysOnTop"
        static let iconStyle = "iconStyle"
    }
}
