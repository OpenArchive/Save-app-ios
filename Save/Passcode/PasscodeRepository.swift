//
//  PasscodeRepository.swift
//  Save
//
//  Created by Elelan on 2024/12/4.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import Foundation
import Combine
import Security

class PasscodeRepository {
    
    private let hashingStrategy: HashingStrategy
    private let config: AppConfig
    private let passcodeHashKey = "passcode_hash"
    private let passcodeSaltKey = "passcode_salt"
    private let failedAttemptsKey = "failed_attempts"
    private let lockoutTimeKey = "lockout_time"
    private let defaults = UserDefaults.standard

    init(
        hashingStrategy: HashingStrategy = PBKDF2HashingStrategy(),
        config: AppConfig = .default
    ) {
        self.hashingStrategy = hashingStrategy
        self.config = config
    }

    func generateSalt() -> Data {
        return hashingStrategy.generateSalt()
    }

    func hashPasscode(passcode: String, salt: Data) -> AnyPublisher<Data, Error> {
        Future { promise in
            DispatchQueue.global(qos: .userInitiated).async {
                if let hash = self.hashingStrategy.hash(passcode: passcode, salt: salt) {
                    promise(.success(hash))
                } else {
                    promise(.failure(NSError(domain: "HashingError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to hash passcode"])))
                }
            }
        }.eraseToAnyPublisher()
    }

    func storePasscodeHashAndSalt(hash: Data, salt: Data) throws {
        guard KeychainHelper.save(key: passcodeHashKey, data: hash) else {
            throw NSError(domain: "PasscodeRepository", code: -1, 
                         userInfo: [NSLocalizedDescriptionKey: "Failed to save passcode hash to keychain"])
        }
        
        guard KeychainHelper.save(key: passcodeSaltKey, data: salt) else {
            throw NSError(domain: "PasscodeRepository", code: -2, 
                         userInfo: [NSLocalizedDescriptionKey: "Failed to save passcode salt to keychain"])
        }
        
        AppSettings.passcodeEnabled = true
    }

    func getPasscodeHashAndSalt() -> (hash: Data?, salt: Data?) {
        migrateLegacyKeychainItemIfNeeded(key: passcodeHashKey)
        migrateLegacyKeychainItemIfNeeded(key: passcodeSaltKey)
        let hash = KeychainHelper.retrieve(key: passcodeHashKey)
        let salt = KeychainHelper.retrieve(key: passcodeSaltKey)
        return (hash, salt)
    }

    /// Migrates a Keychain item stored without an access group (pre-security-fix format)
    /// to the new format that includes the shared access group.
    /// This ensures existing users don't lose their passcode after the update.
    private func migrateLegacyKeychainItemIfNeeded(key: String) {
        // If the item already exists under the new access group, nothing to do.
        guard KeychainHelper.retrieve(key: key) == nil else { return }

        // Try to find the item stored without an access group (legacy format).
        let legacyQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(legacyQuery as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return }

        // Re-save with the shared access group.
        KeychainHelper.save(key: key, data: data)

        // Remove the legacy item.
        SecItemDelete(legacyQuery as CFDictionary)
    }

    func clearPasscode() {
        
        KeychainHelper.delete(key: passcodeHashKey)
        KeychainHelper.delete(key: passcodeSaltKey)
        
        AppSettings.passcodeEnabled = false

        resetFailedAttempts()
    }
    
    func recordFailedAttempt() {
        
        let attempts = defaults.integer(forKey: failedAttemptsKey) + 1
        defaults.set(attempts, forKey: failedAttemptsKey)
        
        if config.maxRetryLimitEnabled && attempts >= config.maxFailedAttempts {
            defaults.set(Date().timeIntervalSince1970, forKey: lockoutTimeKey)
        }
    }
    
    func resetFailedAttempts() {
        defaults.removeObject(forKey: failedAttemptsKey)
        defaults.removeObject(forKey: lockoutTimeKey)
    }
    
    func isLockedOut() -> Bool {
        
        guard config.maxRetryLimitEnabled else { return false }
        guard let lockoutTime = defaults.object(forKey: lockoutTimeKey) as? TimeInterval else { return false }
        
        let elapsedTime = Date().timeIntervalSince1970 - lockoutTime
        
        if elapsedTime >= config.lockoutDuration {
            resetFailedAttempts()
            return false
        }
        return true
    }
    
    func getRemainingAttempts() -> Int {
        
        let failedAttempts = defaults.integer(forKey: failedAttemptsKey)
        return config.maxFailedAttempts - failedAttempts
    }
}
