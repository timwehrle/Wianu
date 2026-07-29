import Foundation
import Security

nonisolated protocol TMDBCredentialStoring: Sendable {
    func loadToken() throws -> String?
    func saveToken(_ token: String) throws
    func removeToken() throws
}

enum TMDBCredentialError: LocalizedError {
    case emptyToken

    var errorDescription: String? {
        switch self {
        case .emptyToken:
            "Enter a TMDB Read Access Token."
        }
    }
}

struct KeychainTMDBCredentialStore: TMDBCredentialStoring {
    private let service: String
    private let account: String

    init(
        service: String = Bundle.main.bundleIdentifier ?? "Wianu",
        account: String = "TMDBReadAccessToken"
    ) {
        self.service = service
        self.account = account
    }

    func loadToken() throws -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        switch SecItemCopyMatching(query as CFDictionary, &result) {
        case errSecSuccess:
            guard
                let data = result as? Data,
                let token = String(data: data, encoding: .utf8)
            else {
                throw KeychainError(status: errSecDecode)
            }
            return token
        case errSecItemNotFound:
            return nil
        case let status:
            throw KeychainError(status: status)
        }
    }

    func saveToken(_ token: String) throws {
        let attributes = [kSecValueData as String: Data(token.utf8)]
        let updateStatus = SecItemUpdate(
            baseQuery as CFDictionary,
            attributes as CFDictionary
        )

        switch updateStatus {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            var item = baseQuery.merging(attributes) { _, new in new }
            item[kSecAttrAccessible as String] =
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            let status = SecItemAdd(item as CFDictionary, nil)
            guard status == errSecSuccess else {
                throw KeychainError(status: status)
            }
        case let status:
            throw KeychainError(status: status)
        }
    }

    func removeToken() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError(status: status)
        }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}

private struct KeychainError: LocalizedError {
    let status: OSStatus

    var errorDescription: String? {
        SecCopyErrorMessageString(status, nil) as String?
            ?? "Keychain error \(status)."
    }
}
