import Foundation
import Security

enum KeychainSecretError: Error, Equatable, Sendable {
    case notFound
    case protectedDataUnavailable
    case unexpectedStatus(OSStatus)
}

struct KeychainSecretStore: Sendable {
    let service: String

    init(service: String = "com.reflo.app.llm-api-key") {
        self.service = service
    }

    func save(secret: String, account: String) throws {
        let data = Data(secret.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecSuccess {
            return
        }
        if status == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw mapStatus(addStatus)
            }
            return
        }
        throw mapStatus(status)
    }

    func load(account: String) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            throw KeychainSecretError.notFound
        }
        guard status == errSecSuccess else {
            throw mapStatus(status)
        }
        guard let data = item as? Data, let secret = String(data: data, encoding: .utf8) else {
            throw KeychainSecretError.unexpectedStatus(errSecDecode)
        }
        return secret
    }

    func delete(account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        if status == errSecSuccess || status == errSecItemNotFound {
            return
        }
        throw mapStatus(status)
    }

    func listAccounts() -> [String] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]

        var items: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &items)
        guard status == errSecSuccess, let entries = items as? [[String: Any]] else {
            return []
        }
        return entries.compactMap { $0[kSecAttrAccount as String] as? String }
    }

    private func mapStatus(_ status: OSStatus) -> KeychainSecretError {
        if status == errSecInteractionNotAllowed {
            return .protectedDataUnavailable
        }
        return .unexpectedStatus(status)
    }
}
