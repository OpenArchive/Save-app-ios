//
//  AppDelegate.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 28.06.18.
//  Copyright © 2018 Open Archive. All rights reserved.
//

import UIKit
import FontBlaster

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    var uploadManager: BackgroundUploadManager?


    func application(_ application: UIApplication, didFinishLaunchingWithOptions
        launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        window?.tintColor = UIColor.accent

        Db.setup()

        uploadManager = BackgroundUploadManager.shared

        FontBlaster.blast() /* { fonts in
            print(fonts)
        } */
        
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
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        Db.setup()

        uploadManager = BackgroundUploadManager(completionHandler)
        uploadManager?.uploadNext()
    }
}
