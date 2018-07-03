//
//  AppDelegate.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 28.06.18.
//  Copyright © 2018 Open Archive. All rights reserved.
//

import UIKit
import YapDatabase

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    static let DB_NAME = "open-archive.sqlite"

    var window: UIWindow?


    lazy var db: YapDatabase? = {
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        let baseDir = paths.count > 0 ? paths[0] : NSTemporaryDirectory()

        return YapDatabase(path: "\(baseDir)\(AppDelegate.DB_NAME)")
    }()


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.

        let assetsGrouper = YapDatabaseViewGrouping.withKeyBlock() {
            transaction, collection, key in

            if Asset.COLLECTION.elementsEqual(collection) {
                return Asset.COLLECTION
            }

            return nil
        }

        let assetsSorter = YapDatabaseViewSorting.withObjectBlock() {
            transaction, group, collection1, key1, obj1, collection2, key2, obj2 in

            return (obj1 as? Asset)?.created.compare((obj2 as? Asset)?.created ?? Date()) ?? ComparisonResult.orderedSame
        }


        let assetsView = YapDatabaseAutoView(grouping: assetsGrouper, sorting: assetsSorter)

        db?.register(assetsView, withName: Asset.COLLECTION)

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
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }


}

