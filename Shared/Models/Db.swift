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
            .containerURL(forSecurityApplicationGroupIdentifier: Constants.appGroup)?
            .appendingPathComponent(DB_NAME) {

//            print("[\(String(describing: Db.self))] path=\(path)")

            let options = YapDatabaseOptions()
            options.enableMultiProcessSupport = true

            return YapDatabase(path: path.path, options: options)
        }

        return nil
    }()

    public class func setup() {
        shared?.register(AssetsProjectsView(), withName: AssetsProjectsView.name)
        shared?.register(SpacesProjectsView(), withName: SpacesProjectsView.name)

        // Enable relationships. (Also row -> file relationship handling!)
        shared?.register(YapDatabaseRelationship(), withName: "relationships")

        // Enable cross-process notifications.
        shared?.register(YapDatabaseCrossProcessNotification(), withName: "xProcNotification")


        Space.fixArchiverName()
        Project.fixArchiverName()
        Collection.fixArchiverName()
        Asset.fixArchiverName()

        NSKeyedArchiver.setClassName("InternetArchive", for: InternetArchive.self)
        NSKeyedUnarchiver.setClass(InternetArchive.self, forClassName: "InternetArchive")

        NSKeyedArchiver.setClassName("WebDavServer", for: WebDavServer.self)
        NSKeyedUnarchiver.setClass(WebDavServer.self, forClassName: "WebDavServer")
    }

    public class func newConnection() -> YapDatabaseConnection? {
        return shared?.newConnection()
    }
}

protocol Item: NSCoding {

    static var collection: String { get }

    /**
     Fix class de-/serialization errors due to iOS prefixing classes with the
     app/extension depending on which part of the app wrote it.

     Should look something like this:

     ```Swift
     NSKeyedArchiver.setClassName("MyItem", for: self)
     NSKeyedUnarchiver.setClass(self, forClassName: "MyItem")
     ```
     */
    static func fixArchiverName()

    /**
     The key to file this object under.
    */
    var id: String { get }

    associatedtype Item2: Item

    func compare(_ rhs: Item2) -> ComparisonResult
}
