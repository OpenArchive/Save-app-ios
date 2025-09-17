
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
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                let responseBody = String(data: data, encoding: .utf8) ?? "No response body"
                logger.error("Bridge API request failed - Status: \(statusCode), Body: \(responseBody)")
                throw BridgeUploadError.networkError("Bridge API request failed with status \(statusCode): \(responseBody)")
            }
            
            let responseString = String(data: data, encoding: .utf8) ?? ""
            logger.info("store/add response: \(responseString)")
            
            // Parse the response array
            guard let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                  let firstResponse = jsonArray.first else {
                throw BridgeUploadError.parseError("Invalid response format")
            }
            
            let responseData = try JSONSerialization.data(withJSONObject: firstResponse)
            let storeResponse = try JSONDecoder().decode(StoreAddResponse.self, from: responseData)
            
            if let error = storeResponse.p.out.error {
                let errorMsg = "Bridge store/add error"
                logger.error("\(errorMsg)")
                
                if retryCount == 0 {
                    logger.error("Token expired, need to regenerate tokens")
                    throw BridgeUploadError.tokenExpired("Token expired - need to regenerate tokens")
                }
                
                throw BridgeUploadError.bridgeError(errorMsg)
            }
            
            guard let success = storeResponse.p.out.ok else {
                throw BridgeUploadError.parseError("Missing success response")
            }
            
            return success
        } catch {
            logger.error("store/add failed: \(error.localizedDescription)")
            
            // Check for specific error patterns
            if error.localizedDescription.contains("unexpected end of data") {
                logger.error("Unexpected end of data detected!")
                logger.error("CAR CID: \(carCid)")
                logger.error("CAR size: \(carSize)")
                logger.error("Space DID: \(spaceDid)")
                logger.error("Token X-Auth-Secret starts with: \(String(tokens.xAuthSecret.prefix(20)))...")
                logger.error("Request JSON length: \(requestData.count)")
            }
            
            throw error
        }
    }
    
    func uploadAddWithRetry(tokens: BridgeTokens, spaceDid: String, rootCid: String, retryCount: Int = 0) async throws -> UploadAddSuccess {
        let uploadTask = UploadAddTask(
            root: ["/": rootCid]
        )
        
        let taskRequest = BridgeTaskRequest(
            tasks: [
                [.string("upload/add"), .string(spaceDid), .uploadTask(uploadTask)]
            ]
        )
        
        // Use correct bridge endpoint
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
                throw BridgeUploadError.networkError("Invalid response type")
            }
            
            let responseString = String(data: data, encoding: .utf8) ?? ""
            logger.info("upload/add response (\(httpResponse.statusCode)): \(responseString)")
            
            guard httpResponse.statusCode == 200 else {
                throw BridgeUploadError.networkError("Bridge API request failed with status: \(httpResponse.statusCode)")
            }
            
            // Parse the response array - bridge returns array of responses
            guard let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                  let firstResponse = jsonArray.first else {
                throw BridgeUploadError.parseError("Invalid response format - expected array")
            }
            
            let responseData = try JSONSerialization.data(withJSONObject: firstResponse)
            let uploadResponse = try JSONDecoder().decode(UploadAddResponse.self, from: responseData)
            
            if let error = uploadResponse.p.out.error {
                let errorMsg = "Bridge upload/add error: \(error)"
                logger.error("\(errorMsg)")
                throw BridgeUploadError.bridgeError(errorMsg)
            }
            
            guard let success = uploadResponse.p.out.ok else {
                throw BridgeUploadError.parseError("Missing success response in upload/add")
            }
            
            return success
        } catch {
            logger.error("upload/add failed: \(error.localizedDescription)")
            
            if error.localizedDescription.contains("unexpected end of data") {
                logger.error("Unexpected end of data detected in upload/add!")
                logger.error("Root CID: \(rootCid)")
                logger.error("Space DID: \(spaceDid)")
                logger.error("Request JSON length: \(requestData.count)")
            }
            
            throw error
        }
    }
}
