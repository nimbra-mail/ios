import Foundation
import NimbraCore
import Security

/// The engine's secrets (sign-ins, passwords, the store's key) as generic passwords in the
/// app's Keychain: readable after the first unlock since a restart (so mail can sync in the
/// background), on this device only, never synced to iCloud and never in a backup that
/// leaves it.
///
/// Every item is under one fixed service; the engine's own service and account names make
/// up the item's account (`<service>/<account>`). Errors carry the Keychain's status code,
/// never an item's contents, and nothing here is logged.
nonisolated final class KeychainSecretStore: SecretStore {
    /// The service of every Nimbra item.
    static let service = "com.riangle.nimbra"

    private let service: String

    /// `service` is for tests, which keep their items apart from the app's.
    init(service: String = KeychainSecretStore.service) {
        self.service = service
    }

    func get(service: String, account: String) throws -> Data {
        var query = baseQuery(service: service, account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data else { throw Self.unavailable(errSecDecode) }
            return data
        case errSecItemNotFound:
            throw SecretError.NotFound
        default:
            throw Self.unavailable(status)
        }
    }

    func set(service: String, account: String, secret: Data) throws {
        let query = baseQuery(service: service, account: account)
        let attributes: [String: Any] = [
            kSecValueData as String: secret,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let updated = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        switch updated {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            let added = SecItemAdd(query.merging(attributes) { $1 } as CFDictionary, nil)
            guard added == errSecSuccess else { throw Self.unavailable(added) }
        default:
            throw Self.unavailable(updated)
        }
    }

    func delete(service: String, account: String) throws {
        let status = SecItemDelete(baseQuery(service: service, account: account) as CFDictionary)
        switch status {
        case errSecSuccess: return
        case errSecItemNotFound: throw SecretError.NotFound
        default: throw Self.unavailable(status)
        }
    }

    /// The item for an engine service and account, never synchronized.
    private func baseQuery(service engineService: String, account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "\(engineService)/\(account)",
            kSecAttrSynchronizable as String: false,
            kSecUseDataProtectionKeychain as String: true,
        ]
    }

    /// The status code only: what `SecCopyErrorMessageString` says never names the item.
    private static func unavailable(_ status: OSStatus) -> SecretError {
        .Unavailable(message: "Keychain error \(status)")
    }
}
