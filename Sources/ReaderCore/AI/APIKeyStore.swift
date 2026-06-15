import Foundation
import Security

public protocol APIKeyStoring: Sendable {
    var hasAPIKey: Bool { get }
    func loadAPIKey() throws -> String?
    func saveAPIKey(_ key: String) throws
    func deleteAPIKey() throws
    func maskedAPIKey() throws -> String?
}

public enum APIKeyStoreError: Error, Equatable, LocalizedError, Sendable {
    case keychainStatus(OSStatus)

    public var errorDescription: String? {
        switch self {
        case .keychainStatus:
            return "Keychain 操作失败"
        }
    }
}

public final class APIKeyStore: APIKeyStoring, @unchecked Sendable {
    private let service: String
    private let account: String

    public init(service: String = "ReaderMacApp.Anthropic", account: String = "api-key") {
        self.service = service
        self.account = account
    }

    public static func store(for provider: AIProvider) -> APIKeyStore {
        APIKeyStore(service: "ReaderMacApp.AI.\(provider.rawValue)", account: "api-key")
    }

    public static func legacyAnthropicStore() -> APIKeyStore {
        APIKeyStore(service: "ReaderMacApp.Anthropic", account: "api-key")
    }

    public var hasAPIKey: Bool {
        ((try? loadAPIKey()) ?? nil)?.isEmpty == false
    }

    public func loadAPIKey() throws -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw APIKeyStoreError.keychainStatus(status)
        }
        guard
            let data = result as? Data,
            let key = String(data: data, encoding: .utf8)
        else {
            throw APIKeyStoreError.keychainStatus(errSecDecode)
        }
        return key
    }

    public func saveAPIKey(_ key: String) throws {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            try deleteAPIKey()
            return
        }

        try deleteAPIKey()

        var query = baseQuery()
        query[kSecValueData as String] = Data(trimmed.utf8)
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw APIKeyStoreError.keychainStatus(status)
        }
    }

    public func deleteAPIKey() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw APIKeyStoreError.keychainStatus(status)
        }
    }

    public func maskedAPIKey() throws -> String? {
        guard let key = try loadAPIKey(), !key.isEmpty else { return nil }
        let suffix = String(key.suffix(4))
        return "••••\(suffix)"
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

public protocol AIKeyStoreProviding: Sendable {
    func keyStore(for provider: AIProvider) -> any APIKeyStoring
}

public struct DefaultAIKeyStoreProvider: AIKeyStoreProviding {
    public init() {}

    public func keyStore(for provider: AIProvider) -> any APIKeyStoring {
        let primary = APIKeyStore.store(for: provider)
        guard provider == .anthropic else {
            return primary
        }
        return FallbackAPIKeyStore(primary: primary, fallback: APIKeyStore.legacyAnthropicStore())
    }
}

public struct SingleAIKeyStoreProvider: AIKeyStoreProviding {
    private let store: any APIKeyStoring

    public init(store: any APIKeyStoring) {
        self.store = store
    }

    public func keyStore(for provider: AIProvider) -> any APIKeyStoring {
        store
    }
}

public final class FallbackAPIKeyStore: APIKeyStoring, @unchecked Sendable {
    private let primary: any APIKeyStoring
    private let fallback: any APIKeyStoring

    public init(primary: any APIKeyStoring, fallback: any APIKeyStoring) {
        self.primary = primary
        self.fallback = fallback
    }

    public var hasAPIKey: Bool {
        primary.hasAPIKey || fallback.hasAPIKey
    }

    public func loadAPIKey() throws -> String? {
        if let key = try primary.loadAPIKey(), !key.isEmpty {
            return key
        }
        return try fallback.loadAPIKey()
    }

    public func saveAPIKey(_ key: String) throws {
        try primary.saveAPIKey(key)
        try? fallback.deleteAPIKey()
    }

    public func deleteAPIKey() throws {
        try primary.deleteAPIKey()
        try fallback.deleteAPIKey()
    }

    public func maskedAPIKey() throws -> String? {
        guard let key = try loadAPIKey(), !key.isEmpty else { return nil }
        return "••••\(key.suffix(4))"
    }
}
