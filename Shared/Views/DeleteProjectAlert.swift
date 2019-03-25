//
//  DeleteProjectAlert.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 25.03.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

class DeleteProjectAlert: UIAlertController {

    convenience init(_ project: Project, _ onSuccess: (() -> ())? = nil) {
        self.init(title: "Delete Project".localize(),
                   message: "Are you sure you want to delete your project \"%\"?".localize(value: project.name ?? ""),
                   preferredStyle: .alert)

        addAction(AlertHelper.cancelAction())
        addAction(AlertHelper.destructiveAction("Delete".localize(), handler: { _ in
            Db.writeConn?.asyncReadWrite() { transaction in
                transaction.removeObject(forKey: project.id, inCollection: Project.collection)

                DispatchQueue.main.async {
                    onSuccess?()
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
