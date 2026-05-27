import Foundation
import Security

enum Keychain {
    enum KeychainError: Error {
        case unexpectedStatus(OSStatus)
    }

    /// Writes `value` to the keychain, replacing any existing entry.
    /// Passing `nil` deletes the existing entry (no-op if absent).
    static func set(_ value: String?) {
        if let value {
            let data = Data(value.utf8)
            // Delete first so we can always do a clean add.
            let deleteQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: AppConstants.keychainService,
                kSecAttrAccount as String: AppConstants.keychainAccount
            ]
            SecItemDelete(deleteQuery as CFDictionary)

            var addQuery = deleteQuery
            addQuery[kSecValueData as String] = data
            SecItemAdd(addQuery as CFDictionary, nil)
        } else {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: AppConstants.keychainService,
                kSecAttrAccount as String: AppConstants.keychainAccount
            ]
            SecItemDelete(query as CFDictionary)
        }
    }

    /// Reads the stored secret, returning `nil` when not set.
    static func get() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: AppConstants.keychainService,
            kSecAttrAccount as String: AppConstants.keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8)
        else {
            return nil
        }
        return value
    }
}
