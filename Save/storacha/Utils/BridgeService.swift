//
//  BridgeService.swift
//  Save
//
//  Created by navoda on 2025-09-17.
//  Copyright © 2025 Open Archive. All rights reserved.
//

import Foundation
import OSLog

class BridgeService: ObservableObject {
    private let bridgeBaseURL = "https://up.storacha.network/"
    private let session: URLSession
    private let logger = Logger(subsystem: "BridgeUploader", category: "Upload")
    
    init(session: URLSession = URLSession.shared) {
        self.session = session
    }
    
    // MARK: - Error Parsing
    
    private func parseErrorFromResponse(_ statusCode: Int, responseBody: String) throws {
        logger.error("Parsing error - Status: \(statusCode), Body: \(responseBody)")
        
        switch statusCode {
        case 503:
            throw BridgeUploadError.storageServiceUnavailable
        case 431:
            throw BridgeUploadError.requestTooLarge
        case 429:
            throw BridgeUploadError.rateLimitExceeded
        case 500...599:
            throw BridgeUploadError.serverError
        default:
            // Check response body for specific errors
            let lowercasedBody = responseBody.lowercased()
            
            if lowercasedBody.contains("invalidtoken") || lowercasedBody.contains("expired") {
                throw BridgeUploadError.tokenExpired(NSLocalizedString("There was an authentication issue. The app will try again automatically.", comment: ""))
            } else if lowercasedBody.contains("s3 upload failed") || lowercasedBody.contains("s3") {
                throw BridgeUploadError.s3UploadFailed(NSLocalizedString("There was a problem with the storage service. Please try again.", comment: ""))
            } else if lowercasedBody.contains("storage") || lowercasedBody.contains("quota") || lowercasedBody.contains("space") {
                throw BridgeUploadError.insufficientStorage
            } else {
                throw BridgeUploadError.networkError(NSLocalizedString("Something went wrong with the upload. Please try again.", comment: ""))
            }
        }
    }
    
    private func parseErrorFromMessage(_ errorMessage: String) throws {
        let lowercased = errorMessage.lowercased()
        
        if lowercased.contains("invalidtoken") || lowercased.contains("expired") {
            throw BridgeUploadError.tokenExpired(NSLocalizedString("There was an authentication issue. The app will try again automatically.", comment: ""))
        } else if lowercased.contains("s3 upload failed") || lowercased.contains("s3") {
            throw BridgeUploadError.s3UploadFailed(NSLocalizedString("There was a problem with the storage service. Please try again.", comment: ""))
        } else if lowercased.contains("storage") || lowercased.contains("quota") {
            throw BridgeUploadError.insufficientStorage
        } else if lowercased.contains("503") {
            throw BridgeUploadError.storageServiceUnavailable
        } else if lowercased.contains("429") {
            throw BridgeUploadError.rateLimitExceeded
        } else if lowercased.contains("431") || lowercased.contains("too large") {
            throw BridgeUploadError.requestTooLarge
        } else if lowercased.contains("500") || lowercased.contains("server") {
            throw BridgeUploadError.serverError
        } else {
            throw BridgeUploadError.bridgeError(errorMessage)
        }
    }
    
    // MARK: - Store Add
    
    func storeAddWithRetry(tokens: BridgeTokens, spaceDid: String, carCid: String, carSize: Int, retryCount: Int = 0) async throws -> StoreAddSuccess {
        let storeTask = StoreAddTask(
            link: ["/": carCid],
            size: carSize
        )
        
        let taskRequest = BridgeTaskRequest(
            tasks: [
                [.string("store/add"), .string(spaceDid), .storeTask(storeTask)]
            ]
        )
        
        var urlRequest = URLRequest(url: URL(string: "\(bridgeBaseURL)bridge")!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(tokens.xAuthSecret, forHTTPHeaderField: "X-Auth-Secret")
        urlRequest.setValue(tokens.authorization, forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestData = try JSONEncoder().encode(taskRequest)
        urlRequest.httpBody = requestData
        
        logger.info("store/add request JSON: \(String(data: requestData, encoding: .utf8) ?? "")")
        
        do {
            let (data, response) = try await session.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw BridgeUploadError.networkError(NSLocalizedString("Invalid response from server", comment: ""))
            }
            
            let responseBody = String(data: data, encoding: .utf8) ?? "No response body"
            
            // Handle HTTP errors
            guard httpResponse.statusCode == 200 else {
                logger.error("Bridge API request failed - Status: \(httpResponse.statusCode), Body: \(responseBody)")
                try parseErrorFromResponse(httpResponse.statusCode, responseBody: responseBody)
                throw BridgeUploadError.networkError("Unexpected error") // Should not reach here
            }
            
            logger.info("store/add response: \(responseBody)")
            
            // Parse the response array
            guard let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                  let firstResponse = jsonArray.first else {
                throw BridgeUploadError.parseError("Invalid response format")
            }
            
            let responseData = try JSONSerialization.data(withJSONObject: firstResponse)
            let storeResponse = try JSONDecoder().decode(StoreAddResponse.self, from: responseData)
            
            // Check for errors in response
            if let errorValue = storeResponse.p.out.error {
                let errorString = String(describing: errorValue.value)
                logger.error("Bridge store/add error: \(errorString)")
                try parseErrorFromMessage(errorString)
                throw BridgeUploadError.bridgeError(errorString) // Fallback
            }
            
            guard let success = storeResponse.p.out.ok else {
                throw BridgeUploadError.parseError("Missing success response")
            }
            
            return success
            
        } catch let error as BridgeUploadError {
            // Re-throw BridgeUploadError as-is
            throw error
        } catch {
            logger.error("store/add failed: \(error.localizedDescription)")
            
            // Check for specific error patterns
            if error.localizedDescription.contains("unexpected end of data") {
                logger.error("Unexpected end of data detected!")
                logger.error("CAR CID: \(carCid)")
                logger.error("CAR size: \(carSize)")
                logger.error("Space DID: \(spaceDid)")
            }
            
            throw BridgeUploadError.networkError(NSLocalizedString("Something went wrong with the upload. Please try again.", comment: ""))
        }
    }
    
    // MARK: - Upload Add
    
    func uploadAddWithRetry(tokens: BridgeTokens, spaceDid: String, rootCid: String, retryCount: Int = 0) async throws -> UploadAddSuccess {
        let uploadTask = UploadAddTask(
            root: ["/": rootCid]
        )
        
        let taskRequest = BridgeTaskRequest(
            tasks: [
                [.string("upload/add"), .string(spaceDid), .uploadTask(uploadTask)]
            ]
        )
        
        var urlRequest = URLRequest(url: URL(string: "\(bridgeBaseURL)bridge")!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(tokens.xAuthSecret, forHTTPHeaderField: "X-Auth-Secret")
        urlRequest.setValue(tokens.authorization, forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestData = try JSONEncoder().encode(taskRequest)
        urlRequest.httpBody = requestData
        
        logger.info("upload/add request to: \(urlRequest.url?.absoluteString ?? "")")
        
        do {
            let (data, response) = try await session.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw BridgeUploadError.networkError(NSLocalizedString("Invalid response from server", comment: ""))
            }
            
            let responseBody = String(data: data, encoding: .utf8) ?? ""
            logger.info("upload/add response (\(httpResponse.statusCode)): \(responseBody)")
            
            // Handle HTTP errors
            guard httpResponse.statusCode == 200 else {
                try parseErrorFromResponse(httpResponse.statusCode, responseBody: responseBody)
                throw BridgeUploadError.networkError("Unexpected error") // Should not reach here
            }
            
            // Parse the response array - bridge returns array of responses
            guard let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                  let firstResponse = jsonArray.first else {
                throw BridgeUploadError.parseError("Invalid response format - expected array")
            }
            
            let responseData = try JSONSerialization.data(withJSONObject: firstResponse)
            let uploadResponse = try JSONDecoder().decode(UploadAddResponse.self, from: responseData)
            
            // Check for errors in response
            if let errorValue = uploadResponse.p.out.error {
                let errorString = String(describing: errorValue.value)
                logger.error("Bridge upload/add error: \(errorString)")
                try parseErrorFromMessage(errorString)
                throw BridgeUploadError.bridgeError(errorString) // Fallback
            }
            
            guard let success = uploadResponse.p.out.ok else {
                throw BridgeUploadError.parseError("Missing success response in upload/add")
            }
            
            return success
            
        } catch let error as BridgeUploadError {
            // Re-throw BridgeUploadError as-is
            throw error
        } catch {
            logger.error("upload/add failed: \(error.localizedDescription)")
            
            if error.localizedDescription.contains("unexpected end of data") {
                logger.error("Unexpected end of data detected in upload/add!")
                logger.error("Root CID: \(rootCid)")
                logger.error("Space DID: \(spaceDid)")
            }
            
            throw BridgeUploadError.networkError(NSLocalizedString("Something went wrong with the upload. Please try again.", comment: ""))
        }
    }
}
