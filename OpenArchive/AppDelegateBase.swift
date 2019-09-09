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

class AppDelegateBase: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    var window: UIWindow?

    var uploadManager: UploadManager?


    func application(_ application: UIApplication, didFinishLaunchingWithOptions
        launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        UNUserNotificationCenter.current().delegate = self

        window?.tintColor = UIColor.accent

        Db.setup()

        uploadManager = UploadManager.shared

        setUp()

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

    /**
     Catches the uploads which finished, when the app was stopped.
    */
    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        Conduit.backgroundSessionManager.backgroundCompletionHandler = completionHandler
    }

    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        Db.setup()

        uploadManager = UploadManager(completionHandler)
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

    func setUp() {
        Localize.update(provider: .strings)
        Localize.update(bundle: Bundle(for: type(of: self)))
        Localize.update(fileName: "Localizable")

        FontBlaster.blast() /* { fonts in
            print(fonts)
        } */
    }
}
