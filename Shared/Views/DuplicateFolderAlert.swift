//
//  RemoveAssetAlert.swift
//  Save
//
//  Created by Benjamin Erhart on 25.03.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

class DuplicateFolderAlert: UIAlertController {

    /**
     - parameter foo: Just there to avoid endless recursion.
    */
    convenience init(_ foo: String?) {
        let message = NSLocalizedString("Please choose another name/folder or use the existing one instead.", comment: "")

        self.init(title: NSLocalizedString("Folder Already Exists", comment: ""),
                   message: message,
                   preferredStyle: .alert)

        addAction(AlertHelper.defaultAction())
    }

    private override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
    }

    /**
     Tests, if a name is already taken as a project for the given space.

     - parameter spaceId: The space to check against.
     - parameter name: The project name.
    */
    func exists(spaceId: String, name: String) -> Bool {
        Db.bgRwConn?.find(where: { (project: Project) in
            project.spaceId == spaceId && project.name == name
        }) != nil
    }
}
