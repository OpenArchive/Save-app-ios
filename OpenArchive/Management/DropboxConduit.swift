//
//  IaConduit.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 03.07.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import Alamofire
import MobileCoreServices

class DropboxConduit: Conduit {

    // MARK: Conduit

    /**
     */
    override func upload(uploadId: String) -> Progress {
        let progress = Progress(totalUnitCount: 100)

        return progress
    }

    override func remove(done: @escaping DoneHandler) {
    }
}
