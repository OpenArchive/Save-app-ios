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
        Settings.firstUploadDone = true

        let space = Space(name: "My Cloud", favIcon: UIImage(named: "ic_nextcloud_favicon"))
        SelectedSpace.space = space

        let project1 = Project(name: "Tunis 2019", space: space)
        let project2 = Project(name: "Berlin 2018", space: space)
        project2.license = String(format: CcSelector.ccUrl, CcSelector.ccDomain, "by-nc-sa")

        Db.writeConn?.readWrite({ tx in
            tx.removeAllObjectsInAllCollections()
            tx.setObject(space, forKey: space.id, inCollection: Space.collection)

            SelectedSpace.store(tx)

            tx.setObject(project1)
            tx.setObject(project2)
        })

        let collection = project2.currentCollection

        for image in images {
            let asset = AssetFactory.create(fromAssets: image, collection)

            _ = Asset.updateSync(assets: [asset]) {
                $0.filename = "\(image).JPG"
                $0.location = "10405 Berlin\nGermany"
            }
        }
    }
}
