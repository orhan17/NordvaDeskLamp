import Foundation
import Security

/// The lamp's miIO token is a device key, so it lives in the Keychain. The README shows
/// how to add it with `security add-generic-password` under the same service and account.
enum LampToken {
    static let service = "io.github.orhan17.NordvaDeskLamp"
    static let account = "token"

    static func load() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
