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
    func clearKeychainOnFirstInstall(forceDelete: Bool = false) {
        let firstLaunchKey = "HasLaunchedBefore"
        
        if !UserDefaults.standard.bool(forKey: firstLaunchKey) || forceDelete {
           
            var keysToKeep: [String] = []
            
            if AppSettings.isPasscodeEnabled {
                keysToKeep = ["passcode_hash", "passcode_salt"]
            }
            
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecReturnAttributes as String: true,
                kSecMatchLimit as String: kSecMatchLimitAll
            ]
            
            var result: AnyObject?
            let status = SecItemCopyMatching(query as CFDictionary, &result)
            
            if status == errSecSuccess, let items = result as? [[String: Any]] {
                for item in items {
                    if let account = item[kSecAttrAccount as String] as? String {
                        // Only delete if not in our keep list
                        if !keysToKeep.contains(account) {
                            let deleteQuery: [String: Any] = [
                                kSecClass as String: kSecClassGenericPassword,
                                kSecAttrAccount as String: account
                            ]
                            SecItemDelete(deleteQuery as CFDictionary)
                        }
                    }
                }
            }
            
            // Mark as launched (only on first launch, not on force delete)
            if !UserDefaults.standard.bool(forKey: firstLaunchKey) {
                UserDefaults.standard.set(true, forKey: firstLaunchKey)
            }
        }
    }
}
