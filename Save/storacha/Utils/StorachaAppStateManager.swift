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
    @Published var spaces: [StorachaSpace] = []
    @Published var selectedSpace: StorachaSpace?
    @Published var recentUploads: [StorachaUpload] = []
    @Published var isLoading: Bool = false
    @Published var error: StorachaError?
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
        }
        
        // Verify session is still valid
        Task {
            do {
                let isValid = try await apiService.checkSession()
                await MainActor.run {
                    if !isValid {
                        self.logout()
                    } else {
                        // Load initial data
                        Task {
                            await self.loadSpaces()
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    self.logout()
                }
            }
        }
    }
    
    // MARK: - Authentication Actions
    @MainActor
    func login(email: String) async {
        isLoading = true
        error = nil
        
        do {
            let sessionData = try await apiService.login(email: email)
            
            let user = StorachaUser(
                did: sessionData.did,
                email: sessionData.email,
                sessionId: sessionData.sessionId
            )
            
            self.currentUser = user
            self.isAuthenticated = sessionData.verified
            self.lastUsedEmail = email
            
        } catch {
            self.error = StorachaError.authenticationFailed(error.localizedDescription)
        }
        
        isLoading = false
    }
    
    @MainActor
    func logout() {
        Task {
            try? await apiService.logout()
        }
        
        currentUser = nil
        isAuthenticated = false
        spaces = []
        selectedSpace = nil
        recentUploads = []
        error = nil
    }
    
    // MARK: - Space Management
    @MainActor
    func loadSpaces() async {
        guard isAuthenticated else { return }
        
        isLoading = true
        
        do {
            let loadedSpaces = try await apiService.getSpaces()
            self.spaces = loadedSpaces
            
            // Auto-select first space if none selected
            if selectedSpace == nil, let firstSpace = loadedSpaces.first {
                self.selectedSpace = firstSpace
                await loadSpaceUsage()
            }
        } catch {
            self.error = StorachaError.networkError(error)
        }
        
        isLoading = false
    }
    
    @MainActor
    func selectSpace(_ space: StorachaSpace) async {
        selectedSpace = space
        await loadSpaceUsage()
    }
    
    @MainActor
    func loadSpaceUsage() async {
        guard let space = selectedSpace else { return }
        
        do {
            let usage = try await apiService.getSpaceUsage(spaceDid: space.did)
            // Update the space usage in your UI
            // You might want to add usage to the StorachaSpace model
        } catch {
            self.error = StorachaError.networkError(error)
        }
    }
    
    // MARK: - Upload Management
    @MainActor
    func uploadFile(_ fileData: Data, fileName: String) async -> Bool {
        guard let space = selectedSpace else {
            error = StorachaError.insufficientPermissions
            return false
        }
        
        isLoading = true
        
        do {
            let uploadResponse = try await apiService.uploadFile(
                fileData,
                fileName: fileName,
                spaceDid: space.did
            )
            
            // Create upload record
            let upload = StorachaUpload(
                cid: uploadResponse.cid,
                fileName: fileName,
                size: uploadResponse.size,
                uploadDate: Date(),
                gatewayUrl: "https://\(uploadResponse.cid).ipfs.w3s.link/"
            )
            
            // Add to recent uploads
            recentUploads.insert(upload, at: 0)
            
            // Refresh space usage
            await loadSpaceUsage()
            
            isLoading = false
            return true
            
        } catch {
            self.error = StorachaError.uploadFailed(error.localizedDescription)
            isLoading = false
            return false
        }
    }
    
    // MARK: - Error Handling
    @MainActor
    func clearError() {
        error = nil
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
            return "Authentication failed: \(message)"
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

// MARK: - Actions
enum StorachaLoginAction {
    case login
    case cancel
    case createAccount
}

enum StorachaAppAction {
    // Authentication
    case login(email: String)
    case logout
    case checkSession
    
    // Spaces
    case loadSpaces
    case selectSpace(StorachaSpace)
    case loadSpaceUsage
    
    // Uploads
    case uploadFile(Data, fileName: String)
    case loadRecentUploads
    
    // Delegations
    case createDelegation(userDid: String, spaceDid: String, expiresInHours: Int)
    
    // Error handling
    case clearError
}

// MARK: - State Dispatcher (Optional Redux-like pattern)
class StorachaStateDispatcher: ObservableObject {
    @Published var appState = StorachaAppState()
    
    func dispatch(_ action: StorachaAppAction) {
        Task {
            await handleAction(action)
        }
    }
    
    @MainActor
    private func handleAction(_ action: StorachaAppAction) async {
        switch action {
        case .login(let email):
            await appState.login(email: email)
            
        case .logout:
            appState.logout()
            
        case .checkSession:
            // Handle session check if needed
            break
            
        case .loadSpaces:
            await appState.loadSpaces()
            
        case .selectSpace(let space):
            await appState.selectSpace(space)
            
        case .loadSpaceUsage:
            await appState.loadSpaceUsage()
            
        case .uploadFile(let data, let fileName):
            _ = await appState.uploadFile(data, fileName: fileName)
            
        case .loadRecentUploads:
            // Handle loading recent uploads if needed
            break
            
        case .createDelegation(let userDid, let spaceDid, let expiresInHours):
            await createDelegation(userDid: userDid, spaceDid: spaceDid, expiresInHours: expiresInHours)
            
        case .clearError:
            appState.clearError()
        }
    }
    
    @MainActor
    private func createDelegation(userDid: String, spaceDid: String, expiresInHours: Int) async {
        appState.isLoading = true
        
        do {
            _ = try await StorachaAPIService.shared.createDelegation(
                userDid: userDid,
                spaceDid: spaceDid,
                expiresInHours: expiresInHours
            )
            // Handle successful delegation creation
        } catch {
            appState.error = StorachaError.networkError(error)
        }
        
        appState.isLoading = false
    }
}
