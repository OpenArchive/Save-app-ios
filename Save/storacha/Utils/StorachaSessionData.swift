//
//  StorachaSessionData.swift
//  Save
//
//  Created by navoda on 2025-08-22.
//  Copyright © 2025 Open Archive. All rights reserved.
//

struct StorachaSessionData: Codable {
    let sessionId: String
    let did: String
    let email: String
    let expiresAt: Date?
    let verified: Bool
    
    var isValid: Bool {
        guard verified else { return false }
        
        if let expiresAt = expiresAt {
            return Date() < expiresAt
        }
        return true
    }
}

public class SessionManager {
    static let shared = SessionManager()
    private let keychain = KeychainService.shared
    private let userDefaults = UserDefaults.standard
    
    private let sessionKey = "storacha_session"
    private let lastEmailKey = "storacha_last_email"
    private let spaceCount = "storacha_space_count"
    
    private init() {}
    
    func saveSession(_ sessionData: StorachaSessionData) throws {
        let data = try JSONEncoder().encode(sessionData)
        try keychain.save(data, for: sessionKey)
        userDefaults.set(sessionData.email, forKey: lastEmailKey)
    }
    
    func saveSpaces(_ count: Int) throws {
        guard let data = "\(count)".data(using: .utf8) else {
            throw StorachaAPIError.authenticationFailed("Failed to convert count to data")
        }
        try keychain.save(data, for: spaceCount)
    }
    
    func loadSession() -> StorachaSessionData? {
        do {
            let data = try keychain.load(for: sessionKey)
            let sessionData = try JSONDecoder().decode(StorachaSessionData.self, from: data)
            return sessionData
        } catch {
            return nil
        }
    }
    
    func loadSpaceCount() -> Int? {
        do {
               let data = try keychain.load(for: spaceCount)
               let string = String(data: data, encoding: .utf8)
               return string.flatMap { Int($0) }
           } catch {
               return nil
           }
    }
    
    func clearSession() {
        try? keychain.delete(for: sessionKey)
        keychain.clearKeychainOnFirstInstall(forceDelete: true)
    }
    
}
// MARK: - Session Manager Extension
extension SessionManager {
    func setLastEmail(_ email: String) {
        UserDefaults.standard.set(email, forKey: "lastUsedEmail")
    }
    
    func getLastEmail() -> String? {
        return UserDefaults.standard.string(forKey: "lastUsedEmail")
    }
}
