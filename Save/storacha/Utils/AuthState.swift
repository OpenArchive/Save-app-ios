//
//  AuthState.swift
//  Save
//
//  Created by navoda on 2025-08-31.
//  Copyright © 2025 Open Archive. All rights reserved.
//


import Foundation

class AuthState: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var currentUser: StorachaUser?
    @Published var lastUsedEmail: String = ""
    @Published var email: String = ""
    @Published var isBusy: Bool = false
    @Published var isLoading: Bool = false
    @Published var isLoginError: Bool = false
    @Published var error: StorachaAPIError?

    private let apiService = StorachaAPIService.shared
    private let sessionManager = SessionManager.shared
    
    var isValid: Bool {
        return !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    init() {
        self.lastUsedEmail = sessionManager.getLastEmail() ?? ""
        restoreSession()
    }

    private func restoreSession() {
        guard let sessionData = sessionManager.loadSession() else { return }
        self.currentUser = StorachaUser(
            did: sessionData.did,
            email: sessionData.email,
            sessionId: sessionData.sessionId
        )
        sessionManager.setLastEmail( self.lastUsedEmail)
        self.isAuthenticated = sessionData.verified
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

    // MARK: - Logout
    @MainActor
    func logout() {
        Task {
            try? await apiService.logout()
        }
        sessionManager.clearSession()
        sessionManager.setLastEmail("")
        currentUser = nil
        isAuthenticated = false
        error = nil
        isLoginError = false
        isBusy = false
        isLoading = false
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
                
                if ((sessionResponse?.verified) ?? false ) {
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
                        sessionManager.setLastEmail(currentUser?.email ?? "")
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
    
    // MARK: - Email validation helper
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format: "SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
    // MARK: - Error Handling
    @MainActor
    func clearError() {
        error = nil
        isLoginError = false
    }
}
