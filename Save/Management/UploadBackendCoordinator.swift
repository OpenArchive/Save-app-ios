//
//  UploadBackendCoordinator.swift
//  Save
//
//  Copyright © 2025 Open Archive. All rights reserved.
//

import Foundation
import Regex

/// Background + foreground sessions used by IA coordinator hooks.
struct UploadSessions {
    let background: URLSession
    let foreground: URLSession
}

/// Result of IA-specific task completion handling.
enum UploadCompletionAction {
    /// Sidecar / irrelevant task — do nothing.
    case ignore
    /// IA main succeeded and meta is still uploading — do not call `done` yet.
    case wait
    /// Finish the upload job.
    case done(uploadId: String, error: Error?, url: URL?)
}

/// What to do after IA success bookkeeping.
enum UploadAfterSuccessAction {
    case continueImmediately
    case continueAfterDelay(TimeInterval)
}

/// Shared helpers used by IA task matching (WebDAV keeps its own copies in UploadManager).
enum UploadBackendTaskHelpers {

    static func filename(of task: URLSessionUploadTask) -> String? {
        guard let name = task.originalRequest?.url?.lastPathComponent else { return nil }
        return name.removingPercentEncoding ?? name
    }

    static func isMainAssetBackgroundUploadTask(_ task: URLSessionTask) -> Bool {
        guard task is URLSessionUploadTask,
              let filename = task.originalRequest?.url?.lastPathComponent
        else {
            return false
        }

        if filename =~ "\\d{15}-\\d{15}" {
            return false
        }

        for file in Asset.Files.allCases where !file.isInternal {
            if filename =~ "\(file.rawValue)$" {
                return false
            }
        }

        return true
    }

    static func isChunkFilename(_ filename: String) -> Bool {
        filename =~ "\\d{15}-\\d{15}"
    }

    static func isProofOrSidecarFilename(_ filename: String) -> Bool {
        for file in Asset.Files.allCases where !file.isInternal {
            if filename =~ "\(file.rawValue)$" {
                return true
            }
        }
        return false
    }
}

/// IA-only entry point. WebDAV stays inline in UploadManager (known-good path).
enum UploadBackendRouter {
    static let ia = IaUploadCoordinator()
}
