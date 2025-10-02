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
    
    // Upload-specific state
    @Published var isUploading: Bool = false
    @Published var uploadProgress: Double = 0.0
    @Published var uploadResult: Result<UploadResponse, Error>?
    @Published var shouldRefreshUploads: Bool = false
    
    private let keyManager = DIDKeyManager()
    private let apiService = StorachaAPIService.shared
    private let bridgeUploader = BridgeUploader()
    private let sessionManager = SessionManager.shared
    
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
    func loadUploads(for spaceDid: String,isAdmin:Bool, reset: Bool = false) async {
        if reset {
            uploads = []
            uploadsCursor = nil
            uploadsHasMore = true
        }
        
        guard uploadsHasMore else { return }
        
        isLoadingUploads = true
        defer { isLoadingUploads = false }
        
        do {
            let response = try await apiService.listUploads(spaceDid: spaceDid,cursor: uploadsCursor, isAdmin:isAdmin)
            uploads.append(contentsOf: response.uploads)
            uploadsCursor = response.cursor
            uploadsHasMore = response.hasMore
        } catch {
            print("Failed to load uploads: \(error)")
            uploads = []
            uploadsHasMore = false
        }
    }
    
    // MARK: - Upload File
    @MainActor
    func uploadFile(fileURL: URL, spaceDid: String,isAdmin:Bool) async {
        isUploading = true
        uploadProgress = 0.0
        uploadResult = nil
        
            let  sessionData = sessionManager.loadSession()
            do {
                // Get user DID
                let userDid = try getOrCreateDID()
                
                // Step 1: Create temporary file from URL (if needed)
                let tempFile = try createTempFileIfNeeded(from: fileURL)
                uploadProgress = 0.1
                
                // Step 2: Generate CAR file
                print("Generating CAR file for: \(fileURL.lastPathComponent)")
                let carResult = try CarFileCreator.createCarFile(from: tempFile)
                uploadProgress = 0.3
                
                // Step 3: Save CAR data for debugging (optional)
                try saveCarFileForDebugging(carResult: carResult, originalFileName: fileURL.lastPathComponent)
                uploadProgress = 0.4
        
                print("Starting bridge upload")
                let bridgeResult = try await bridgeUploader.uploadFile(
                    file: tempFile,
                    carData: carResult.carData,
                    carCid: carResult.carCid,
                    rootCid: carResult.rootCid,
                    spaceDid: spaceDid,
                    userDid: userDid,
                    sessionId: sessionData?.sessionId,
                    isAdmin:isAdmin
                )
                uploadProgress = 1.0
                
                // Step 5: Create success response
                let uploadResponse = UploadResponse(
                    success: true,
                    cid: bridgeResult.rootCid,
                    size: bridgeResult.size
                )
                
                uploadResult = .success(uploadResponse)
                print("Upload completed successfully. CID: \(bridgeResult.rootCid)")
                
                // Step 6: Refresh the uploads list
                await loadUploads(for: spaceDid,isAdmin:isAdmin, reset: true)
                
                // Cleanup temp file if we created one
                cleanupTempFile(tempFile, originalURL: fileURL)
                
            } catch {
                print("Upload failed: \(error.localizedDescription)")
                uploadResult = .failure(error)
            }
        
        isUploading = false
    }
    
    // MARK: - Helper Methods
    private func createTempFileIfNeeded(from url: URL) throws -> URL {
        print("Processing file URL: \(url)")
        
        // Check if it's already in our app's container (like temp files we created)
        let tempDirectory = FileManager.default.temporaryDirectory
        let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        
        if url.path.hasPrefix(tempDirectory.path) || url.path.hasPrefix(cachesDirectory.path) {
            print("File is already in app container, using directly")
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
            print("Created temp file: \(tempFile.path)")
            
            return tempFile
            
        } catch {
            print("Failed to read file at \(url): \(error)")
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
        print("CAR file saved for debugging: \(carFile.path)")
    }
    
    private func cleanupTempFile(_ tempFile: URL, originalURL: URL) {
        // Only remove temp files we created (they have "upload_" prefix)
        if tempFile.lastPathComponent.hasPrefix("upload_") {
            do {
                try FileManager.default.removeItem(at: tempFile)
                print("Cleaned up temp file: \(tempFile.path)")
            } catch {
                print("Failed to cleanup temp file: \(error)")
            }
        }
    }
    
    @MainActor
    func resetUploadState() {
        uploadResult = nil
        uploadProgress = 0.0
        isUploading = false
    }
    
    // Optionally: helper to clear error
    @MainActor
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
