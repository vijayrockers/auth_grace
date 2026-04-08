import Foundation
import Security

class AuthGraceSession {

    private static let keychainKey = "com.authgrace.last_auth_time"

    // Save current timestamp after successful auth
    static func markAuthenticated() {
        let timestamp = Date().timeIntervalSince1970
        let data = withUnsafeBytes(of: timestamp) { Data($0) }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        SecItemDelete(query as CFDictionary) // delete old value
        SecItemAdd(query as CFDictionary, nil)
    }

    // Check if last auth is within grace window
    static func isWithinGracePeriod(seconds: Int) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              data.count == MemoryLayout<Double>.size else {
            return false
        }

        let lastAuth = data.withUnsafeBytes { $0.load(as: Double.self) }
        let elapsed = Date().timeIntervalSince1970 - lastAuth
        return elapsed < Double(seconds)
    }

    // Clear on logout
    static func clearSession() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey
        ]
        SecItemDelete(query as CFDictionary)
    }
}
