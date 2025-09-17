//
//  StorachaUploadModels.swift
//  Save
//
//  Created by navoda on 2025-09-18.
//  Copyright © 2025 Open Archive. All rights reserved.
//


// MARK: - Upload Error Types
enum StorachaUploadError: LocalizedError {
    case fileAccessError(String)
    case fileProcessingError(String)
    case invalidCid(String)
    case networkError(String)
    case bridgeError(String)
    case tokenExpired(String)
    case s3UploadFailed(String)
    case parseError(String)
    
    var errorDescription: String? {
        switch self {
        case .fileAccessError(let message):
            return "File access error: \(message)"
        case .fileProcessingError(let message):
            return "File processing error: \(message)"
        case .invalidCid(let message):
            return "Invalid CID: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .bridgeError(let message):
            return "Bridge error: \(message)"
        case .tokenExpired(let message):
            return "Token expired: \(message)"
        case .s3UploadFailed(let message):
            return "S3 upload failed: \(message)"
        case .parseError(let message):
            return "Parse error: \(message)"
        }
    }
}

// MARK: - Error Types
enum BridgeUploadError: LocalizedError {
    case invalidCid(String)
    case networkError(String)
    case parseError(String)
    case bridgeError(String)
    case tokenExpired(String)
    case s3UploadFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidCid(let message):
            return "Invalid CID: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .parseError(let message):
            return "Parse error: \(message)"
        case .bridgeError(let message):
            return "Bridge error: \(message)"
        case .tokenExpired(let message):
            return "Token expired: \(message)"
        case .s3UploadFailed(let message):
            return "S3 upload failed: \(message)"
        }
    }
}

// MARK: - Upload Response Model
struct UploadResponse: Equatable {
    let success: Bool
    let cid: String
    let size: Int
}
struct BridgeUploadResult {
    let rootCid: String
    let carCid: String
    let size: Int
}

// MARK: - API Models
struct BridgeTokenRequest: Codable {
    let resource: String
    let can: [String]
    let expiration: Int64
    let json: Bool
}

struct BridgeTokenResponse: Codable {
    let tokens: BridgeTokens
    let success:Bool
}

struct BridgeTokens: Codable {
    let xAuthSecret: String
    let authorization: String
}

struct BridgeTaskRequest: Codable {
    let tasks: [[TaskElement]]
}

enum TaskElement: Codable {
    case string(String)
    case storeTask(StoreAddTask)
    case uploadTask(UploadAddTask)
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let storeTask = try? container.decode(StoreAddTask.self) {
            self = .storeTask(storeTask)
        } else if let uploadTask = try? container.decode(UploadAddTask.self) {
            self = .uploadTask(uploadTask)
        } else {
            throw DecodingError.typeMismatch(TaskElement.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid task element"))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let string):
            try container.encode(string)
        case .storeTask(let task):
            try container.encode(task)
        case .uploadTask(let task):
            try container.encode(task)
        }
    }
}

struct StoreAddTask: Codable {
    let link: [String: String]
    let size: Int
}

struct UploadAddTask: Codable {
    let root: [String: String]
}

struct StoreAddResponse: Codable {
    let p: StoreAddResponseP
}

struct StoreAddResponseP: Codable {
    let out: StoreAddOut
}

struct StoreAddOut: Codable {
    let ok: StoreAddSuccess?
    let error: AnyCodable?
}

struct StoreAddSuccess: Codable {
    let status: String
    let url: String?
    let headers: [String: String]?
}

struct UploadAddResponse: Codable {
    let p: UploadAddResponseP
}

struct UploadAddResponseP: Codable {
    let out: UploadAddOut
}

struct UploadAddOut: Codable {
    let ok: UploadAddSuccess?
    let error: AnyCodable?
}

struct UploadAddSuccess: Codable {
    let root: [String: String]
}

struct AnyCodable: Codable {
    let value: Any
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            throw DecodingError.typeMismatch(AnyCodable.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Cannot decode"))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode("Error occurred") // Simplified error representation
    }
}
