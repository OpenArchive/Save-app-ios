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

// MARK: - API Models
struct StorachaLoginRequest: Codable {
    let email: String
    let did: String
}

struct StorachaLoginResponse: Codable {
    let message: String
    let sessionId: String
    let did: String
    let verified: Bool
    let challenge: String?
    let challengeId: String?
}

struct StorachaVerifyRequest: Codable {
    let did: String
    let challengeId: String
    let signature: String
    let sessionId: String
    let email: String
}

struct StorachaVerifyResponse: Codable {
    let sessionId: String
    let did: String
    let message: String
}

struct StorachaSessionResponse: Codable {
    let valid: Bool
    let verified: Int
    let expiresAt: String?
    let message: String
}

struct StorachaSpace: Codable, Identifiable {
    let did: String
    let name: String
    let isAdmin: Bool
    
    var id: String { did }
}

struct StorachaUploadResponse: Codable {
    let success: Bool
    let cid: String
    let size: Int
}

struct StorachaUsageResponse: Codable {
    let spaceDid: String
    let usage: StorachaUsageDetail
}

struct StorachaUsageDetail: Codable {
    let bytes: Int
    let mb: Double
    let human: String
}

struct StorachaDelegationRequest: Codable {
    let userDid: String
    let spaceDid: String
    let expiresIn: Int
}

struct StorachaDelegationResponse: Codable {
    let message: String
    let principalDid: String
    let delegationCid: String
    let expiresAt: String
    let createdBy: String
}

// MARK: - API Errors
enum StorachaAPIError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError(Error)
    case networkError(Error)
    case authenticationFailed(String)
    case invalidDID
    case signatureGenerationFailed
    case sessionExpired
    case insufficientPermissions
    case uploadFailed(String)
    case serverError(Int, String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No data received"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .authenticationFailed(let message):
            return "Authentication failed: \(message)"
        case .invalidDID:
            return "Invalid DID format"
        case .signatureGenerationFailed:
            return "Failed to generate signature"
        case .sessionExpired:
            return "Session has expired"
        case .insufficientPermissions:
            return "Insufficient permissions for this operation"
        case .uploadFailed(let message):
            return "Upload failed: \(message)"
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message)"
        }
    }
}

// MARK: - Main API Service
class StorachaAPIService {
    static let shared = StorachaAPIService()
    
    private let baseURL: String
    private let session = URLSession.shared
    private let keyManager = DIDKeyManager()
    private let sessionManager = SessionManager.shared
    
    private init(baseURL: String = "http://192.168.0.104:3000") {
        self.baseURL = baseURL
    }
    
    // MARK: - Configuration
    func configure(baseURL: String) {
        // You can add a method to reconfigure if needed
    }
    
    // MARK: - Authentication Methods
    func login(email: String) async throws -> StorachaSessionData {
        // Generate or load existing key pair
        let keyPair: DIDKeyManager.DIDKeyPair
        do {
            keyPair = try keyManager.loadKeyPair(for: email)
        } catch {
            keyPair = keyManager.generateKeyPair()
            try keyManager.saveKeyPair(keyPair, for: email)
        }
        
        // Step 1: Initiate login
        let loginResponse = try await initiateLogin(email: email, did: keyPair.did)
        
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
        
        // Return unverified session (verification happens via email)
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
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw StorachaAPIError.serverError(httpResponse.statusCode, errorMessage)
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
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw StorachaAPIError.serverError(httpResponse.statusCode, errorMessage)
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
            // Log the error response
            if let errorString = String(data: data, encoding: .utf8) {
                print("HTTP Error \(httpResponse.statusCode): \(errorString)")
            }
            return nil
        }

        // Log the raw response data before decoding
        if let rawResponse = String(data: data, encoding: .utf8) {
            print("Raw API Response: \(rawResponse)")
        } else {
            print("Failed to convert response data to string")
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
        
        _ = try await session.data(for: request)
        sessionManager.clearSession()
    }
    
    // MARK: - Space Management
    func getSpaces() async throws -> [StorachaSpace] {
        guard let sessionData = sessionManager.loadSession() else {
            throw StorachaAPIError.authenticationFailed("No active session")
        }
        
        guard let url = URL(string: "\(baseURL)/spaces") else {
            throw StorachaAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue(sessionData.sessionId, forHTTPHeaderField: "x-session-id")
        
        let (data, response) = try await session.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw StorachaAPIError.serverError(httpResponse.statusCode, errorMessage)
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
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw StorachaAPIError.serverError(httpResponse.statusCode, errorMessage)
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
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw StorachaAPIError.uploadFailed(errorMessage)
        }
        
        return try JSONDecoder().decode(StorachaUploadResponse.self, from: data)
    }
    
    // MARK: - Delegation Management
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
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw StorachaAPIError.serverError(httpResponse.statusCode, errorMessage)
        }
        
        return try JSONDecoder().decode(StorachaDelegationResponse.self, from: data)
    }
}
