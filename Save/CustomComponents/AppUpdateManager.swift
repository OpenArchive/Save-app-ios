//
//  AppUpdateManager.swift
//  Save
//
//  Created by navoda on 2025-10-22.
//  Copyright © 2025 Open Archive. All rights reserved.
//

import UIKit
import StoreKit

class AppUpdateManager {
    
    static let shared = AppUpdateManager()
    
    private let cacheKey = "com.app.versionCache"
    private let lastPromptDateKey = "com.app.lastUpdatePrompt"
    private let canceledVersionKey = "com.app.canceledVersion"
    private let userDefaults = UserDefaults.standard
    
    // Configuration
    private let cacheExpirationHours: TimeInterval = 3 // Hours
    private let checkTimeoutInterval: TimeInterval = 10 // Seconds
    private let retryAfterFailureMinutes: TimeInterval = 30 // Minutes
    
    private var isCheckingUpdate = false
    private var updateAlertController: UIAlertController?
    
    private init() {}
    
    // MARK: - Public Methods
    
    func checkForUpdateIfNeeded(forced: Bool = false) {
        
        guard !isCheckingUpdate else { return }
        
        if !forced, let cachedInfo = getCachedVersionInfo(), !cachedInfo.isExpired {
            handleVersionCheck(appStoreVersion: cachedInfo.appStoreVersion,
                               trackId: cachedInfo.trackId,
                               trackViewUrl: cachedInfo.trackViewUrl,
                               releaseNotes: cachedInfo.releaseNotes)
            return
        }
        
        performUpdateCheck()
    }
    
    // MARK: - Private Methods
    
    private func performUpdateCheck() {
        isCheckingUpdate = true
        
        guard let bundleId = Bundle.main.bundleIdentifier else {
            isCheckingUpdate = false
            return
        }
        
        let urlString = "https://itunes.apple.com/lookup?bundleId=\(bundleId)"
        
        guard let url = URL(string: urlString) else {
            isCheckingUpdate = false
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = checkTimeoutInterval
        request.cachePolicy = .reloadIgnoringLocalCacheData
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            defer {
                DispatchQueue.main.async {
                    self?.isCheckingUpdate = false
                }
            }
            
            // Handle network errors - FALLBACK: Allow user to continue
            if let error = error {
                print("Update check failed: \(error.localizedDescription)")
                self?.handleNetworkFailure()
                return
            }
            
            guard let data = data else {
                self?.handleNetworkFailure()
                return
            }
            
            do {
                let appStoreResponse = try JSONDecoder().decode(AppStoreResponse.self, from: data)
                
                if let appStoreApp = appStoreResponse.results.first {
                    // Cache the result
                    self?.cacheVersionInfo(appStoreApp)
                    
                    // Check if update is needed
                    DispatchQueue.main.async {
                        self?.handleVersionCheck(appStoreVersion: appStoreApp.version,
                                                 trackId: appStoreApp.trackId,
                                                 trackViewUrl: appStoreApp.trackViewUrl,
                                                 releaseNotes: appStoreApp.releaseNotes)
                    }
                } else {
                    self?.handleNetworkFailure()
                }
            } catch {
                print("Failed to decode App Store response: \(error)")
                self?.handleNetworkFailure()
            }
        }
        
        task.resume()
    }
    
    private func handleVersionCheck(appStoreVersion: String, trackId: Int, trackViewUrl: String, releaseNotes: String?) {
        guard let currentVersion = getCurrentAppVersion() else { return }
        
        if isVersionOlder(currentVersion: currentVersion, appStoreVersion: appStoreVersion) {
            // Check if user already canceled this version
            if shouldSkipVersion(appStoreVersion) {
                print("Skipping update alert for version \(appStoreVersion) - user canceled")
                return
            }
            
            showUpdateAlert(appStoreVersion: appStoreVersion,
                            trackId: trackId,
                            trackViewUrl: trackViewUrl,
                            releaseNotes: releaseNotes)
        }
    }
    
    private func handleNetworkFailure() {
        // FALLBACK: Check if we have cached data that's not too old (within 24 hours)
        if let cachedInfo = getCachedVersionInfo() {
            let twentyFourHours: TimeInterval = 24 * 60 * 60
            if Date().timeIntervalSince(cachedInfo.lastChecked) < twentyFourHours {
                // Use cached data even if expired for normal cache duration
                DispatchQueue.main.async {
                    self.handleVersionCheck(appStoreVersion: cachedInfo.appStoreVersion,
                                            trackId: cachedInfo.trackId,
                                            trackViewUrl: cachedInfo.trackViewUrl,
                                            releaseNotes: cachedInfo.releaseNotes)
                }
                return
            }
        }
        
        // FALLBACK: Allow user to continue using the app
        print("Update check failed and no valid cache. Allowing user to continue.")
    }
    
    private func isVersionOlder(currentVersion: String, appStoreVersion: String) -> Bool {
        return currentVersion.compare(appStoreVersion, options: .numeric) == .orderedAscending
    }
    
    private func getCurrentAppVersion() -> String? {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }
    
    // MARK: - Cancel Management
    
    private func shouldSkipVersion(_ version: String) -> Bool {
        // Simply check if this version was canceled - no expiration
        guard let canceledVersion = userDefaults.string(forKey: canceledVersionKey),
              canceledVersion == version else {
            return false
        }
        
        return true
    }
    
    private func setCanceledVersion(_ version: String) {
        userDefaults.set(version, forKey: canceledVersionKey)
    }
    
    private func clearCanceledVersion() {
        userDefaults.removeObject(forKey: canceledVersionKey)
    }
    
    // MARK: - Cache Management
    
    private func cacheVersionInfo(_ appStoreApp: AppStoreApp) {
        let cachedInfo = CachedVersionInfo(
            appStoreVersion: appStoreApp.version,
            trackId: appStoreApp.trackId,
            trackViewUrl: appStoreApp.trackViewUrl,
            releaseNotes: appStoreApp.releaseNotes,
            lastChecked: Date()
        )
        
        if let encoded = try? JSONEncoder().encode(cachedInfo) {
            userDefaults.set(encoded, forKey: cacheKey)
        }
    }
    
    private func getCachedVersionInfo() -> CachedVersionInfo? {
        guard let data = userDefaults.data(forKey: cacheKey),
              let cachedInfo = try? JSONDecoder().decode(CachedVersionInfo.self, from: data) else {
            return nil
        }
        return cachedInfo
    }
    
    func clearCache() {
        userDefaults.removeObject(forKey: cacheKey)
        userDefaults.removeObject(forKey: lastPromptDateKey)
        clearCanceledVersion()
    }
    
    // MARK: - UI Presentation
    
    private func showUpdateAlert(appStoreVersion: String, trackId: Int, trackViewUrl: String, releaseNotes: String?) {
        // Dismiss any existing alert
        updateAlertController?.dismiss(animated: false)
        
        guard let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow })
                ?? UIApplication.shared.windows.first,
              let rootViewController = window.rootViewController else {
            print("Could not find window or root view controller")
            return
        }
        
        let topController = getTopViewController(from: rootViewController)
        
        // Create alert
        let alert = UIAlertController(
            title: "Update Available",
            message: createUpdateMessage(newVersion: appStoreVersion, releaseNotes: releaseNotes),
            preferredStyle: .alert
        )
        
        // Update Now Action
        let updateAction = UIAlertAction(title: "Update Now", style: .default) { [weak self] _ in
            self?.clearCanceledVersion() // Clear any canceled version when user chooses to update
            self?.openAppStore(trackId: trackId, trackViewUrl: trackViewUrl)
            
            // Check again after user returns
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                // Force check (ignore cache) when returning from App Store
                self?.checkForUpdateIfNeeded(forced: true)
            }
        }
        
        // Later Action (Cancel)
        let laterAction = UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            // Store this version as canceled - will never show again
            self?.setCanceledVersion(appStoreVersion)
            print("User canceled update for version \(appStoreVersion) - will not show again")
        }
        
        alert.addAction(updateAction)
        alert.addAction(laterAction)
        alert.preferredAction = updateAction
        
        updateAlertController = alert
        topController.present(alert, animated: true)
    }
    
    private func createUpdateMessage(newVersion: String, releaseNotes: String?) -> String {
        let message = "Version \(newVersion) is now available. Please update to get the latest features and improvements."
        
        return message
    }
    
    private func openAppStore(trackId: Int, trackViewUrl: String) {
        // Try to open App Store app directly
        if let appStoreURL = URL(string: "itms-apps://itunes.apple.com/app/id\(trackId)") {
            if UIApplication.shared.canOpenURL(appStoreURL) {
                UIApplication.shared.open(appStoreURL)
                return
            }
        }
        
        // Fallback to web URL
        if let webURL = URL(string: trackViewUrl) {
            UIApplication.shared.open(webURL)
        }
    }
    
    private func getTopViewController(from rootVC: UIViewController) -> UIViewController {
        if let presented = rootVC.presentedViewController {
            return getTopViewController(from: presented)
        }
        
        if let nav = rootVC as? UINavigationController,
           let visible = nav.visibleViewController {
            return getTopViewController(from: visible)
        }
        
        if let tab = rootVC as? UITabBarController,
           let selected = tab.selectedViewController {
            return getTopViewController(from: selected)
        }
        
        return rootVC
    }
}

// MARK: - Data Models

struct AppStoreResponse: Codable {
    let resultCount: Int
    let results: [AppStoreApp]
}

struct AppStoreApp: Codable {
    let version: String
    let trackId: Int
    let trackViewUrl: String
    let releaseNotes: String?
    let currentVersionReleaseDate: String?
    let minimumOsVersion: String?
}

struct CachedVersionInfo: Codable {
    let appStoreVersion: String
    let trackId: Int
    let trackViewUrl: String
    let releaseNotes: String?
    let lastChecked: Date
    
    var isExpired: Bool {
        let expirationInterval: TimeInterval = 3 * 60 * 60 // 3 hours in seconds
        return Date().timeIntervalSince(lastChecked) > expirationInterval
    }
}

// MARK: - Configuration Extension

extension AppUpdateManager {
    
    struct Configuration {
        let forceUpdate: Bool
        let showLaterButton: Bool
        let cacheExpirationHours: TimeInterval
        let checkOnForeground: Bool
        
        static let `default` = Configuration(
            forceUpdate: true,
            showLaterButton: false,
            cacheExpirationHours: 3,
            checkOnForeground: true
        )
    }
    
    func configure(with configuration: Configuration) {
        
    }
}
