//
//  AppPreferences.swift
//  Save
//
//  Created by Elelan on 2024/12/4.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import Foundation


/// `AppSettings` class to manage user preferences
class AppSettings {
    
    private static let defaults = UserDefaults.standard
    
    // Keys Enum
    enum Keys: String {
        case passcodeEnabled = "passcode_enabled"
        case didCompleteOnboarding = "did_complete_onboarding"
        case uploadWifiOnly = "upload_wifi_only"
        case nearbyUseBluetooth = "nearby_use_bluetooth"
        case nearbyUseWifi = "nearby_use_wifi"
        case useTor = "use_tor"
        case currentSpaceId = "current_space_id"
        case prohibitScreenshots = "prohibit_screenshots"
        case theme = "theme"
    }
    
    // MARK: - Basic Getters and Setters
    
    static func getString(forKey key: Keys, defaultValue: String) -> String {
        return defaults.string(forKey: key.rawValue) ?? defaultValue
    }
    
    static func putString(_ value: String, forKey key: Keys) {
        defaults.set(value, forKey: key.rawValue)
    }
    
    static func getInt(forKey key: Keys, defaultValue: Int) -> Int {
        return defaults.integer(forKey: key.rawValue) // Default already handled by UserDefaults
    }
    
    static func putInt(_ value: Int, forKey key: Keys) {
        defaults.set(value, forKey: key.rawValue)
    }
    
    static func getBool(forKey key: Keys, defaultValue: Bool) -> Bool {
        return defaults.object(forKey: key.rawValue) as? Bool ?? defaultValue
    }
    
    static func putBool(_ value: Bool, forKey key: Keys) {
        defaults.set(value, forKey: key.rawValue)
    }
    
    static func getLong(forKey key: Keys, defaultValue: Int64) -> Int64 {
        return defaults.object(forKey: key.rawValue) as? Int64 ?? defaultValue
    }
    
    static func putLong(_ value: Int64, forKey key: Keys) {
        defaults.set(value, forKey: key.rawValue)
    }
    
    static func remove(forKey key: Keys) {
        defaults.removeObject(forKey: key.rawValue)
    }
    
    static func contains(_ key: Keys) -> Bool {
        return defaults.object(forKey: key.rawValue) != nil
    }
    
    // MARK: - Properties
    
    @UserDefault(key: .passcodeEnabled, defaultValue: false)
    static var passcodeEnabled: Bool
    
    
    // MARK: - Advanced Properties
    static var isPasscodeEnabled: Bool {
        get { getBool(forKey: .passcodeEnabled, defaultValue: false) }
        set { putBool(newValue, forKey: .passcodeEnabled) }
    }
    
    static var didCompleteOnboarding: Bool {
        get { getBool(forKey: .didCompleteOnboarding, defaultValue: false) }
        set { putBool(newValue, forKey: .didCompleteOnboarding) }
    }
    
    static var uploadWifiOnly: Bool {
        get { getBool(forKey: .uploadWifiOnly, defaultValue: false) }
        set { putBool(newValue, forKey: .uploadWifiOnly) }
    }
    
    static var currentSpaceId: Int64 {
        get { getLong(forKey: .currentSpaceId, defaultValue: -1) }
        set { putLong(newValue, forKey: .currentSpaceId) }
    }
    
    static var theme: String {
        get { getString(forKey: .theme, defaultValue: "default") }
        set { putString(newValue, forKey: .theme) }
    }
}


/// A property wrapper to simplify access to `UserDefaults`
@propertyWrapper
struct UserDefault<T> {
    private let key: AppSettings.Keys
    private let defaultValue: T
    private let userDefaults: UserDefaults
    
    init(
        key: AppSettings.Keys,
        defaultValue: T,
        userDefaults: UserDefaults = .standard
    ) {
        self.key = key
        self.defaultValue = defaultValue
        self.userDefaults = userDefaults
    }
    
    var wrappedValue: T {
        get {
            return userDefaults.object(forKey: key.rawValue) as? T ?? defaultValue
        }
        set {
            userDefaults.set(newValue, forKey: key.rawValue)
        }
    }
}

/// A property wrapper for optional values in `UserDefaults`.
@propertyWrapper
struct OptionalUserDefault<T> {
    private let key: AppSettings.Keys
    private let userDefaults: UserDefaults
    
    init(
        key: AppSettings.Keys,
        userDefaults: UserDefaults = .standard
    ) {
        self.key = key
        self.userDefaults = userDefaults
    }
    
    var wrappedValue: T? {
        get {
            return userDefaults.object(forKey: key.rawValue) as? T
        }
        set {
            userDefaults.set(newValue, forKey: key.rawValue)
        }
    }
}
