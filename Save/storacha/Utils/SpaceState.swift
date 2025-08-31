//
//  SpaceState.swift
//  Save
//
//  Created by navoda on 2025-08-31.
//  Copyright © 2025 Open Archive. All rights reserved.
//


import Foundation

class SpaceState: ObservableObject {
    @Published var spaces: [StorachaSpace] = []
    @Published var isLoading: Bool = false
    @Published var uploads: [StorachaUploadItem] = []
    @Published var uploadsCursor: String? = nil
    @Published var uploadsHasMore: Bool = true
    @Published var isLoadingUploads: Bool = false
    @Published var error: StorachaAPIError?
    private let keyManager = DIDKeyManager()
    private let apiService = StorachaAPIService.shared

    // MARK: - Load Spaces
    @MainActor
    func loadSpaces() async {
        isLoading = true
        error = nil

        do {
            let fetchedSpaces = try await apiService.getSpaces()
            self.spaces = fetchedSpaces
        } catch {
            self.error = error as? StorachaAPIError ?? .networkError(error)
            self.spaces = []
        }

        isLoading = false
    }
  
    // MARK: - Load files in space for a user
    @MainActor
    func loadUploads(for spaceDid: String, reset: Bool = false) async {
            if reset {
                uploads = []
                uploadsCursor = nil
                uploadsHasMore = true
            }
            
            guard uploadsHasMore else { return }
            
            isLoadingUploads = true
            defer { isLoadingUploads = false }
            
            do {
                let response = try await apiService.listUploads(spaceDid: spaceDid, cursor: uploadsCursor)
                uploads.append(contentsOf: response.uploads)
                uploadsCursor = response.cursor
                uploadsHasMore = response.hasMore
            } catch {
                print("Failed to load uploads: \(error)")
                uploads = []
                uploadsHasMore = false
            }
        }
    
    // Optionally: helper to clear error
    @MainActor
    func clearError() {
        error = nil
    }
    //MARK: - Generate DID for QR code
    func getOrCreateDID() throws -> String {
            let keyPair: DIDKeyManager.DIDKeyPair
            do {
                keyPair = try keyManager.loadKeyPair()
            } catch {
                let generated = keyManager.generateKeyPair()
                try keyManager.saveKeyPair(generated)
                keyPair = generated
            }
            return keyPair.did
        }
}
