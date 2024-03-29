//
//  BatchInfoAlert.swift
//  Save
//
//  Created by Benjamin Erhart on 09.07.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

/**
 A special alert which informs the user about the batch edit feature.
 */
class BatchInfoAlert: InfoAlert {

    override class var image: UIImage? {
        UIImage(named: "ic_compose")
    }

    override class var tintColor: UIColor {
        .warning
    }

    override class var title: String {
        NSLocalizedString("Edit Multiple", comment: "")
    }

    override class var message: String {
        NSLocalizedString("Press and hold to select and edit multiple media.", comment: "")
    }

    override class var wasAlreadyShown: Bool {
        get {
            Settings.firstBatchEditDone
        }
        set {
            Settings.firstBatchEditDone = newValue
        }
    }
}
