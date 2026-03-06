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

/// Space count and session validity; updated together in `refreshSpaceCountAndSession()`.
struct SpaceSessionStats: Equatable {
    var spaceCount: Int
    var delegatedSpaceCount: Int
    var hasValidSession: Bool
}

// MARK: - Storacha App State

@MainActor
class StorachaAppState: ObservableObject {
    @Published private(set) var spaceStats: SpaceSessionStats
    @Published var isAuthenticated: Bool = false
    @Published var accounts: [String] = []
    @Published var isLoading: Bool = false
    @Published var usage: StorachaAccountUsageResponse?
    @Published var error: StorachaAPIError?
    @Published var isBusy: Bool = false
    @Published var didState = DIDState()
    @Published var authState = AuthState()
    @Published var spaceState = SpaceState()
    @Published var currentUser: StorachaUser?
    @Published var lastUsedEmail: String = ""
    private let apiService = StorachaAPIService.shared
    private let sessionManager = SessionManager.shared

    var spaceCount: Int { spaceStats.spaceCount }
    var delegatedSpaceCount: Int { spaceStats.delegatedSpaceCount }
    var hasValidSession: Bool { spaceStats.hasValidSession }
   
    init() {
        let session = SessionManager.shared.loadSession()
        self.spaceStats = SpaceSessionStats(
            spaceCount: SessionManager.shared.loadSpaceCount() ?? 0,
            delegatedSpaceCount: SessionManager.shared.loadDelegatedSpaceCount() ?? 0,
            hasValidSession: (session.map { !$0.sessionId.isEmpty }) ?? false
        )
        self.lastUsedEmail = sessionManager.getLastEmail() ?? ""
        restoreSessionSync() // Local-only, no network; required for initial state
    }

    // MARK: - Space Count Management

    func refreshSpaceCountAndSession() {
        let session = sessionManager.loadSession()
        spaceStats = SpaceSessionStats(
            spaceCount: sessionManager.loadSpaceCount() ?? 0,
            delegatedSpaceCount: sessionManager.loadDelegatedSpaceCount() ?? 0,
            hasValidSession: (session.map { !$0.sessionId.isEmpty }) ?? false
        )
    }
    
    // MARK: - Account Listing

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
    
    func clearAccounts() {
        accounts = []
    }

    // MARK: - Session Restoration
    
    /// Restores session from local storage only (no network). Safe to call from init.
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
    
    /// Restores session from local storage (no network). Call from view controllers.
    func restoreSession() {
        guard let sessionData = sessionManager.loadSession() else {
            return
        }
    
        self.currentUser = StorachaUser(
            did: sessionData.did,
            email: sessionData.email,
            sessionId: sessionData.sessionId
        )
        self.lastUsedEmail = sessionData.email
        sessionManager.setLastEmail(self.lastUsedEmail)
        self.isAuthenticated = sessionData.verified
    }
    
    // MARK: - Session Management

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
    
    func loadUsage(sessionId: String) async {
        
        isLoading = true
        error = nil
        
        do {
           
            let result = try await apiService.getAccountUsage()
            
            // Update state on main actor
            usage = result
            error = nil // Clear any previous errors
            
        } catch {
            // Convert to StorachaAPIError and set error state
            let apiError = error as? StorachaAPIError ?? .networkError(error)
            self.error = apiError
            usage = nil
        }
        
        isLoading = false
    }
    
    // MARK: - Error Handling

    func clearError() {
        error = nil
    }
}

