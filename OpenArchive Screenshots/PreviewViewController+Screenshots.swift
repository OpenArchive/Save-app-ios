//
//  PreviewViewController+Screenshots.swift
//  OpenArchive Screenshots
//
//  Created by Benjamin Erhart on 24.09.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import Foundation

extension PreviewViewController {

    /**
     Sets the first upload to 50% progress, in order to have the screenshot show one upload which is in between
     and displays the number of uploaded bytes.
     */
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        Db.writeConn?.asyncReadWrite { transaction in
            var lowest = Int.max
            var firstUpload: Upload?

            transaction.enumerateKeysAndObjects(inCollection: Upload.collection) { key, object, stop in
                if let upload = object as? Upload, upload.order < lowest {
                    lowest = upload.order
                    firstUpload = upload
                }
            }

            if let firstUpload = firstUpload {
                firstUpload.progress = 0.5

                transaction.setObject(firstUpload, forKey: firstUpload.id, inCollection: Upload.collection)
            }
        }
    }
}
