//
//  SpaceState.swift
//  Save
//
//  Created by navoda on 2025-08-31.
//  Copyright © 2025 Open Archive. All rights reserved.
//

import Foundation

@MainActor
class SpaceState: ObservableObject {
    @Published var spaces: [StorachaSpace] = []
    @Published var isLoading: Bool = false
    @Published var uploads: [StorachaUploadItem] = []
    @Published var uploadsCursor: String? = nil
    @Published var uploadsHasMore: Bool = true
    @Published var isLoadingUploads: Bool = false
    @Published var error: StorachaAPIError?
    
    // Upload-specific state
    @Published var isUploading: Bool = false
    @Published var uploadProgress: Double = 0.0
    @Published var uploadResult: Result<UploadResponse, Error>?
    @Published var shouldRefreshUploads: Bool = false
    
    // Auth error handling
    @Published var showUnauthorizedAlert: Bool = false
    @Published var unauthorizedMessage: String = ""
    @Published var shouldNavigateToLogin: Bool = false
    @Published var isDelegatedUserError: Bool = false
    
    private let keyManager = DIDKeyManager()
    private let apiService = StorachaAPIService.shared
    private let bridgeUploader = BridgeUploader()
    private let sessionManager = SessionManager.shared
    
    // MARK: - Load Spaces
    func loadSpaces() async {
        isLoading = true
        error = nil

        do {
            let fetchedSpaces = try await apiService.getSpaces()
            self.spaces = fetchedSpaces
            try sessionManager.saveSpacesCount(fetchedSpaces.count)
            try sessionManager.saveDelegatedSpaceCount(fetchedSpaces.filter { !$0.isAdmin }.count)
        } catch {
            let apiError = error as? StorachaAPIError ?? .networkError(error)
                   self.error = apiError
                   let hasDelegatedSpace = self.spaces.contains { !$0.isAdmin }
                   
                   await handle401Error(apiError, isDelegatedUser: hasDelegatedSpace)
                   self.spaces = []
        }

        isLoading = false
    }
  
    // MARK: - Load files in space for a user
    func loadUploads(for spaceDid: String, isAdmin: Bool, reset: Bool = false) async {
        if reset {
            uploads = []
            uploadsCursor = nil
            uploadsHasMore = true
        }
        
        guard uploadsHasMore else { return }
        
        isLoadingUploads = true
        defer { isLoadingUploads = false }
        
        do {
            let response = try await apiService.listUploads(spaceDid: spaceDid, cursor: uploadsCursor, isAdmin: isAdmin)
            uploads.append(contentsOf: response.uploads)
            uploadsCursor = response.uploads.last?.cid
            uploadsHasMore = response.hasMore
        } catch {
            uploads = []
            uploadsHasMore = false
            
            // Handle 401 errors
            let apiError = error as? StorachaAPIError ?? .networkError(error)
            await handle401Error(apiError, isDelegatedUser: !isAdmin)
        }
    }
    
    // MARK: - Upload File
    func uploadFile(fileURL: URL, spaceDid: String, isAdmin: Bool) async {
        isUploading = true
        uploadProgress = 0.0
        uploadResult = nil
        
        let sessionData = sessionManager.loadSession()
        do {
            // Get user DID (required for delegated uploads; delegated users can upload without login via x-user-did)
            let userDid = try getOrCreateDID()
            
            // Step 1: Create temporary file from URL (if needed)
            let tempFile = try createTempFileIfNeeded(from: fileURL)
            uploadProgress = 0.1
            
            // --- TEMPORARY: Bridge store/add broken; using Token Service /upload until native space/blob/add or long-term decision ---
            let tokenResult = try await apiService.uploadFileViaTokenService(
                fileURL: tempFile,
                spaceDid: spaceDid,
                isAdmin: isAdmin,
                userDid: userDid,
                sessionId: sessionData?.sessionId
            )
            uploadProgress = 1.0
            
            let uploadResponse = UploadResponse(
                success: tokenResult.success,
                cid: tokenResult.cid,
                size: tokenResult.size
            )
            uploadResult = .success(uploadResponse)
            await loadUploads(for: spaceDid, isAdmin: isAdmin, reset: true)
            cleanupTempFile(tempFile, originalURL: fileURL)
            
            // --- OLD BRIDGE PATH (commented out, bridge store/add broken) ---
            // let userDid = try getOrCreateDID()
            // print("Generating CAR file for: \(fileURL.lastPathComponent)")
            // let carResult = try CarFileCreator.createCarFile(from: tempFile)
            // uploadProgress = 0.3
            // try saveCarFileForDebugging(carResult: carResult, originalFileName: fileURL.lastPathComponent)
            // uploadProgress = 0.4
            // let bridgeResult = try await bridgeUploader.uploadFile(
            //     file: tempFile,
            //     carData: carResult.carData,
            //     carCid: carResult.carCid,
            //     rootCid: carResult.rootCid,
            //     spaceDid: spaceDid,
            //     userDid: userDid,
            //     sessionId: sessionData?.sessionId,
            //     isAdmin: isAdmin
            // )
            // let uploadResponse = UploadResponse(success: true, cid: bridgeResult.rootCid, size: bridgeResult.size)
            // uploadResult = .success(uploadResponse)
            // print("Upload completed successfully. CID: \(bridgeResult.rootCid)")
            // --- END OLD BRIDGE PATH ---
            
        } catch {
            uploadResult = .failure(error)
            
            // Handle 401 errors
            let apiError = error as? StorachaAPIError ?? .networkError(error)
            await handle401Error(apiError, isDelegatedUser: !isAdmin)
        }
        
        isUploading = false
    }
    
    // MARK: - 401 Error Handling
    private func handle401Error(_ error: StorachaAPIError, isDelegatedUser: Bool = false) async {
        // Check if it's a 401 error
        if case .unauthorized = error {
            isDelegatedUserError = isDelegatedUser
            
            if isDelegatedUser {
                unauthorizedMessage = "Your access to this space has been revoked. Would you like to refresh your spaces list or return to login?"
            } else {
                unauthorizedMessage = "Your session has expired. Please log in again."
            }
            
            showUnauthorizedAlert = true
        }
    }
    
    // MARK: - Alert Actions
    func handleStayHereAction() async {
        showUnauthorizedAlert = false
        // Refresh spaces for delegated user
        await loadSpaces()
    }
    
    func handleBackToLoginAction() {
        showUnauthorizedAlert = false
        shouldNavigateToLogin = true
       
        sessionManager.clearSession()
    }
    
    func resetNavigationState() {
        shouldNavigateToLogin = false
    }
    
    // MARK: - Helper Methods
    private func createTempFileIfNeeded(from url: URL) throws -> URL {
        
        // Check if it's already in our app's container (like temp files we created)
        let tempDirectory = FileManager.default.temporaryDirectory
        let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        
        if url.path.hasPrefix(tempDirectory.path) || url.path.hasPrefix(cachesDirectory.path) {
            return url
        }
        
        // For security-scoped resources (like file picker), try to access
        var needsSecurityScope = false
        if url.scheme == "file" && !url.path.contains("/var/mobile/Media/") {
            // This looks like a file picker URL, try security scope
            needsSecurityScope = url.startAccessingSecurityScopedResource()
        }
        
        defer {
            if needsSecurityScope {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        do {
            // Try to read the file
            let data = try Data(contentsOf: url)
            
            // Create temp file with preserved filename
            let originalName = url.lastPathComponent.isEmpty ? "file_\(Int(Date().timeIntervalSince1970))" : url.lastPathComponent
            let tempFile = tempDirectory.appendingPathComponent("upload_\(UUID().uuidString)_\(originalName)")
            
            // Write to temp file
            try data.write(to: tempFile)
            
            return tempFile
            
        } catch {
            throw StorachaUploadError.fileAccessError("Cannot read file: \(error.localizedDescription)")
        }
    }
    
    private func saveCarFileForDebugging(carResult: CarFileResult, originalFileName: String) throws {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let carDirectory = documentsPath.appendingPathComponent("car_files")
        
        // Create directory if it doesn't exist
        try FileManager.default.createDirectory(at: carDirectory, withIntermediateDirectories: true)
        
        // Create CAR filename
        let nameWithoutExtension = (originalFileName as NSString).deletingPathExtension
        let carFileName = "\(nameWithoutExtension)_\(Int(Date().timeIntervalSince1970)).car"
        let carFile = carDirectory.appendingPathComponent(carFileName)
        
        // Write CAR data
        try carResult.carData.write(to: carFile)
    }
    
    private func cleanupTempFile(_ tempFile: URL, originalURL: URL) {
        // Only remove temp files we created (they have "upload_" prefix)
        if tempFile.lastPathComponent.hasPrefix("upload_") {
            do {
                try FileManager.default.removeItem(at: tempFile)
            } catch {
            }
        }
    }
    
    func resetUploadState() {
        uploadResult = nil
        uploadProgress = 0.0
        isUploading = false
    }
    
    // Optionally: helper to clear error
    func clearError() {
        error = nil
    }
    
    // MARK: - Generate DID for QR code
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
