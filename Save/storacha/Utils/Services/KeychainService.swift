//
//  KeychainService.swift
//  Save
//
//  Created by navoda on 2025-08-22.
//  Copyright © 2025 Open Archive. All rights reserved.
//

import Foundation
import Security

enum KeychainError: Error {
    case duplicateItem
    case unableToSave
    case unableToLoad
    case invalidData
    case itemNotFound
    case unknown(OSStatus)
    
    var localizedDescription: String {
        switch self {
        case .duplicateItem:
            return "Item already exists in keychain"
        case .unableToSave:
            return "Failed to save to keychain"
        case .unableToLoad:
            return "Failed to load from keychain"
        case .invalidData:
            return "Invalid data in keychain"
        case .itemNotFound:
            return "Item not found in keychain"
        case .unknown(let status):
            return "Keychain error: \(status)"
        }
    }
}

class KeychainService {
    static let shared = KeychainService()
    
    private let serviceName = Bundle.main.bundleIdentifier ?? "com.save.app"
    
    private init() {}
    
    func save(_ data: Data, for key: String) throws {
      
        // Delete existing item first to avoid duplicates
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        
        // Add new item
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            print("❌ Keychain save failed for '\(key)' - Status: \(status)")
            throw KeychainError.unableToSave
        }
     
    }
    
    func load(for key: String) throws -> Data {
       
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
        
                throw KeychainError.itemNotFound
            } else if status == errSecInteractionNotAllowed {
                print("   ⚠️ Device is locked")
                throw KeychainError.unableToLoad
            } else {
                print("   ❌ Error code: \(status)")
                throw KeychainError.unknown(status)
            }
        }
        
        guard let data = result as? Data else {
            print("   ❌ Invalid data type")
            throw KeychainError.invalidData
        }
        
        return data
    }
    
    func delete(for key: String) throws {
      
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            print("❌ Delete failed - Status: \(status)")
            throw KeychainError.unknown(status)
        }
        
    }
    
    // MARK: - First Install Cleanup
    func clearKeychainOnFirstInstall(forceDelete: Bool = false) {
       
        let firstLaunchKey = "HasLaunchedBefore"
        
        if !UserDefaults.standard.bool(forKey: firstLaunchKey) || forceDelete {
            print("   Performing keychain cleanup...")
            
            var keysToKeep: [String] = []
            
            if AppSettings.isPasscodeEnabled {
                keysToKeep = ["passcode_hash", "passcode_salt"]
                print("   Keeping passcode keys")
            }
            
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: serviceName,
                kSecReturnAttributes as String: true,
                kSecMatchLimit as String: kSecMatchLimitAll
            ]
            
            var result: AnyObject?
            let status = SecItemCopyMatching(query as CFDictionary, &result)
            
            if status == errSecSuccess, let items = result as? [[String: Any]] {
                print("   Found \(items.count) keychain items")
                
                for item in items {
                    if let account = item[kSecAttrAccount as String] as? String {
                        if !keysToKeep.contains(account) {
                            let deleteQuery: [String: Any] = [
                                kSecClass as String: kSecClassGenericPassword,
                                kSecAttrService as String: serviceName,
                                kSecAttrAccount as String: account
                            ]
                            let deleteStatus = SecItemDelete(deleteQuery as CFDictionary)
                            print("   Deleted '\(account)' - Status: \(deleteStatus)")
                        } else {
                            print("   Keeping '\(account)'")
                        }
                    }
                }
            } else if status == errSecItemNotFound {
                print("   No items found to clean")
            } else {
                print("   ⚠️ Query failed - Status: \(status)")
            }
            
            // Mark as launched (only on first launch, not on force delete)
            if !UserDefaults.standard.bool(forKey: firstLaunchKey) {
                UserDefaults.standard.set(true, forKey: firstLaunchKey)
            }
        } else {
            print("   Skipping - not first launch")
        }
    }
}
