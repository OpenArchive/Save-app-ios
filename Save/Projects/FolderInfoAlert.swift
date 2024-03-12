//
//  FolderInfoAlert.swift
//  Save
//
//  Created by Benjamin Erhart on 21.11.23.
//  Copyright © 2023 Open Archive. All rights reserved.
//

import UIKit

class FolderInfoAlert: InfoAlert {

    override class var image: UIImage? {
        UIImage(systemName: "folder")
    }

    override class var tintColor: UIColor {
        .accent
    }

    override class var title: String {
        NSLocalizedString("To get started, please add a folder", comment: "")
    }

    override class var buttonTitle: String {
        NSLocalizedString("Add a Folder", comment: "")
    }

    override class var wasAlreadyShown: Bool {
        get {
            Settings.firstFolderDone
        }
        set {
            Settings.firstFolderDone = newValue
        }
    }

}
