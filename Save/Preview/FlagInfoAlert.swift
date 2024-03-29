//
//  FlagInfoAlert.swift
//  Save
//
//  Created by Benjamin Erhart on 17.05.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

/**
 A special alert which informs the user about the flag feature.
 */
class FlagInfoAlert: InfoAlert {

    override class var image: UIImage? {
        UIImage(named: "ic_flag")
    }

    override class var tintColor: UIColor {
        .warning
    }

    override class var title: String {
        NSLocalizedString("Flag Significant Content", comment: "")
    }

    override class var message: String {
        NSLocalizedString(
            "When you flag an item, it is routed into a subfolder within the chosen folder on the private server.",
            comment: "")
    }

    override class var wasAlreadyShown: Bool {
        get {
            Settings.firstFlaggedDone
        }
        set {
            Settings.firstFlaggedDone = newValue
        }
    }
}
