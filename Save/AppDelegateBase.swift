//
//  AppDelegate.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 28.06.18.
//  Copyright © 2018 Open Archive. All rights reserved.
//

import UIKit
import UserNotifications
import LibProofMode
import SwiftUI
import FirebaseCore
import FirebaseAnalytics
import FirebaseCrashlytics
import Mixpanel

class AppDelegateBase: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    var uploadManager: UploadManager?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions
                     launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        UNUserNotificationCenter.current().delegate = self

        Db.setup()
        
        uploadManager = UploadManager.shared
        
        cleanCache()

        UIFont.setUpMontserrat()

        FirebaseApp.configure()

        let mixpanelProvider = MixpanelProvider(token: GeneralConstants.mix_panel_token)
        AnalyticsManager.shared.initialize(providers: [mixpanelProvider])

        AnalyticsManager.shared.startSession()

        // Track app opened
        let isFirstLaunch = !UserDefaults.standard.bool(forKey: "has_launched_before")
        if isFirstLaunch {
            UserDefaults.standard.set(true, forKey: "has_launched_before")
        }
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        trackEvent(.appOpened(isFirstLaunch: isFirstLaunch, appVersion: appVersion))

        applyTheme(AppSettings.theme)
        
        return true
    }
    
    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        UISceneConfiguration(
            name: "Default Configuration",
            sessionRole: connectingSceneSession.role
        )
    }

    func applicationWillTerminate(_ application: UIApplication) {
     
        AnalyticsManager.shared.endSession()
        cleanCache()
    }
    
    func application(_ app: UIApplication, open url: URL,
                     options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool
    {
        
        return true
    }
    
    /**
     Catches the uploads which finished, when the app was stopped.
     */
    func application(_ application: UIApplication,
                     handleEventsForBackgroundURLSession identifier: String,
                     completionHandler: @escaping () -> Void)
    {
        UploadManager.backgroundCompletionHandler = completionHandler
        
        if uploadManager == nil {
            uploadManager = UploadManager.shared
        }
    }
    
    func application(_ application: UIApplication, shouldAllowExtensionPointIdentifier
                     extensionPointIdentifier: UIApplication.ExtensionPointIdentifier) -> Bool
    {
        // Potential security issue: Only allow custom keyboards, if user explicitly said so.
        if extensionPointIdentifier == .keyboard {
            return Settings.thirdPartyKeyboards
        }
        
        return true
    }
    
    
    // MARK: UNUserNotificationCenterDelegate
    
    /**
     Allow notifications, when in foreground. Mainly used for dev purposes, currently,
     but doesn't harm, so left here to avoid unnecessary debugging.
     */
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent
                                notification: UNNotification, withCompletionHandler completionHandler:
                                @escaping (UNNotificationPresentationOptions) -> Void) {
        
        completionHandler([.banner, .badge, .sound])
    }
    
    /**
     Handle tap on the notification from Share Extension:

     - Select the project, where the user added something in the Share Extension.
     - Update MainViewController display.
     - Jump to preview scene showing all assets of the currently open collection.
     */
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive
                                response: UNNotificationResponse, withCompletionHandler completionHandler:
                                @escaping () -> Void) {

        guard let projectId = response.notification.request.content.userInfo[Project.collection] as? String,
              let project: Project = Db.bgRwConn?.object(for: projectId) else {
            completionHandler()
            return
        }

        SelectedSpace.space = project.space

        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }

        guard let navVc = window?.rootViewController as? UINavigationController else {
            completionHandler()
            return
        }

        var mainVc: MainViewController?
        var vc: UIViewController? = navVc
        while vc != nil {
            if let found = vc as? MainViewController {
                mainVc = found
                break
            }
            vc = vc?.subViewController
        }

        if let mainVc {
            navVc.popToViewController(mainVc, animated: false)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                mainVc.selectedProject = project
                mainVc.updateFilter()
                mainVc.picked()
            }
        }

        completionHandler()
    }
  
    func cleanCache()
    {
        // This will clean the contents of the Cache.db file, but unfortunately not
        // backup copies, which also exist.
        URLCache.shared.removeAllCachedResponses()
        
        let fm = FileManager.default
        
        if let id = Bundle.main.bundleIdentifier,
           let cache = fm.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent(id),
           cache.exists
        {
            do {
                // Try to remove *all* URL cache files.
                try fm.removeItem(at: cache)
            }
            catch {
                #if DEBUG
                debugPrint(error)
                #endif
            }
        }
        
        // Remove cached files from Dropbox web authentication.
        if let safariLib = fm.urls(for: .libraryDirectory, in: .userDomainMask).first?
            .appendingPathComponent("..")
            .appendingPathComponent("SystemData")
            .appendingPathComponent("com.apple.SafariViewService")
            .appendingPathComponent("Library"),
           safariLib.exists
        {
            do {
                try fm.removeItem(at: safariLib)
            }
            catch {
                #if DEBUG
                debugPrint(error)
                #endif
            }
        }
    }
    
}

extension AppDelegateBase {

    func applyTheme(_ theme: String) {
        if theme == GeneralConstants.dark {
            Utils.setDarkMode()
        } else if theme == GeneralConstants.light {
            Utils.setLightMode()
        } else {
            Utils.setUnspecifiedMode()
        }
    }
}
