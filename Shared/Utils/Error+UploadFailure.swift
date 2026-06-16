//
//  Error+UploadFailure.swift
//  Save
//
//  Copyright © 2025 Open Archive. All rights reserved.
//

import Foundation

enum UploadFailureKind {
    case duplicateExists
    case ia503
    case serverError
    case timeout
    case connectivity
    case other
}

struct UploadTimeoutError: Error, LocalizedError {
    var errorDescription: String? {
        NSLocalizedString("Upload timed out.", comment: "")
    }
}

extension Error {

    func uploadFailureKind(for space: Space?) -> UploadFailureKind {
        if let saveError = self as? SaveError,
           case .http(let status) = saveError,
           status == 409 || status == 412 {
            return .duplicateExists
        }

        if let saveError = self as? SaveError,
           case .http(503) = saveError,
           space is IaSpace {
            return .ia503
        }

        if let saveError = self as? SaveError,
           case .http(let status) = saveError,
           (500...599).contains(status) {
            return .serverError
        }

        if self is UploadTimeoutError {
            return .timeout
        }

        let ns = self as NSError
        if ns.domain == NSURLErrorDomain,
           ns.code == URLError.timedOut.rawValue {
            return .timeout
        }

        if isLikelyConnectivityFailure {
            return .connectivity
        }

        return .other
    }

    func duplicateSuccessURL(fallback: URL?) -> URL? {
        fallback
    }
}
