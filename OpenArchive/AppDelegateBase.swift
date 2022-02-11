//
//  AppDelegate.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 28.06.18.
//  Copyright © 2018 Open Archive. All rights reserved.
//

import UIKit
import UserNotifications
import Localize
import FontBlaster
import SwiftyDropbox

class AppDelegateBase: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    var window: UIWindow?

    var uploadManager: UploadManager?


    func application(_ application: UIApplication, didFinishLaunchingWithOptions
        launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        UNUserNotificationCenter.current().delegate = self

        window?.tintColor = .accent

        Db.setup()

        uploadManager = UploadManager.shared

        setUpDropbox()

        setUpUi()

        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.

        if let navVc = window?.rootViewController as? UINavigationController,
            let mainVc = navVc.viewControllers.first as? MainViewController {

            // `MainViewController#viewWillAppear` will not be called, when the
            // app is still running, but we need to update the selected project
            // filter anyway, because the share extension could have added an
            // image and for an unkown reason, this update doesn't bubble up
            // into the `AbcFilteredByProjectView`.
            // Here is the only place where we know, that we're in this situation.
            mainVc.updateFilter()
        }

        // #applicationWillEnterForeground is only called, if the app was already running,
        // not the first time.
        // In that case, the `UploadManager` might need a restart, since it could
        // have been #stopped, due to running out of background time.
        uploadManager?.restart()
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

    func application(_ app: UIApplication, open url: URL,
                     options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {

        DropboxClientsManager.handleRedirectURL(url) { [weak self] authResult in
            switch authResult {
            case .success(let token):
                print("[\(String(describing: type(of: self)))] dropbox auth success token=\(token)")

                SelectedSpace.space = DropboxSpace()
                SelectedSpace.space?.username = token.uid
                SelectedSpace.space?.password = token.accessToken

                Db.writeConn?.asyncReadWrite() { transaction in
                    SelectedSpace.store(transaction)

                    transaction.setObject(SelectedSpace.space, forKey: SelectedSpace.space!.id,
                                          inCollection: Space.collection)
                }

                // Find the MenuNavigationController which currently should
                // display DropboxViewController and replace that with the next step
                // of AddProjectViewController.
                var vc = self?.window?.rootViewController
                var menuNav: MenuNavigationController?

                while vc != nil {
                    if vc is MenuNavigationController {
                        menuNav = vc as? MenuNavigationController
                        break
                    }

                    vc = vc?.subViewController
                }

                menuNav?.setViewControllers([AddProjectViewController()], animated: true)

            case .cancel, .none:
                print("[\(String(describing: type(of: self)))] dropbox auth cancelled")
                // Nothing to do. User cancelled. Dropbox authentication scene should close automatically.

            case .error(let error, let description):
                print("[\(String(describing: type(of: self)))] dropbox auth error=\(error), description=\(description ?? "nil")")
                // Nothing to do. User bailed out after login.
                // Dropbox authentication scene should close automatically.
            }
        }

        return true
    }

    /**
     Catches the uploads which finished, when the app was stopped.
    */
    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        Conduit.backgroundSessionManager.backgroundCompletionHandler = completionHandler
    }

    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        Db.setup()

        uploadManager = UploadManager(completionHandler)

        setUpDropbox()
        
        uploadManager?.uploadNext()
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

        if let projectId = response.notification.request.content.userInfo[Project.collection] as? String {
            var project: Project?

            Db.bgRwConn?.read { transaction in
                project = transaction.object(forKey: projectId, inCollection: Project.collection) as? Project
            }

            if let project = project {
                SelectedSpace.space = project.space

                if let navVc = window?.rootViewController as? UINavigationController,
                    let mainVc = navVc.viewControllers.first as? MainViewController {

                    navVc.popToViewController(mainVc, animated: false)

                    // When launching, the app needs some time to initialize everything,
                    // otherwise it will crash.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        mainVc.tabBar.selectedProject = project
                        mainVc.updateFilter()
                        mainVc.showDetails(project.currentCollection)
                    }
                }
            }
        }

        completionHandler()
    }

    func setUpDropbox() {
        let client = DropboxTransportClient(
            accessToken: "", baseHosts: nil, userAgent: nil, selectUser: nil,
            sessionDelegate: uploadManager,
            backgroundSessionDelegate: Conduit.backgroundSessionManager.delegate,
            sharedContainerIdentifier: Constants.appGroup)

        DropboxClientsManager.setupWithAppKey(Constants.dropboxKey, transportClient: client)
    }

    func setUpUi() {
        Localize.update(provider: .strings)
        Localize.update(bundle: Bundle(for: type(of: self)))
        Localize.update(fileName: "Localizable")

        FontBlaster.blast() /* { fonts in
            print(fonts)
        } */


        if #available(iOS 13.0, *) {
            let a = UINavigationBarAppearance()
            a.configureWithOpaqueBackground()

            UINavigationBar.appearance().scrollEdgeAppearance = a
        }
    }
}
