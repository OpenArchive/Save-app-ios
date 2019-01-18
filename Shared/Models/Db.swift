//
//  Db.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 01.08.18.
//  Copyright © 2018 Open Archive. All rights reserved.
//

import UIKit
import YapDatabase

class Db {

    private static let DB_NAME = "open-archive.sqlite"

    public static var shared: YapDatabase? = {
        if let path = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: Constants.appGroup as String)?
            .appendingPathComponent(DB_NAME) {

            let options = YapDatabaseOptions()
            options.enableMultiProcessSupport = true

            return YapDatabase(path: path.path, options: options)
        }

        return nil
    }()

    public class func setup() {
        registerAsset()
        registerServerConfig()

        // Enable relationships. (Also row -> file relationship handling!)
        shared?.register(YapDatabaseRelationship(), withName: "relationships")

        // Enable cross-process notifications.
        shared?.register(YapDatabaseCrossProcessNotification(), withName: "xProcNotification")


        // Fix class de-/serialization errors due to iOS prefixing classes with the app/extension
        // depending on which part of the app wrote it.
        NSKeyedArchiver.setClassName("Asset", for: Asset.self)
        NSKeyedUnarchiver.setClass(Asset.self, forClassName: "Asset")

        NSKeyedArchiver.setClassName("InternetArchive", for: InternetArchive.self)
        NSKeyedUnarchiver.setClass(InternetArchive.self, forClassName: "InternetArchive")

        NSKeyedArchiver.setClassName("WebDavServer", for: WebDavServer.self)
        NSKeyedUnarchiver.setClass(WebDavServer.self, forClassName: "WebDavServer")

        NSKeyedArchiver.setClassName("ServerConfig", for: ServerConfig.self)
        NSKeyedUnarchiver.setClass(ServerConfig.self, forClassName: "ServerConfig")
    }

    public class func newConnection() -> YapDatabaseConnection? {
        return shared?.newConnection()
    }

    private class func registerAsset() {
        let grouper = YapDatabaseViewGrouping.withKeyBlock() {
            transaction, collection, key in

            if Asset.COLLECTION.elementsEqual(collection) {
                return Asset.COLLECTION
            }

            return nil
        }

        let sorter = YapDatabaseViewSorting.withObjectBlock() {
            transaction, group, collection1, key1, obj1, collection2, key2, obj2 in

            return (obj1 as? Asset)?.created
                .compare((obj2 as? Asset)?.created ?? Date())
                ?? ComparisonResult.orderedSame
        }

        shared?.register(YapDatabaseAutoView(grouping: grouper, sorting: sorter),
                         withName: Asset.COLLECTION)
    }

    private class func registerServerConfig() {
        let grouper = YapDatabaseViewGrouping.withKeyBlock() {
            transaction, collection, key in

            if ServerConfig.COLLECTION.elementsEqual(collection) {
                return ServerConfig.COLLECTION
            }

            return nil
        }

        let sorter = YapDatabaseViewSorting.withObjectBlock() {
            transaction, group, collection1, key1, obj1, collection2, key2, obj2 in

            return (obj1 as? ServerConfig)?.url?.absoluteString
                .compare((obj2 as? ServerConfig)?.url?.absoluteString ?? "")
                ?? ComparisonResult.orderedSame
        }

        shared?.register(YapDatabaseAutoView(grouping: grouper, sorting: sorter),
                         withName: ServerConfig.COLLECTION)
    }
}
