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
import GoogleSignIn
import TorManager
import OrbotKit
import SwiftUI

class AppDelegateBase: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    var window: UIWindow?

    var uploadManager: UploadManager?

    private var hadResigned = false


    /**
    Flag, if biometric/password authentication after activation was successful.

    Return to false immediately after positive check, otherwise, security issues will arise!
    */
    private var verified = false

    private var mainVc: MainViewController? {
        var vc = window?.rootViewController

        while vc != nil {
            if let mainVc = vc as? MainViewController {
                return mainVc
            }

            vc = vc?.subViewController
        }

        return nil
    }


    func application(_ application: UIApplication, didFinishLaunchingWithOptions
        launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        UNUserNotificationCenter.current().delegate = self

        window?.tintColor = .accent

        Db.setup()

        uploadManager = UploadManager.shared

        cleanCache()

        setUpGdrive()

        UIFont.setUpMontserrat()

        setUpOrbotAndTor()
        applyTheme(AppSettings.theme)
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.

        if AppSettings.passcodeEnabled {
            BlurredSnapshot.create(window)
            hadResigned = true
        }
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.

        // `MainViewController#viewWillAppear` will not be called, when the
        // app is still running, but we need to update the selected project
        // filter anyway, because the share extension could have added an
        // image and for an unkown reason, this update doesn't bubble up
        // into the `AbcFilteredByProjectView`.
        // Here is the only place where we know, that we're in this situation.
        mainVc?.updateFilter()

        // #applicationWillEnterForeground is only called, if the app was already running,
        // not the first time.
        // In that case, the `UploadManager` might need a restart, since it could
        // have been #stopped, due to running out of background time.
        uploadManager?.restart()
        if(shouldShowAppPasscodeEntryScreen()){
            showAppPasscodeEntryScreen()
        }
       
    }

    func applicationDidBecomeActive(_ application: UIApplication) {

        if AppSettings.passcodeEnabled {
            BlurredSnapshot.remove()
        }

        // Note: If restart is slow (and even crashes), it could be, that
        // #applicationDidEnterBackground isn't finished, yet!

//        if !verified, let privateKey = SecureEnclave.loadKey() {
//            var counter = 0
//
//            repeat {
//                if let encryptedPassphrase = Settings.proofModeEncryptedPassphrase {
//                    let passphrase = SecureEnclave.decrypt(encryptedPassphrase, with: privateKey)
//                    Proof.shared.passphrase = passphrase
//
//                    verified = passphrase != nil
//
//                    if !verified {
//                        // This key cannot decrypt the passphare. Remove the passphrase,
//                        // so, during the next iteration of the loop, we can verify
//                        // the user normally. Otherwise, the user would be locked out forever.
//                        //
//                        // This situation could have been achieved by the user through
//                        // a bug, which was introduced during the redesign, where the
//                        // settings form was split into two pieces and the form row
//                        // dependencies didn't work anymore.
//                        Settings.proofModeEncryptedPassphrase = nil
//                    }
//                }
//                else {
//                    let nonce = SecureEnclave.getNonce()
//
//                    verified = SecureEnclave.verify(
//                        nonce, signature: SecureEnclave.sign(nonce, with: privateKey),
//                        with: SecureEnclave.getPublicKey(privateKey))
//                }
//
//                counter += 1
//            } while !verified && counter < 3
//
//            if !verified {
//                applicationWillResignActive(application)
//                applicationDidEnterBackground(application)
//                applicationWillTerminate(application)
//
//                exit(0)
//            }
//
//            // Always return here, as the SecureEnclave operations will always
//            // trigger a user identification and therefore the app becomes inactive
//            // and then active again. So #applicationDidBecomeActive will be
//            // called again. Therefore, we store the result of the verification
//            // in an object property and check that on re-entry.
//            return
//        }
//
//        verified = false
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.

        TorManager.shared.stop()

        cleanCache()
    }

    func application(_ app: UIApplication, open url: URL,
                     options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool
    {
        if let urlc = URLComponents(url: url, resolvingAgainstBaseURL: true),
            urlc.path == "token-callback"
        {
            if let token = urlc.queryItems?.first(where: { $0.name == "token" })?.value {
                OrbotManager.shared.received(token: token)
            }

            return true
        }

        if GIDSignIn.sharedInstance.handle(url) {
            return true
        }

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

        completionHandler([.alert, .badge, .sound])
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

        if let projectId = response.notification.request.content.userInfo[Project.collection] as? String,
           let project: Project = Db.bgRwConn?.object(for: projectId)
        {
            SelectedSpace.space = project.space

            if let navVc = window?.rootViewController as? UINavigationController,
               let mainVc = mainVc
            {
                navVc.popToViewController(mainVc, animated: false)

                // When launching, the app needs some time to initialize everything,
                // otherwise it will crash.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    mainVc.selectedProject = project
                    mainVc.updateFilter()
                    mainVc.picked()
                }
            }
        }

        completionHandler()
    }

    func setUpGdrive() {
        GIDSignIn.sharedInstance.restorePreviousSignIn { user, error in
            if error != nil || user == nil {
                GdriveConduit.user = nil
            }
            else {
                GdriveConduit.user = user
            }
        }
    }

    func setUpOrbotAndTor() {
        if Settings.useOrbot {
            OrbotManager.shared.start()
        }
        else {
            // Always set up Orbot API token, so TorManager can work around Orbot, if need be.
            OrbotKit.shared.apiToken = Settings.orbotApiToken
        }

        // Always initialize TorManager, so PT_STATE directory gets set and users
        // can fetch bridges before they switch on Tor.
        _ = TorManager.shared

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            OrbotManager.shared.alertCannotUpload()
        }
    }

    /**
     Somehow SwiftyDropbox still leaves traces in the URL cache, even, if we configure it to not cache anything.

     So, we clean the cache here as a last resort.

     Additionally, when Dropbox authentication is done via a web view, there's also remnants we try to remove here.
     */
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
                debugPrint(error)
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
                debugPrint(error)
            }
        }
    }
   
}

extension TorManager {
    static let shared = TorManager(directory: .groupDir!.appendingPathComponent("tor", isDirectory: true))
}

extension AppDelegateBase {
    
     func showAppPasscodeEntryScreen() {
        guard let rootVC = window?.rootViewController else { return }

        // Check if PIN screen is already presented
        if let presented = rootVC.presentedViewController,
           presented is UIHostingController<PasscodeEntryView> {
            return
        }
         
         // Define the onComplete closure to dismiss the screen or perform further actions
         let onPasscodeSuccess = {
             rootVC.dismiss(animated: true) {
                 print("Passcode verified successfully!")
                 // Perform further actions after passcode success, if needed
             }
         }
         
         let onExit = {
             print("Exiting the application...")
             UIControl().sendAction(#selector(NSXPCConnection.suspend), to: UIApplication.shared, for: nil)
             DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                 exit(0)
             }
         }

        // Show the PIN screen
         let passcodeEntryView = PasscodeEntryView(
            onPasscodeSuccess: onPasscodeSuccess,
            onExit: onExit
//            onExit: {
//                self.showAppPasscodeEntryScreen()
//            }
        )

        let hostingController = UIHostingController(rootView: passcodeEntryView)
        hostingController.modalPresentationStyle = .fullScreen
        rootVC.present(hostingController, animated: true)
    }
    
    func shouldShowAppPasscodeEntryScreen() -> Bool {
        return AppSettings.passcodeEnabled
    }
    func applyTheme(_ theme: String) {
        if theme == GeneralConstants.dark {
            Utils.setDarkMode()
        } else if theme == GeneralConstants.light {
            Utils.setLightMode()
        }
        else {
            Utils.setUnspecifiedMode()
        }
    }
}
