import Foundation
import Security

nonisolated struct CredentialStore: Sendable {
    private let service: String
    private let account: String
    private let legacyAccount = "access-token"

    init(service: String = "com.momentumia.nido.caregiver", account: String = "session") {
        self.service = service
        self.account = account
    }

    func load() -> SessionCredential? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data
        else {
            delete(account: legacyAccount)
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(SessionCredential.self, from: data)
    }

    func save(_ credential: SessionCredential) throws {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data: Data
        do {
            data = try encoder.encode(credential)
        } catch {
            throw CredentialError.couldNotSave
        }
        let status = SecItemUpdate(base as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var insertion = base
            insertion[kSecValueData as String] = data
            insertion[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            guard SecItemAdd(insertion as CFDictionary, nil) == errSecSuccess else { throw CredentialError.couldNotSave }
        } else if status != errSecSuccess {
            throw CredentialError.couldNotSave
        }
    }

    func delete() {
        delete(account: account)
        if account != legacyAccount { delete(account: legacyAccount) }
    }

    private func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

nonisolated private enum CredentialError: LocalizedError {
    case couldNotSave

    var errorDescription: String? { "No se ha podido guardar el acceso de forma segura." }
}
