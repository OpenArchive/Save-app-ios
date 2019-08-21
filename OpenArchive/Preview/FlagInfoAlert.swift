//
//  FlagInfoAlert.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 17.05.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

/**
 A special alert which informs the user about the flag feature.
 */
class FlagInfoAlert: InfoAlert {

    override class var image: UIImage? {
        return UIImage(named: "ic_flag")
    }

    override class var tintColor: UIColor {
        return UIColor.warning
    }

    override class var title: String {
        return "Flag Significant Content".localize()
    }

    override class var message: String {
        return "When you flag an item, it is routed into a subfolder within the chosen project folder on the private server.".localize()
    }

    override class var wasAlreadyShown: Bool {
        get {
            return Settings.firstFlaggedDone
        }
        set {
            Settings.firstFlaggedDone = newValue
        }
    }
}
