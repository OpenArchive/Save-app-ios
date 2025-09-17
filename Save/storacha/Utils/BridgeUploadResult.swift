//
//  BridgeUploadResult.swift
//  Save
//
//  Created by navoda on 2025-09-17.
//  Copyright © 2025 Open Archive. All rights reserved.
//


import Foundation
import OSLog

class BridgeUploader: ObservableObject {
    private let bridgeBaseURL = "https://up.storacha.network/"
    private let session: URLSession
    private let logger = Logger(subsystem: "BridgeUploader", category: "Upload")
    private let apiService = StorachaAPIService.shared
    private let bridgeService = BridgeService()
    init(session: URLSession = URLSession.shared) {
        self.session = session
    }
    
    func uploadFile(
        file: URL,
        carData: Data,
        carCid: String,
        rootCid: String,
        spaceDid: String,
        userDid: String? = nil,
        sessionId: String? = nil
    ) async throws -> BridgeUploadResult {
        // Validate CID formats
        guard carCid.hasPrefix("bag") else {
            throw BridgeUploadError.invalidCid("CAR CID must start with 'bag', got: \(carCid)")
        }
        guard rootCid.hasPrefix("bafy") else {
            throw BridgeUploadError.invalidCid("Root CID must start with 'bafy', got: \(rootCid)")
        }
        
        logger.info("Starting bridge upload - CAR CID: \(carCid), Root CID: \(rootCid), Size: \(carData.count)")
        
        do {
            // Step 1: Generate bridge tokens
            let tokens = try await apiService.generateBridgeTokens(spaceDid: spaceDid, userDid: userDid, sessionId: sessionId)
            
            // Small delay to ensure token propagation
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            
            // Step 2: Call store/add to get S3 pre-signed URL
            let storeResult = try await bridgeService.storeAddWithRetry(tokens: tokens, spaceDid: spaceDid, carCid: carCid, carSize: carData.count)
            
            // Step 3: Upload to S3 (if required)
            if storeResult.status == "upload", let url = storeResult.url {
                logger.info("S3 upload required")
                try await uploadToS3(carData: carData, url: url, headers: storeResult.headers ?? [:])
                logger.info("S3 upload completed")
            } else {
                logger.info("File already uploaded, status: \(storeResult.status)")
            }
            
            // Step 4: Register upload with upload/add
            let uploadResult = try await bridgeService.uploadAddWithRetry(tokens: tokens, spaceDid: spaceDid, rootCid: rootCid)
            logger.info("Upload registered successfully")
            
            return BridgeUploadResult(
                rootCid: uploadResult.root["/"] ?? rootCid,
                carCid: carCid,
                size: carData.count
            )
        } catch {
            logger.error("Bridge upload failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    
    
    private func uploadToS3(carData: Data, url: String, headers: [String: String]) async throws {
        var urlRequest = URLRequest(url: URL(string: url)!)
        urlRequest.httpMethod = "PUT"
        urlRequest.setValue("application/vnd.ipld.car", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("\(carData.count)", forHTTPHeaderField: "Content-Length")
        
        // Add provided headers
        for (key, value) in headers {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }
        
        urlRequest.httpBody = carData
        urlRequest.timeoutInterval = 300 // 5 minutes for large files
        
        let (_, response) = try await session.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            logger.error("S3 upload failed - Code: \(statusCode)")
            logger.error("CAR data size: \(carData.count) bytes")
            throw BridgeUploadError.s3UploadFailed("S3 upload failed with status code: \(statusCode)")
        }
    }
}
