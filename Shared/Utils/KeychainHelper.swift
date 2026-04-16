//
//  KeychainHelper.swift
//  Save
//
//  Created by Elelan on 2024/12/4.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import Foundation
import Security

class KeychainHelper {

    /// Shared access group so both the main app and ShareExtension can read the same items.
    // kSecAttrAccessGroup for application-groups-based Keychain sharing must use the
    // raw app group identifier (no team ID prefix). The team ID prefix is only for
    // keychain-access-groups entitlement entries.
    private static let accessGroup = Constants.appGroup

    @discardableResult
    static func save(key: String, data: Data) -> Bool {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecAttrAccessGroup: accessGroup,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock,
            kSecValueData: data
        ]

        SecItemDelete(query as CFDictionary)
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    static func retrieve(key: String) -> Data? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecAttrAccessGroup: accessGroup,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]

        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)
        return result as? Data
    }

    static func delete(key: String) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecAttrAccessGroup: accessGroup
        ]

        SecItemDelete(query as CFDictionary)
    }

    // MARK: - String convenience

    @discardableResult
    static func save(key: String, string: String) -> Bool {
        guard let data = string.data(using: .utf8) else { return false }
        return save(key: key, data: data)
    }

    static func retrieveString(key: String) -> String? {
        guard let data = retrieve(key: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
