//
//  AnalyticsEventType.swift
//  Save
//
//  Created by navoda on 2025-12-12.
//  Copyright © 2025 Open Archive. All rights reserved.
//


//
//  AnalyticsEvent.swift
//  SaveAnalytics
//
//  Analytics event definitions for tracking user behavior
//  100% GDPR-compliant - No PII tracking
//

import Foundation

/// Protocol defining common properties for all analytics events
public protocol AnalyticsEventType {
    var eventName: String { get }
    var properties: [String: Any] { get }
}

/// Enumeration of all analytics events tracked in the app
public enum AnalyticsEvent: AnalyticsEventType {

    // MARK: - App Lifecycle Events

    case appOpened(isFirstLaunch: Bool, appVersion: String)
    case appClosed(sessionDuration: TimeInterval)
    case appBackgrounded
    case appForegrounded

    // MARK: - Session Events

    case sessionStarted(isFirstSession: Bool, sessionNumber: Int)
    case sessionEnded(lastScreen: String, duration: TimeInterval, uploadsCompleted: Int, uploadsFailed: Int)

    // MARK: - Screen Tracking

    case screenViewed(screenName: String, timeSpent: TimeInterval?, previousScreen: String?)
    case navigationAction(fromScreen: String, toScreen: String, trigger: String)

    // MARK: - Backend Events

    case backendConfigured(backendType: String, isNew: Bool)
    case backendUpdated(backendType: String)
    case backendRemoved(backendType: String, reason: String)

    // MARK: - Upload Events

    case uploadStarted(backendType: String, fileType: String, fileSizeKB: Int, fileSizeCategory: String)
    case uploadCompleted(backendType: String, fileType: String, fileSizeKB: Int, durationSeconds: TimeInterval, uploadSpeedKbps: Double)
    case uploadFailed(backendType: String, fileType: String, errorCategory: String, fileSizeKB: Int)
    case uploadSessionStarted(count: Int, totalSizeMB: Double)
    case uploadSessionCompleted(count: Int, successCount: Int, failedCount: Int, durationSeconds: TimeInterval, successRate: Double)
    case uploadCancelled(backendType: String, fileType: String, reason: String)
    case uploadNetworkError(reason: String)

    // MARK: - Media Events

    case mediaCaptured(mediaType: String, source: String)
    case mediaSelected(count: Int, source: String, mediaTypes: [String])
    case mediaDeleted(count: Int)

    // MARK: - Feature Usage Events

    case featureToggled(featureName: String, enabled: Bool)

    // MARK: - Review Events

    case reviewPromptShown
    case reviewPromptCompleted
    case reviewPromptError(errorCode: Int)

    // MARK: - Error Events

    case errorOccurred(errorCategory: String, screenName: String?, backendType: String?)

    // MARK: - AnalyticsEventType Implementation

    public var eventName: String {
        switch self {
        // App Lifecycle
        case .appOpened: return "app_opened"
        case .appClosed: return "app_closed"
        case .appBackgrounded: return "app_backgrounded"
        case .appForegrounded: return "app_foregrounded"

        // Session
        case .sessionStarted: return "session_started"
        case .sessionEnded: return "session_ended"

        // Screen Tracking
        case .screenViewed: return "screen_viewed"
        case .navigationAction: return "navigation_action"

        // Backend
        case .backendConfigured: return "backend_configured"
        case .backendUpdated: return "backend_updated"
        case .backendRemoved: return "backend_removed"

        // Upload
        case .uploadStarted: return "upload_started"
        case .uploadCompleted: return "upload_completed"
        case .uploadFailed: return "upload_failed"
        case .uploadSessionStarted: return "upload_session_started"
        case .uploadSessionCompleted: return "upload_session_completed"
        case .uploadCancelled: return "upload_cancelled"
        case .uploadNetworkError: return "upload_network_error"

        // Media
        case .mediaCaptured: return "media_captured"
        case .mediaSelected: return "media_selected"
        case .mediaDeleted: return "media_deleted"

        // Feature Usage
        case .featureToggled: return "feature_toggled"

        // Review
        case .reviewPromptShown: return "review_prompt_shown"
        case .reviewPromptCompleted: return "review_prompt_completed"
        case .reviewPromptError: return "review_prompt_error"

        // Error
        case .errorOccurred: return "error_occurred"
        }
    }

    public var properties: [String: Any] {
        switch self {
        // App Lifecycle
        case .appOpened(let isFirstLaunch, let appVersion):
            return ["is_first_launch": isFirstLaunch, "app_version": appVersion]
        case .appClosed(let sessionDuration):
            return ["session_duration": sessionDuration]
        case .appBackgrounded:
            return [:]
        case .appForegrounded:
            return [:]

        // Session
        case .sessionStarted(let isFirstSession, let sessionNumber):
            return ["is_first_session": isFirstSession, "session_number": sessionNumber]
        case .sessionEnded(let lastScreen, let duration, let uploadsCompleted, let uploadsFailed):
            return [
                "last_screen": lastScreen,
                "duration": duration,
                "uploads_completed": uploadsCompleted,
                "uploads_failed": uploadsFailed
            ]

        // Screen Tracking
        case .screenViewed(let screenName, let timeSpent, let previousScreen):
            var props: [String: Any] = ["screen_name": screenName]
            if let timeSpent = timeSpent { props["time_spent"] = timeSpent }
            if let previousScreen = previousScreen { props["previous_screen"] = previousScreen }
            return props
        case .navigationAction(let fromScreen, let toScreen, let trigger):
            return ["from_screen": fromScreen, "to_screen": toScreen, "trigger": trigger]

        // Backend
        case .backendConfigured(let backendType, let isNew):
            return ["backend_type": backendType, "is_new": isNew]
        case .backendUpdated(let backendType):
            return ["backend_type": backendType]
        case .backendRemoved(let backendType, let reason):
            return ["backend_type": backendType, "reason": reason]

        // Upload
        case .uploadStarted(let backendType, let fileType, let fileSizeKB, let fileSizeCategory):
            return [
                "backend_type": backendType,
                "file_type": fileType,
                "file_size_kb": fileSizeKB,
                "file_size_category": fileSizeCategory
            ]
        case .uploadCompleted(let backendType, let fileType, let fileSizeKB, let durationSeconds, let uploadSpeedKbps):
            return [
                "backend_type": backendType,
                "file_type": fileType,
                "file_size_kb": fileSizeKB,
                "duration_seconds": durationSeconds,
                "upload_speed_kbps": uploadSpeedKbps
            ]
        case .uploadFailed(let backendType, let fileType, let errorCategory, let fileSizeKB):
            return [
                "backend_type": backendType,
                "file_type": fileType,
                "error_category": errorCategory,
                "file_size_kb": fileSizeKB
            ]
        case .uploadSessionStarted(let count, let totalSizeMB):
            return ["count": count, "total_size_mb": totalSizeMB]
        case .uploadSessionCompleted(let count, let successCount, let failedCount, let durationSeconds, let successRate):
            return [
                "count": count,
                "success_count": successCount,
                "failed_count": failedCount,
                "duration_seconds": durationSeconds,
                "success_rate": successRate
            ]
        case .uploadCancelled(let backendType, let fileType, let reason):
            return [
                "backend_type": backendType,
                "file_type": fileType,
                "reason": reason
            ]
        case .uploadNetworkError(let reason):
            return ["reason": reason]

        // Media
        case .mediaCaptured(let mediaType, let source):
            return ["media_type": mediaType, "source": source]
        case .mediaSelected(let count, let source, let mediaTypes):
            return ["count": count, "source": source, "media_types": mediaTypes]
        case .mediaDeleted(let count):
            return ["count": count]

        // Feature Usage
        case .featureToggled(let featureName, let enabled):
            return ["feature_name": featureName, "enabled": enabled]

        // Review
        case .reviewPromptShown:
            return [:]
        case .reviewPromptCompleted:
            return [:]
        case .reviewPromptError(let errorCode):
            return ["error_code": errorCode]

        // Error
        case .errorOccurred(let errorCategory, let screenName, let backendType):
            var props: [String: Any] = ["error_category": errorCategory]
            if let screenName = screenName { props["screen_name"] = screenName }
            if let backendType = backendType { props["backend_type"] = backendType }
            return props
        }
    }
}

// MARK: - Helper Extensions

public extension AnalyticsEvent {
    /// Categorizes file size into buckets for better analytics aggregation
    static func fileSizeCategory(bytes: Int64) -> String {
        let mb = Double(bytes) / (1024 * 1024)
        switch mb {
        case ..<1: return "small"
        case 1..<10: return "medium"
        case 10..<100: return "large"
        default: return "very_large"
        }
    }

    /// Converts file extension to media type
    static func mediaType(from url: URL?) -> String {
        let ext = url?.pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg", "png", "heic", "gif", "bmp", "webp":
            return "image"
        case "mp4", "mov", "avi", "mkv", "m4v", "3gp":
            return "video"
        case "mp3", "m4a", "wav", "aac", "flac":
            return "audio"
        case "pdf":
            return "pdf"
        case "txt", "doc", "docx":
            return "document"
        default:
            return "other"
        }
    }
}
