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
    
    private init() {}
    
    func saveSession(_ sessionData: StorachaSessionData) throws {
        let data = try JSONEncoder().encode(sessionData)
        try keychain.save(data, for: sessionKey)
        
        // Save last used email for convenience
        userDefaults.set(sessionData.email, forKey: lastEmailKey)
    }
    
    func loadSession() -> StorachaSessionData? {
        do {
            let data = try keychain.load(for: sessionKey)
            let sessionData = try JSONDecoder().decode(StorachaSessionData.self, from: data)
            
            // Return only if session is still valid
            return sessionData
        } catch {
            return nil
        }
    }
    
    func clearSession() {
        try? keychain.delete(for: sessionKey)
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
