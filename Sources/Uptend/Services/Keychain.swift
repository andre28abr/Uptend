import Foundation
import Security

/// Guarda segredos (ex.: token do GitHub, senha de banco) no Keychain do macOS —
/// cofre nativo, cifrado em repouso pelo sistema. Nunca gravamos segredos em
/// UserDefaults, arquivos ou logs.
///
/// Item de senha genérica (`kSecClassGenericPassword`) por (service, account), com
/// `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`: só acessível com o Mac desbloqueado
/// e sem sincronizar para o iCloud — coerente com o "local-first".
///
/// NOTA (distribuição): NÃO usamos `kSecUseDataProtectionKeychain` (keychain moderno).
/// Ele exige a entitlement de keychain-access-groups; num app ad-hoc/sem assinatura
/// Developer ID a gravação falha com `errSecMissingEntitlement` (verificado). O
/// upgrade para o data-protection keychain deve acompanhar a assinatura + entitlements
/// no empacotamento para distribuição. Enquanto isso, o keychain de login já cifra em
/// repouso e não sincroniza — a postura de segurança se mantém.
enum Keychain {

    /// Identificação comum do item, compartilhada por add/get/delete.
    private static func baseQuery(service: String, account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    @discardableResult
    static func set(_ value: String, service: String, account: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        let query = baseQuery(service: service, account: account)
        // Remove qualquer item anterior e grava o novo (upsert idempotente).
        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        return SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess
    }

    static func get(service: String, account: String) -> String? {
        var query = baseQuery(service: service, account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8) else { return nil }
        return value
    }

    @discardableResult
    static func delete(service: String, account: String) -> Bool {
        let status = SecItemDelete(baseQuery(service: service, account: account) as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
