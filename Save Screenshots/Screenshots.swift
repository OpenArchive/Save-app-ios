//
//  Screenshots.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 24.07.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

class Screenshots {

    private static let images = ["IMG_4014", "IMG_3201", "IMG_1491",
                                 "IMG_1252", "IMG_1508", "IMG_1291" ]

    /**
     Prepare app to take screenshots for App Store.
    */
    class func prepare() {
        // Disable animations to avoid timing issues.
        UIView.setAnimationsEnabled(false)

        // Create test environment.
        Settings.firstRunDone = true
        Settings.firstBatchEditDone = true

        let space = Space(name: "My Cloud", favIcon: UIImage(named: "ic_nextcloud_favicon"))
        SelectedSpace.space = space

        let project1 = Project(name: "Tunis 2019", space: space)
        let project2 = Project(name: "Berlin 2018", space: space)
        project2.license = String(format: EditProjectViewController.ccUrl, EditProjectViewController.ccDomain, "by-nc-sa")

        Db.writeConn?.readWrite({ transaction in
            transaction.removeAllObjectsInAllCollections()
            transaction.setObject(space, forKey: space.id, inCollection: Space.collection)

            SelectedSpace.store(transaction)

            transaction.setObject(project1, forKey: project1.id, inCollection: Project.collection)
            transaction.setObject(project2, forKey: project2.id, inCollection: Project.collection)
        })

        var assets = [Asset]()

        let collection = project2.currentCollection

        for image in images {
            let asset = AssetFactory.create(fromAssets: image, collection)

            asset.filename = "\(image).JPG"

            asset.location = "10405 Berlin\nGermany"

            assets.append(asset)
        }

        Db.writeConn?.readWrite({ transaction in
            for asset in assets {
                transaction.setObject(asset, forKey: asset.id, inCollection: Asset.collection)
            }
        })
    }
}
