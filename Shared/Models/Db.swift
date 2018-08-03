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
        if let path = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Constants.appGroup as String)?.appendingPathComponent(DB_NAME) {

            return YapDatabase(path: path.path)
        }

        return nil
    }()

    public class func setup() {
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

        shared?.register(assetsView, withName: Asset.COLLECTION)

        // Fix class de-/serialization errors due to iOS prefixing classes with the app/extension
        // depending on which part of the app wrote it.
        NSKeyedArchiver.setClassName("Image", for: Image.self)
        NSKeyedUnarchiver.setClass(Image.self, forClassName: "Image")
    }

    public class func newConnection() -> YapDatabaseConnection? {
        return shared?.newConnection()
    }
}
