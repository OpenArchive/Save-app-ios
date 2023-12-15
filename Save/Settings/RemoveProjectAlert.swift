//
//  RemoveProjectAlert.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 25.03.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import SDCAlertView

class RemoveProjectAlert {

    class func present(_ vc: UIViewController, _ project: Project, _ completionHandler: ((_ success: Bool) -> Void)? = nil) {
        AlertHelper.present(
            vc,
            message: String(format: NSLocalizedString(
                "Removing this folder will remove all contained thumbnails from the %@ app.",
                comment: "Placeholder is app name"), Bundle.main.displayName),
            title: NSLocalizedString("Are you sure?", comment: ""),
            actions: [
                AlertHelper.cancelAction(handler: { _ in
                    if let completionHandler = completionHandler {
                        DispatchQueue.main.async {
                            completionHandler(false)
                        }
                    }
                }),
                AlertHelper.destructiveAction(NSLocalizedString("Remove Folder", comment: ""), handler: { _ in
                    Db.writeConn?.asyncReadWrite() { tx in
                        tx.remove(project)

                        if let completionHandler = completionHandler {
                            DispatchQueue.main.async {
                                completionHandler(true)
                            }
                        }
                    }
                })
            ])
    }
}
