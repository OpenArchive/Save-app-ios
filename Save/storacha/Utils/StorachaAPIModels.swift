//
//  StorachaAPIModels.swift
//  Save
//
//  Created by navoda on 2025-09-18.
//  Copyright © 2025 Open Archive. All rights reserved.
//

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

struct StorachaDelegationListResponse: Codable {
    let spaceDid: String
    let users: [String]
}

struct StorachaUploadItem: Codable, Identifiable {
    let cid: String
    let created: String
    let insertedAt: String
    let updatedAt: String
    let gatewayUrl: String
    
    var id: String { cid }
}

struct StorachaUploadsResponse: Codable {
    let success: Bool
    let userDid: String
    let spaceDid: String
    let uploads: [StorachaUploadItem]
    let count: Int
    let cursor: String?
    let hasMore: Bool
}

struct StorachaRevokeResponse: Codable {
    let message: String
    let userDid: String
    let spaceDid: String
    let revokedCount: Int
}

struct StorachaAccountUsageResponse: Codable {
    let totalUsage: StorachaUsageDetail
    let spaces: [StorachaSpaceUsage]
}

struct StorachaSpaceUsage: Codable, Identifiable {
    let spaceDid: String
    let name: String
    let usage: StorachaUsageDetail

    var id: String { spaceDid }
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
