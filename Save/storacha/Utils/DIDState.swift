//
//  DIDState.swift
//  Save
//
//  Created by navoda on 2025-08-31.
//  Copyright © 2025 Open Archive. All rights reserved.
//

import Foundation

class DIDState: ObservableObject {
    @Published var dids: [String] = []
    @Published var isLoading: Bool = false
    @Published var error: StorachaAPIError?
    
    // Auth error handling
    @Published var showUnauthorizedAlert: Bool = false
    @Published var unauthorizedMessage: String = ""
    @Published var shouldNavigateToLogin: Bool = false

    private let apiService = StorachaAPIService.shared
    private let sessionManager = SessionManager.shared

    @MainActor
    func loadDIDs(for spaceDid: String) async {
        isLoading = true
        error = nil
        do {
            let users = try await apiService.listDelegations(spaceDid: spaceDid)
            self.dids = users
        } catch {
            let apiError = error as? StorachaAPIError ?? .networkError(error)
            self.error = apiError
            self.dids = []
            
            // Handle 401 errors (always admin context for DID management)
            await handle401Error(apiError)
        }
        isLoading = false
    }

    @MainActor
    func addDID(for spaceDid: String, did: String, expiresInHours: Int = 24) async {
        isLoading = true
        error = nil

        do {
            _ = try await apiService.createDelegation(
                userDid: did,
                spaceDid: spaceDid,
                expiresInHours: expiresInHours
            )
            // refresh list after add
            await loadDIDs(for: spaceDid)
        } catch {
            let apiError = error as? StorachaAPIError ?? .networkError(error)
            self.error = apiError
            
            // Handle 401 errors
            await handle401Error(apiError)
        }

        isLoading = false
    }

    // MARK: - Revoke DID
    @MainActor
    func revokeDID(for spaceDid: String, did: String) async {
        isLoading = true
        error = nil

        do {
            _ = try await apiService.revokeDelegation(userDid: did, spaceDid: spaceDid)
            // refresh list after revoke
            await loadDIDs(for: spaceDid)
        } catch {
            let apiError = error as? StorachaAPIError ?? .networkError(error)
            self.error = apiError
            
            // Handle 401 errors
            await handle401Error(apiError)
        }

        isLoading = false
    }
    
    // MARK: - 401 Error Handling
    @MainActor
    private func handle401Error(_ error: StorachaAPIError) async {
        // Check if it's a 401 error
        if case .unauthorized = error {
            // DID management is always admin context, so no delegated user option
            unauthorizedMessage = NSLocalizedString("Your session has expired. Please login again to continue." , comment: "")
            showUnauthorizedAlert = true
        }
    }
    
    // MARK: - Alert Actions
    @MainActor
    func handleBackToLoginAction() {
        showUnauthorizedAlert = false
        shouldNavigateToLogin = true
        sessionManager.clearSession()
    }
    
    @MainActor
    func resetNavigationState() {
        shouldNavigateToLogin = false
    }
}
