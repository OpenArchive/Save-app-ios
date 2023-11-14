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

        Db.writeConn?.asyncReadWrite { tx in
            var lowest = Int.max
            var firstUpload: Upload?

            tx.iterate { (key, upload: Upload, stop) in
                if upload.order < lowest {
                    lowest = upload.order
                    firstUpload = upload
                }
            }

            if let firstUpload = firstUpload {
                firstUpload.progress = 0.5

                tx.setObject(firstUpload)
            }
        }
    }
}
