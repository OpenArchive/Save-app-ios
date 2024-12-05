//
//  PasscodeRepository.swift
//  Save
//
//  Created by Elelan on 2024/12/4.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import Foundation
import Combine

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

    func storePasscodeHashAndSalt(hash: Data, salt: Data) {
        KeychainHelper.save(key: passcodeHashKey, data: hash)
        KeychainHelper.save(key: passcodeSaltKey, data: salt)
        
        AppSettings.passcodeEnabled.toggle()
    }

    func getPasscodeHashAndSalt() -> (hash: Data?, salt: Data?) {
        let hash = KeychainHelper.retrieve(key: passcodeHashKey)
        let salt = KeychainHelper.retrieve(key: passcodeSaltKey)
        return (hash, salt)
    }

    func clearPasscode() {
        
        KeychainHelper.delete(key: passcodeHashKey)
        KeychainHelper.delete(key: passcodeSaltKey)
        
        AppSettings.passcodeEnabled.toggle()
        
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
