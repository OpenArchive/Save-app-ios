//
//  StorachaAppState.swift
//  Save
//
//  Created by navoda on 2025-08-25.
//  Copyright © 2025 Open Archive. All rights reserved.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Storacha States
class StorachaAppState: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var accounts: [String] = []
    @Published var isLoading: Bool = false
    @Published var usage: StorachaAccountUsageResponse?
    @Published var error: StorachaAPIError?
    @Published var isBusy: Bool = false
    @Published var spaceCount:Int = 0
    @Published var didState = DIDState()
    @Published var authState = AuthState()
    @Published var spaceState = SpaceState()
    @Published var currentUser: StorachaUser?
    @Published var lastUsedEmail: String = ""
    private let apiService = StorachaAPIService.shared
    private let sessionManager = SessionManager.shared
   
    init() {
        self.lastUsedEmail = sessionManager.getLastEmail() ?? ""
        // Call synchronous version in init
        restoreSessionSync()
        spaceCount = sessionManager.loadSpaceCount() ?? 0
    }
   
    // MARK: - Space Count Management
    @MainActor
    func loadSpaceCount() {
        spaceCount = sessionManager.loadSpaceCount() ?? 0
    }
    
    @MainActor
    func refreshSpaceCount() {
        loadSpaceCount()
    }
    
    // MARK: - Account Listing
    @MainActor
    func loadAccounts() {
        isLoading = true
        accounts.removeAll()

        if let lastEmail = sessionManager.getLastEmail(), !lastEmail.isEmpty {
            accounts = [lastEmail]
        }
        else{
            guard let sessionData = sessionManager.loadSession() else { return }
            accounts = [sessionData.email]
            self.lastUsedEmail = sessionData.email
            sessionManager.setLastEmail( self.lastUsedEmail)
        }

        isLoading = false
    }
    
    @MainActor
    func clearAccounts() {
        accounts = []
    }

    // MARK: - Session Restoration
    
    // Synchronous version for init
    private func restoreSessionSync() {
        guard let sessionData = sessionManager.loadSession() else { return }
        self.currentUser = StorachaUser(
            did: sessionData.did,
            email: sessionData.email,
            sessionId: sessionData.sessionId
        )
        self.lastUsedEmail = sessionData.email
        sessionManager.setLastEmail(self.lastUsedEmail)
        self.isAuthenticated = sessionData.verified
    }
    
    // MainActor version for view controllers
    @MainActor
    func restoreSession() {
        guard let sessionData = sessionManager.loadSession() else {
            print("⚠️ [restoreSession] No session data found")
            return
        }
        
        print("✅ [restoreSession] Restoring session for: \(sessionData.email)")
        
        self.currentUser = StorachaUser(
            did: sessionData.did,
            email: sessionData.email,
            sessionId: sessionData.sessionId
        )
        self.lastUsedEmail = sessionData.email
        sessionManager.setLastEmail(self.lastUsedEmail)
        self.isAuthenticated = sessionData.verified
        
        print("✅ [restoreSession] Session restored - User: \(sessionData.email), DID: \(sessionData.did)")
    }
    
    // MARK: - Session Management
    @MainActor
    func checkSessionAndNavigate() async -> (shouldGoToLogin: Bool,isVerified:Bool, userEmail: String?) {
        isBusy = true
        isLoading = true
        error = nil
        
        guard let sessionData = sessionManager.loadSession() else {
            isBusy = false
            isLoading = false
            return (shouldGoToLogin: true,isVerified:false, userEmail: nil)
        }
        
        do {
            // Validate session with server
            let storachaSessionResponse = try await apiService.checkSession()
            
            isBusy = false
            isLoading = false
            
            if (storachaSessionResponse?.valid ?? false) {
                if (storachaSessionResponse?.verified == 0) {
                    return (shouldGoToLogin: true,isVerified:false, userEmail: nil)
                }
               
                return (shouldGoToLogin: false,isVerified:true, userEmail: sessionData.email)
            } else {
            
                return (shouldGoToLogin: true,isVerified:false, userEmail: nil)
            }
        } catch {
           
            self.error = error as? StorachaAPIError ?? StorachaAPIError.networkError(error)
            
            isBusy = false
            isLoading = false
            return (shouldGoToLogin: true,isVerified:false, userEmail: nil)
        }
    }
    
    @MainActor
    func loadUsage(sessionId: String) async {
        print("🔄 [loadUsage] Starting - Task is cancelled: \(Task.isCancelled)")
        
        isLoading = true
        error = nil
        
        do {
            print("🔄 [loadUsage] Calling API...")
            let result = try await apiService.getAccountUsage()
            print("✅ [loadUsage] Got response: \(result)")
            
            // Update state on main actor
            usage = result
            error = nil // Clear any previous errors
            print("✅ [loadUsage] Updated state with response")
            
        } catch {
            print("❌ [loadUsage] Error: \(error)")
            
            // Convert to StorachaAPIError and set error state
            let apiError = error as? StorachaAPIError ?? .networkError(error)
            self.error = apiError
            usage = nil
            
            // Log if it's a 401 error
            if case .unauthorized = apiError {
                print("⚠️ [loadUsage] Unauthorized error detected - observers should handle this")
            }
        }
        
        isLoading = false
    }
    
    // MARK: - Error Handling
    @MainActor
    func clearError() {
        error = nil
    }
}

// MARK: - Supporting Models
struct StorachaUser {
    let did: String
    let email: String
    let sessionId: String
}

struct StorachaUpload: Identifiable {
    let id = UUID()
    let cid: String
    let fileName: String
    let size: Int
    let uploadDate: Date
    let gatewayUrl: String
}

enum StorachaError: Error, LocalizedError {
    case authenticationFailed(String)
    case networkError(Error)
    case uploadFailed(String)
    case insufficientPermissions
    case sessionExpired
    case unknownError(String)
    
    var errorDescription: String? {
        switch self {
        case .authenticationFailed(let message):
            return message
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .uploadFailed(let message):
            return "Upload failed: \(message)"
        case .insufficientPermissions:
            return "Insufficient permissions"
        case .sessionExpired:
            return "Session has expired"
        case .unknownError(let message):
            return "Unknown error: \(message)"
        }
    }
}

// MARK: - Actions (Simplified for login only)
enum StorachaLoginAction {
    case login
    case cancel
    case createAccount
}
