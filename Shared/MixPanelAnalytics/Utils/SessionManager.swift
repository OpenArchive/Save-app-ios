//
//  SessionManager.swift
//  Save
//
//  Created by navoda on 2025-12-12.
//  Copyright © 2025 Open Archive. All rights reserved.
//


//
//  SessionManager.swift
//  SaveAnalytics
//
//  Manages analytics session tracking
//

import Foundation

public class SessionManager {

    public static let shared = SessionManager()

    // MARK: - Properties

    // Serial queue for thread-safe access to all mutable state
    private let queue = DispatchQueue(label: "com.openarchive.sessionmanager", qos: .utility)

    private let defaults = UserDefaults.standard

    // Session tracking (accessed only through queue)
    private var sessionStartTime: Date?
    private var _currentScreen: String = ""
    private var _previousScreen: String = ""

    // Upload tracking (accessed only through queue)
    private var _sessionUploadsCompleted: Int = 0
    private var _sessionUploadsFailed: Int = 0

    // Public computed properties for thread-safe access
    public var currentScreen: String {
        queue.sync { _currentScreen }
    }

    public var sessionUploadsCompleted: Int {
        queue.sync { _sessionUploadsCompleted }
    }

    public var sessionUploadsFailed: Int {
        queue.sync { _sessionUploadsFailed }
    }

    // Session metadata - all UserDefaults access through queue
    private var sessionNumber: Int {
        get {
            queue.sync {
                defaults.integer(forKey: "analytics_session_number")
            }
        }
        set {
            queue.async { [weak self] in
                self?.defaults.set(newValue, forKey: "analytics_session_number")
            }
        }
    }

    private var totalSessions: Int {
        get {
            queue.sync {
                defaults.integer(forKey: "analytics_total_sessions")
            }
        }
        set {
            queue.async { [weak self] in
                self?.defaults.set(newValue, forKey: "analytics_total_sessions")
            }
        }
    }

    private var isFirstSession: Bool {
        return totalSessions == 0
    }

    // MARK: - Initialization

    private init() {}

    // MARK: - Session Management

    public func startSession() {
        queue.async { [weak self] in
            guard let self = self else { return }

            self.sessionStartTime = Date()

            // Atomic increment of session numbers
            let currentSession = self.defaults.integer(forKey: "analytics_session_number")
            self.defaults.set(currentSession + 1, forKey: "analytics_session_number")

            let totalSessions = self.defaults.integer(forKey: "analytics_total_sessions")
            self.defaults.set(totalSessions + 1, forKey: "analytics_total_sessions")

            // Reset session upload counters
            self._sessionUploadsCompleted = 0
            self._sessionUploadsFailed = 0

        }
    }

    public func endSession() -> TimeInterval {
        return queue.sync { [weak self] in
            guard let self = self else { return 0 }
            guard let startTime = self.sessionStartTime else {
                return 0
            }

            let duration = Date().timeIntervalSince(startTime)
            self.sessionStartTime = nil

            return duration
        }
    }

    public func getSessionDuration() -> TimeInterval {
        return queue.sync { [weak self] in
            guard let self = self else { return 0 }
            guard let startTime = self.sessionStartTime else {
                return 0
            }
            return Date().timeIntervalSince(startTime)
        }
    }

    public func getSessionNumber() -> Int {
        return queue.sync { [weak self] in
            guard let self = self else { return 0 }
            return self.defaults.integer(forKey: "analytics_session_number")
        }
    }

    public func isFirstSessionEver() -> Bool {
        return queue.sync { [weak self] in
            guard let self = self else { return false }
            let total = self.defaults.integer(forKey: "analytics_total_sessions")
            return total == 0
        }
    }

    // MARK: - Screen Tracking

    public func setCurrentScreen(_ screen: String) {
        queue.async { [weak self] in
            guard let self = self else { return }
            self._previousScreen = self._currentScreen
            self._currentScreen = screen
        }
    }

    public func getPreviousScreen() -> String? {
        return queue.sync { [weak self] in
            guard let self = self else { return nil }
            return self._previousScreen.isEmpty ? nil : self._previousScreen
        }
    }

    public func getLastScreen() -> String {
        return queue.sync { [weak self] in
            guard let self = self else { return "unknown" }
            return self._currentScreen.isEmpty ? "unknown" : self._currentScreen
        }
    }

    // MARK: - Upload Tracking

    public func incrementUploadsCompleted() {
        queue.async { [weak self] in
            guard let self = self else { return }
            self._sessionUploadsCompleted += 1
        }
    }

    public func incrementUploadsFailed() {
        queue.async { [weak self] in
            guard let self = self else { return }
            self._sessionUploadsFailed += 1
        }
    }

    public func resetUploadCounters() {
        queue.async { [weak self] in
            guard let self = self else { return }
            self._sessionUploadsCompleted = 0
            self._sessionUploadsFailed = 0
        }
    }

    // MARK: - Reset

    public func reset() {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.sessionStartTime = nil
            self._currentScreen = ""
            self._previousScreen = ""
            self._sessionUploadsCompleted = 0
            self._sessionUploadsFailed = 0
           
        }
    }
}
