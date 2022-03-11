//
//  RemoveProjectAlert.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 25.03.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import IPtProxyUI

class RemoveProjectAlert: UIAlertController {

    convenience init(_ project: Project, _ onSuccess: (() -> Void)? = nil) {
        self.init(title: NSLocalizedString("Remove from App", comment: ""),
                   message: String(format: NSLocalizedString("Are you sure you want to remove your project \"%@\"?", comment: ""), project.name ?? ""),
                   preferredStyle: .alert)

        addAction(AlertHelper.cancelAction())
        addAction(AlertHelper.destructiveAction(NSLocalizedString("Remove", comment: ""), handler: { _ in
            Db.writeConn?.asyncReadWrite() { transaction in
                transaction.removeObject(forKey: project.id, inCollection: Project.collection)

                if let onSuccess = onSuccess {
                    DispatchQueue.main.async(execute: onSuccess)
                }
            }
        }))
    }

    private override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
    }
}
