//
//  StorachaUser.swift
//  Save
//
//  Created by navoda on 2026-03-06.
//  Copyright © 2026 Open Archive. All rights reserved.
//


// MARK: - Supporting Models
struct StorachaUser {
    let did: String
    let email: String
    let sessionId: String
}

struct StorachaUpload: Identifiable {
    let id = UUID()
    let cid: String
    let fileName: String
    let size: Int
    let uploadDate: Date
    let gatewayUrl: String
}

enum StorachaError: Error, LocalizedError {
    case authenticationFailed(String)
    case networkError(Error)
    case uploadFailed(String)
    case insufficientPermissions
    case sessionExpired
    case unknownError(String)
    
    var errorDescription: String? {
        switch self {
        case .authenticationFailed(let message):
            return message
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .uploadFailed(let message):
            return "Upload failed: \(message)"
        case .insufficientPermissions:
            return "Insufficient permissions"
        case .sessionExpired:
            return "Session has expired"
        case .unknownError(let message):
            return "Unknown error: \(message)"
        }
    }
}
