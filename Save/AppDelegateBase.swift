//
//  AppDelegate.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 28.06.18.
//  Copyright © 2018 Open Archive. All rights reserved.
//

import UIKit
import UserNotifications
import FontBlaster
import SwiftyDropbox
import CleanInsightsSDK
import LibProofMode

class AppDelegateBase: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    var window: UIWindow?

    var uploadManager: UploadManager?

    lazy var curtain: UIWindow? = {
        guard let scene = window?.windowScene else {
            return nil
        }

        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIStoryboard.main.instantiate(ClaimViewController.self)
        window.windowLevel = .alert

        return window
    }()

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

        setUpDropbox()

        setUpUi()

        setUpOrbot()

        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.

        if Settings.hideContent {
            curtain?.isHidden = false
            hadResigned = true
        }
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.

        CleanInsights.shared.persist()
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
    }

    func applicationDidBecomeActive(_ application: UIApplication) {

        if Settings.hideContent && hadResigned {
            curtain?.isHidden = true
        }

        // Note: If restart is slow (and even crashes), it could be, that
        // #applicationDidEnterBackground isn't finished, yet!

        if !verified, let privateKey = SecureEnclave.loadKey() {
            var counter = 0

            repeat {
                if let encryptedPassphrase = Settings.proofModeEncryptedPassphrase {
                    let passphrase = SecureEnclave.decrypt(encryptedPassphrase, with: privateKey)
                    Proof.shared.passphrase = passphrase

                    verified = passphrase != nil
                }
                else {
                    let nonce = SecureEnclave.getNonce()

                    verified = SecureEnclave.verify(
                        nonce, signature: SecureEnclave.sign(nonce, with: privateKey),
                        with: SecureEnclave.getPublicKey(privateKey))
                }

                counter += 1
            } while !verified && counter < 3

            if !verified {
                applicationWillResignActive(application)
                applicationDidEnterBackground(application)
                applicationWillTerminate(application)

                exit(0)
            }

            // Always return here, as the SecureEnclave operations will always
            // trigger a user identification and therefore the app becomes inactive
            // and then active again. So #applicationDidBecomeActive will be
            // called again. Therefore, we store the result of the verification
            // in an object property and check that on re-entry.
            return
        }

        verified = false
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.

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

        DropboxClientsManager.handleRedirectURL(url) { [weak self] authResult in
            switch authResult {
            case .success(let token):
                debugPrint("[\(String(describing: type(of: self)))] dropbox auth success")

                let space = DropboxSpace()
                space.username = token.uid
                space.password = token.accessToken
                SelectedSpace.space = space

                CleanInsights.shared.measure(event: "backend", "new", forCampaign: "upload_fails", name: space.name)

                let group = DispatchGroup()
                group.enter()

                Db.writeConn?.asyncReadWrite() { transaction in
                    SelectedSpace.store(transaction)

                    transaction.setObject(space)

                    group.leave()
                }

                DispatchQueue.global(qos: .background).async {
                    group.wait()

                    DropboxConduit.client?.users?.getCurrentAccount().response(completionHandler: { account, error in
                        space.email = account?.email

                        Db.writeConn?.setObject(space)
                    })
                }

                self?.mainVc?.addFolder()

            case .cancel, .none:
                debugPrint("[\(String(describing: type(of: self)))] dropbox auth cancelled")
                // Nothing to do. User cancelled. Dropbox authentication scene should close automatically.

            case .error(let error, let description):
                debugPrint("[\(String(describing: type(of: self)))] dropbox auth error=\(error), description=\(description ?? "nil")")
                // Nothing to do. User bailed out after login.
                // Dropbox authentication scene should close automatically.
            }
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
                    mainVc.showDetails(project.currentCollection)
                }
            }
        }

        completionHandler()
    }

    func setUpDropbox() {
        DropboxClientsManager.setupWithAppKey(
            Constants.dropboxKey,
            transportClient: DropboxConduit.transportClient(unauthorized: true))
    }

    func setUpUi() {
        FontBlaster.blast() /* { fonts in
            print(fonts)
        } */


        if #available(iOS 13.0, *) {
            let a = UINavigationBarAppearance()
            a.configureWithOpaqueBackground()

            UINavigationBar.appearance().scrollEdgeAppearance = a
        }
    }

    func setUpOrbot() {
        if Settings.useOrbot {
            OrbotManager.shared.start()

            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                OrbotManager.shared.alertOrbotStopped()
            }
        }
    }

    /**
     Somehow SwiftyDropbox still leaves traces in the URL cache, even, if we configure it to not cache anything.

     So, we clean the cache here as a last resort.

     Additionally, when Dropbox authentication is done via a web view, there's also remnants we try to remove here.
     */
    func cleanCache() {

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

extension CleanInsights {

    static var shared = try! CleanInsights(
        jsonConfigurationFile: Bundle.main.url(forResource: "cleaninsights-dev", withExtension: "json")!)
}
