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

    private let apiService = StorachaAPIService.shared

    @MainActor
    func loadDIDs(for spaceDid: String) async {
        isLoading = true
        error = nil
        do {
            let users = try await apiService.listDelegations(spaceDid: spaceDid)
            self.dids = users
        } catch {
            self.error = error as? StorachaAPIError ?? .networkError(error)
            self.dids = []
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
                await MainActor.run {
                    self.error = error as? StorachaAPIError ?? .networkError(error)
                }
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
                await MainActor.run {
                    self.error = error as? StorachaAPIError ?? .networkError(error)
                }
            }

            isLoading = false
        }
}
