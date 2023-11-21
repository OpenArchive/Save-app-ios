//
//  UploadInfoAlert.swift
//  Save
//
//  Created by Benjamin Erhart on 13.11.23.
//  Copyright © 2023 Open Archive. All rights reserved.
//

import UIKit

/**
 A special alert which informs the user about the finality of an upload.
 */
class UploadInfoAlert: InfoAlert {

    override class var image: UIImage? {
        UIImage(systemName: "arrow.up.square")
    }

    override class var tintColor: UIColor {
        .accent
    }

    override class var message: String {
        NSLocalizedString("Once uploaded, you will not be able to edit media.", comment: "")
    }

    override class var wasAlreadyShown: Bool {
        get {
            Settings.firstUploadDone
        }
        set {
            Settings.firstUploadDone = newValue
        }
    }
}
