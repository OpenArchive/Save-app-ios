//
//  KeychainService.swift
//  Save
//
//  Created by navoda on 2025-08-22.
//  Copyright © 2025 Open Archive. All rights reserved.
//

class KeychainService {
    static let shared = KeychainService()
    private init() {}
    
    func save(_ data: Data, for key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw StorachaAPIError.authenticationFailed("Failed to save to keychain")
        }
    }
    
    func load(for key: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess, let data = result as? Data else {
            throw StorachaAPIError.authenticationFailed("Failed to load from keychain")
        }
        
        return data
    }
    
    func delete(for key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw StorachaAPIError.authenticationFailed("Failed to delete from keychain")
        }
    }
    
    // MARK: - First Install Cleanup
    func clearKeychainOnFirstInstall() {
        let firstLaunchKey = "HasLaunchedBefore"
        
        if !UserDefaults.standard.bool(forKey: firstLaunchKey) {
            // First install - clear all keychain items for this app
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword
            ]
            SecItemDelete(query as CFDictionary)
            
            // Mark as launched
            UserDefaults.standard.set(true, forKey: firstLaunchKey)
        }
    }
}
