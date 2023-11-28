//
//  RemoveProjectAlert.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 25.03.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

class RemoveProjectAlert: UIAlertController {

    convenience init(_ project: Project, _ completionHandler: ((_ success: Bool) -> Void)? = nil) {
        self.init(title: NSLocalizedString("Are you sure?", comment: ""),
                  message: String(format: NSLocalizedString(
                    "Removing this folder will remove all contained thumbnails from the %@ app.",
                    comment: "Placeholder is app name"), Bundle.main.displayName),
                   preferredStyle: .alert)

        addAction(AlertHelper.cancelAction(handler: { _ in
            if let completionHandler = completionHandler {
                DispatchQueue.main.async {
                    completionHandler(false)
                }
            }
        }))

        addAction(AlertHelper.destructiveAction(NSLocalizedString("Remove Folder", comment: ""), handler: { _ in
            Db.writeConn?.asyncReadWrite() { tx in
                tx.remove(project)

                if let completionHandler = completionHandler {
                    DispatchQueue.main.async {
                        completionHandler(true)
                    }
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
