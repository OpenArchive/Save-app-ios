//
//  StorachaAPIService.swift
//  Save
//
//  Created by navoda on 2025-08-22.
//  Copyright © 2025 Open Archive. All rights reserved.
//

import Foundation
import CryptoKit
import Combine
import OSLog

// MARK: - Main API Service
class StorachaAPIService {
    static let shared = StorachaAPIService()
    
    private let baseURL: String
    private let session = URLSession.shared
    private let keyManager = DIDKeyManager()
    private let sessionManager = SessionManager.shared
    private let logger = Logger(subsystem: "StorachaApiService", category: "API")
    
    private init(baseURL: String = "http://save-storacha.staging.hypha.coop:3000") {
        self.baseURL = baseURL
    }
    
    // MARK: - Configuration
    func configure(baseURL: String) {
        // You can add a method to reconfigure if needed
    }
    
    // MARK: - Helper to handle HTTP errors
    private func handleHTTPError(statusCode: Int, data: Data) throws {
        let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
        
        if statusCode == 401 {
            logger.error("Unauthorized access - Status: 401, Message: \(errorMessage)")
            throw StorachaAPIError.unauthorized
        } else {
            logger.error("API Error - Status: \(statusCode), Message: \(errorMessage)")
            throw StorachaAPIError.serverError(statusCode, errorMessage)
        }
    }
    
    // MARK: - Authentication Methods
    func login(email: String) async throws -> StorachaSessionData {
        // Generate or load existing key pair
        let keyPair: DIDKeyManager.DIDKeyPair
        do {
            keyPair = try keyManager.loadKeyPair()
        } catch {
            keyPair = keyManager.generateKeyPair()
            try keyManager.saveKeyPair(keyPair)
        }
        
        // Step 1: Initiate login
        let loginResponse = try await initiateLogin(email: email, did: keyPair.did)
        if(!loginResponse.verified){
            
            // Step 2: Sign challenge if provided
            if let challenge = loginResponse.challenge,
               let challengeId = loginResponse.challengeId {
                let signature = try keyManager.signChallenge(challenge, with: keyPair.privateKey)
                return try await verifySignature(
                    did: keyPair.did,
                    challengeId: challengeId,
                    signature: signature,
                    sessionId: loginResponse.sessionId,
                    email: email
                )
            }
        }
        
        let sessionData = StorachaSessionData(
            sessionId: loginResponse.sessionId,
            did: loginResponse.did,
            email: email,
            expiresAt: nil,
            verified: loginResponse.verified
        )
        
        try sessionManager.saveSession(sessionData)
        return sessionData
    }
    
    private func initiateLogin(email: String, did: String) async throws -> StorachaLoginResponse {
        guard let url = URL(string: "\(baseURL)/auth/login") else {
            throw StorachaAPIError.invalidURL
        }
        
        let request = StorachaLoginRequest(email: email, did: did)
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        let (data, response) = try await session.data(for: urlRequest)
        
        if let rawResponse = String(data: data, encoding: .utf8) {
            print("Raw Login API Response: \(rawResponse)")
        }
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            try handleHTTPError(statusCode: httpResponse.statusCode, data: data)
        }
        
        return try JSONDecoder().decode(StorachaLoginResponse.self, from: data)
    }
    
    private func verifySignature(
        did: String,
        challengeId: String,
        signature: String,
        sessionId: String,
        email: String
    ) async throws -> StorachaSessionData {
        guard let url = URL(string: "\(baseURL)/auth/verify") else {
            throw StorachaAPIError.invalidURL
        }
        
        let request = StorachaVerifyRequest(
            did: did,
            challengeId: challengeId,
            signature: signature,
            sessionId: sessionId,
            email: email
        )
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        let (data, response) = try await session.data(for: urlRequest)
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            try handleHTTPError(statusCode: httpResponse.statusCode, data: data)
        }
        
        if let rawResponse = String(data: data, encoding: .utf8) {
            print("Raw verify signature API Response: \(rawResponse)")
        }
        
        let verifyResponse = try JSONDecoder().decode(StorachaVerifyResponse.self, from: data)
        
        let sessionData = StorachaSessionData(
            sessionId: verifyResponse.sessionId,
            did: verifyResponse.did,
            email: email,
            expiresAt: nil,
            verified: false
        )
        sessionManager.clearSession()
        try sessionManager.saveSession(sessionData)
        return sessionData
    }
    
    func checkSession() async throws -> StorachaSessionResponse? {
        guard let sessionData = sessionManager.loadSession() else {
            return nil
        }
        
        guard let url = URL(string: "\(baseURL)/auth/session") else {
            throw StorachaAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue(sessionData.sessionId, forHTTPHeaderField: "x-session-id")
        
        let (data, response) = try await session.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            if let errorString = String(data: data, encoding: .utf8) {
                print("Check Session HTTP Error \(httpResponse.statusCode): \(errorString)")
            }
            
            if httpResponse.statusCode == 401 {
                throw StorachaAPIError.unauthorized
            }
            return nil
        }
        
        if let rawResponse = String(data: data, encoding: .utf8) {
            print("Check Session Raw API Response: \(rawResponse)")
        }
        
        let sessionResponse = try JSONDecoder().decode(StorachaSessionResponse.self, from: data)
        return sessionResponse
    }
    
    func logout() async throws {
        guard let sessionData = sessionManager.loadSession() else { return }
        
        guard let url = URL(string: "\(baseURL)/auth/logout") else {
            throw StorachaAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(sessionData.sessionId, forHTTPHeaderField: "x-session-id")
        
        let (data, response) = try await session.data(for: request)
        
        if let rawResponse = String(data: data, encoding: .utf8) {
            print("Logout Raw API Response: \(rawResponse)")
        }
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            try handleHTTPError(statusCode: httpResponse.statusCode, data: data)
        }
        
        sessionManager.clearSession()
    }
    
    // MARK: - Space Management
    func getSpaces() async throws -> [StorachaSpace] {
        let keyPair: DIDKeyManager.DIDKeyPair
        do {
            keyPair = try keyManager.loadKeyPair()
        } catch {
            let generated = keyManager.generateKeyPair()
            try keyManager.saveKeyPair(generated)
            keyPair = generated
        }
        
        guard let url = URL(string: "\(baseURL)/spaces") else {
            throw StorachaAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        
        // Add session header only if available
        if let sessionData = sessionManager.loadSession() {
            request.setValue(sessionData.sessionId, forHTTPHeaderField: "x-session-id")
        }
        
        // Always pass DID
        request.setValue(keyPair.did, forHTTPHeaderField: "x-user-did")
        
        let (data, response) = try await session.data(for: request)
        
        if let rawResponse = String(data: data, encoding: .utf8) {
            print("Get Spaces Raw API Response: \(rawResponse)")
        }
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            try handleHTTPError(statusCode: httpResponse.statusCode, data: data)
        }
        
        return try JSONDecoder().decode([StorachaSpace].self, from: data)
    }
    
    func getSpaceUsage(spaceDid: String) async throws -> StorachaUsageDetail {
        guard let sessionData = sessionManager.loadSession() else {
            throw StorachaAPIError.authenticationFailed("No active session")
        }
        
        guard let url = URL(string: "\(baseURL)/spaces/usage?spaceDid=\(spaceDid)") else {
            throw StorachaAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue(sessionData.sessionId, forHTTPHeaderField: "x-session-id")
        
        let (data, response) = try await session.data(for: request)
        
        if let rawResponse = String(data: data, encoding: .utf8) {
            print("Get Space Usage Raw API Response: \(rawResponse)")
        }
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            try handleHTTPError(statusCode: httpResponse.statusCode, data: data)
        }
        
        let usageResponse = try JSONDecoder().decode(StorachaUsageResponse.self, from: data)
        return usageResponse.usage
    }
    
    // MARK: - File Upload
    func uploadFile(_ fileData: Data, fileName: String, spaceDid: String) async throws -> StorachaUploadResponse {
        guard let sessionData = sessionManager.loadSession() else {
            throw StorachaAPIError.authenticationFailed("No active session")
        }
        
        guard let url = URL(string: "\(baseURL)/upload") else {
            throw StorachaAPIError.invalidURL
        }
        
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue(sessionData.sessionId, forHTTPHeaderField: "x-session-id")
        
        var body = Data()
        
        // Add file data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add spaceDid
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"spaceDid\"\r\n\r\n".data(using: .utf8)!)
        body.append(spaceDid.data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let (data, response) = try await session.data(for: request)
        
        if let rawResponse = String(data: data, encoding: .utf8) {
            print("Upload File Raw API Response: \(rawResponse)")
        }
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            if httpResponse.statusCode == 401 {
                throw StorachaAPIError.unauthorized
            }
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw StorachaAPIError.uploadFailed(errorMessage)
        }
        
        return try JSONDecoder().decode(StorachaUploadResponse.self, from: data)
    }
    
    // MARK: - create Delegation
    func createDelegation(userDid: String, spaceDid: String, expiresInHours: Int = 24) async throws -> StorachaDelegationResponse {
        guard let sessionData = sessionManager.loadSession() else {
            throw StorachaAPIError.authenticationFailed("No active session")
        }
        
        guard let url = URL(string: "\(baseURL)/delegations/create") else {
            throw StorachaAPIError.invalidURL
        }
        
        let request = StorachaDelegationRequest(
            userDid: userDid,
            spaceDid: spaceDid,
            expiresIn: expiresInHours
        )
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(sessionData.sessionId, forHTTPHeaderField: "x-session-id")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        let (data, response) = try await session.data(for: urlRequest)
        
        if let rawResponse = String(data: data, encoding: .utf8) {
            print("Create Delegation Raw API Response: \(rawResponse)")
        }
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            try handleHTTPError(statusCode: httpResponse.statusCode, data: data)
        }
        
        return try JSONDecoder().decode(StorachaDelegationResponse.self, from: data)
    }
    
    // MARK: - list Delegations for a space
    func listDelegations(spaceDid: String) async throws -> [String] {
        guard let sessionData = sessionManager.loadSession() else {
            throw StorachaAPIError.authenticationFailed("No active session")
        }
        
        guard let url = URL(string: "\(baseURL)/delegations/list?spaceDid=\(spaceDid)") else {
            throw StorachaAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(sessionData.sessionId, forHTTPHeaderField: "x-session-id")
        
        let (data, response) = try await session.data(for: request)
        
        if let rawResponse = String(data: data, encoding: .utf8) {
            print("List Delegations Raw API Response: \(rawResponse)")
        }
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            try handleHTTPError(statusCode: httpResponse.statusCode, data: data)
        }
        
        let decoded = try JSONDecoder().decode(StorachaDelegationListResponse.self, from: data)
        return decoded.users
    }
    
    // MARK: -  Revoke DID access
    func revokeDelegation(userDid: String, spaceDid: String) async throws -> StorachaRevokeResponse {
        guard let sessionData = sessionManager.loadSession() else {
            throw StorachaAPIError.authenticationFailed("No active session")
        }
        
        guard let url = URL(string: "\(baseURL)/delegations/revoke") else {
            throw StorachaAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(sessionData.sessionId, forHTTPHeaderField: "x-session-id")
        
        let body: [String: String] = ["userDid": userDid, "spaceDid": spaceDid]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await session.data(for: request)
        
        if let rawResponse = String(data: data, encoding: .utf8) {
            print("Revoke Delegation Raw API Response: \(rawResponse)")
        }
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            try handleHTTPError(statusCode: httpResponse.statusCode, data: data)
        }
        
        return try JSONDecoder().decode(StorachaRevokeResponse.self, from: data)
    }
    
    // MARK: - list uploads
    func listUploads(
        spaceDid: String,
        cursor: String? = nil,
        isAdmin: Bool,
        size: Int = 25
    ) async throws -> StorachaUploadsResponse {
        
        // Load or generate DID
        let keyPair: DIDKeyManager.DIDKeyPair
        do {
            keyPair = try keyManager.loadKeyPair()
        } catch {
            let generated = keyManager.generateKeyPair()
            try keyManager.saveKeyPair(generated)
            keyPair = generated
        }
        
        // Build URL with query params
        var components = URLComponents(string: "\(baseURL)/uploads")!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "spaceDid", value: spaceDid),
            URLQueryItem(name: "size", value: "\(size)")
        ]
        if let cursor = cursor {
            queryItems.append(URLQueryItem(name: "cursor", value: cursor))
        }
        components.queryItems = queryItems
        
        guard let url = components.url else {
            throw StorachaAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        
        // Required DID header
        request.setValue(keyPair.did, forHTTPHeaderField: "x-user-did")
    
        if isAdmin {
            if let sessionData = sessionManager.loadSession() {
                request.setValue(sessionData.sessionId, forHTTPHeaderField: "x-session-id")
            }
        }
        
        let (data, response) = try await session.data(for: request)
        
        if let rawResponse = String(data: data, encoding: .utf8) {
            print("List Uploads Raw API Response: \(rawResponse)")
        }
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            try handleHTTPError(statusCode: httpResponse.statusCode, data: data)
        }
        
        return try JSONDecoder().decode(StorachaUploadsResponse.self, from: data)
    }
    
    // MARK: - Get account usage
    func getAccountUsage() async throws -> StorachaAccountUsageResponse {
        guard let sessionData = sessionManager.loadSession() else {
            throw StorachaAPIError.authenticationFailed("No active session")
        }
        
        guard let url = URL(string: "\(baseURL)/spaces/account-usage") else {
            throw StorachaAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue(sessionData.sessionId, forHTTPHeaderField: "x-session-id")

        let (data, response) = try await session.data(for: request)

        if let rawResponse = String(data: data, encoding: .utf8) {
            print("Get Account Usage Raw API Response: \(rawResponse)")
        }

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            try handleHTTPError(statusCode: httpResponse.statusCode, data: data)
        }

        return try JSONDecoder().decode(StorachaAccountUsageResponse.self, from: data)
    }
    
    // MARK: - Generate bridge Tokens
    func generateBridgeTokens(spaceDid: String, userDid: String?, sessionId: String?, isAdmin: Bool) async throws -> BridgeTokens {
        // Generate expiration timestamp (1 hour from now)
        let currentTimeSeconds = Int64(Date().timeIntervalSince1970)
        let expirationMillis = (currentTimeSeconds * 1000) + (60 * 60 * 1000) // 1 hour from now
        
        logger.info("Token expiration: \(expirationMillis) (current: \(Date().timeIntervalSince1970 * 1000))")
        
        let request = BridgeTokenRequest(
            resource: spaceDid,
            can: ["store/add", "upload/add"],
            expiration: expirationMillis,
            json: false
        )
        
        guard let url = URL(string: "\(baseURL)/bridge-tokens") else {
            throw StorachaAPIError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let userDid = userDid {
            urlRequest.setValue(userDid, forHTTPHeaderField: "x-user-did")
        }
        if isAdmin {
            if let sessionId = sessionId {
                urlRequest.setValue(sessionId, forHTTPHeaderField: "x-session-id")
            }
        }
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        let (data, response) = try await session.data(for: urlRequest)
        
        if let rawResponse = String(data: data, encoding: .utf8) {
            print("Generate Bridge Tokens Raw API Response: \(rawResponse)")
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BridgeUploadError.networkError("Invalid response")
        }
        
        if httpResponse.statusCode == 401 {
            throw StorachaAPIError.unauthorized
        }
        
        if httpResponse.statusCode != 200 {
            let responseBody = String(data: data, encoding: .utf8) ?? "No response body"
            logger.error("Failed to generate tokens - Status: \(httpResponse.statusCode), Body: \(responseBody)")
            throw BridgeUploadError.networkError("Failed to generate tokens: \(httpResponse.statusCode)")
        }
        
        let tokenResponse = try JSONDecoder().decode(BridgeTokenResponse.self, from: data)
        
        logger.info("Token response received: \(tokenResponse.success)")
        logger.info("X-Auth-Secret length: \(tokenResponse.tokens.xAuthSecret.count)")
        logger.info("Authorization length: \(tokenResponse.tokens.authorization.count)")
        logger.info("Generated tokens successfully")
        
        return tokenResponse.tokens
    }
}
