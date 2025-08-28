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
    @Published var currentUser: StorachaUser?
    @Published var isLoading: Bool = false
    @Published var error: StorachaAPIError?
    @Published var lastUsedEmail: String = ""
    @Published var email: String = ""
    @Published var isBusy: Bool = false
    @Published var isLoginError: Bool = false
    
    private let apiService = StorachaAPIService.shared
    private let sessionManager = SessionManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    var isValid: Bool {
        return !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    init() {
        self.lastUsedEmail = sessionManager.getLastEmail() ?? ""
        self.email = self.lastUsedEmail
        restoreSession()
    }
    
    private func restoreSession() {
        guard let sessionData = sessionManager.loadSession() else { return }
        
        let user = StorachaUser(
            did: sessionData.did,
            email: sessionData.email,
            sessionId: sessionData.sessionId
        )
        
        DispatchQueue.main.async {
            self.currentUser = user
            self.isAuthenticated = sessionData.verified
            self.lastUsedEmail = sessionData.email
            self.email = sessionData.email
        }
        
    }
    
    // MARK: - Authentication Actions
    @MainActor
    func login(email: String) async {
        // Set busy state to show progress indicator
        isBusy = true
        isLoading = true
        error = nil
        isLoginError = false
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard isValidEmail(trimmedEmail) else {
            isLoginError = true
            error = StorachaAPIError.authenticationFailed("Please enter a valid email address")
            isBusy = false
            isLoading = false
            return
        }
        
        do {
            
            let sessionData = try await apiService.login(email: trimmedEmail)
            
            let user = StorachaUser(
                did: sessionData.did,
                email: sessionData.email,
                sessionId: sessionData.sessionId
            )
            
            self.currentUser = user
            self.isAuthenticated = sessionData.verified
            self.lastUsedEmail = trimmedEmail
            self.email = trimmedEmail
            
        } catch {
            
            self.isLoginError = true
            
            if let apiError = error as? StorachaAPIError {
                self.error = apiError
            } else {
                self.error = StorachaAPIError.authenticationFailed("Login failed. Please check your email and try again.")
            }
        }
        
        isBusy = false
        isLoading = false
    }
    
    // Email validation helper
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
    
    @MainActor
    func logout() {
        Task {
            try? await apiService.logout()
        }
        
        currentUser = nil
        isAuthenticated = false
        error = nil
        isLoginError = false
        isBusy = false
        isLoading = false
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
                if(storachaSessionResponse?.verified == 0 ){
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
    
    // MARK: - Email Verification Polling
    @MainActor
    func startVerificationPolling(completion: @escaping (Bool) -> Void) {
        Task {
            await pollForVerification(completion: completion)
        }
    }
    
    @MainActor
    private func pollForVerification(completion: @escaping (Bool) -> Void) async {
        var pollAttempts = 0
        let maxAttempts = 20 // Poll for 5 minutes (60 * 5 seconds)
        
        while pollAttempts < maxAttempts {
            do {
                let sessionResponse = try await apiService.checkSession()
                
                if sessionResponse?.verified == 1 {
                    if let sessionData = sessionManager.loadSession() {
                       
                        let verifiedSessionData = StorachaSessionData(
                            sessionId: sessionData.sessionId,
                            did: sessionData.did,
                            email: sessionData.email,
                            expiresAt: sessionData.expiresAt,
                            verified: true
                        )
                        
                        try sessionManager.saveSession(verifiedSessionData)
                      
                        self.isAuthenticated = true
                        if let currentUser = self.currentUser {
                            self.currentUser = StorachaUser(
                                did: currentUser.did,
                                email: currentUser.email,
                                sessionId: currentUser.sessionId
                            )
                        }
                        completion(true)
                        return
                    }
                }
                
                pollAttempts += 1
                
                // Wait 5 seconds before next poll
                if pollAttempts < maxAttempts {
                    try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                }
                
            } catch {
                // Continue polling on error, but increment attempt count
                pollAttempts += 1
                if pollAttempts < maxAttempts {
                    try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                }
            }
        }
        
        // Polling timed out
        completion(false)
    }
    
   
    @MainActor
    func stopVerificationPolling() {
        // This will be handled by the Task cancellation in the view
    }
    
    // MARK: - Error Handling
    @MainActor
    func clearError() {
        error = nil
        isLoginError = false
    }
}

// MARK: - Enhanced Login State
class StorachaLoginState: ObservableObject {
    @Published var email: String = ""
    @Published var isBusy: Bool = false
    @Published var isLoginError: Bool = false
    @Published var errorMessage: String = ""
    
    private let appState: StorachaAppState
    
    init(appState: StorachaAppState) {
        self.appState = appState
        
        // Pre-fill email if available
        if !appState.lastUsedEmail.isEmpty {
            self.email = appState.lastUsedEmail
        }
    }
    
    var isValid: Bool {
        return !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    @MainActor
    func login() async {
        guard isValid else { return }
        
        isBusy = true
        isLoginError = false
        errorMessage = ""
        
        await appState.login(email: email)
        
        // Check if login was successful
        if !appState.isAuthenticated, let error = appState.error {
            isLoginError = true
            errorMessage = error.localizedDescription
            appState.clearError()
        }
        
        isBusy = false
    }
    
    func cancel() {
        // Handle cancel action
    }
    
    func createAccount() {
        // Handle create account action
        // You might want to open a web view or handle registration
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
