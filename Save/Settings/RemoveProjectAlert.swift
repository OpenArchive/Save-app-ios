//
//  RemoveProjectAlert.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 25.03.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import SDCAlertView
import SwiftUI
class RemoveProjectAlert {

    class func present(_ vc: UIViewController, _ project: Project, _ completionHandler: ((_ success: Bool) -> Void)? = nil) {
       
        
        let alertVC = CustomAlertViewController(
            title: NSLocalizedString("Are you sure?", comment: ""),
            message: String(format: NSLocalizedString(
                "Removing this folder will remove all contained thumbnails from the %@ app.",
                comment: "Placeholder is app name"), Bundle.main.displayName),
            primaryButtonTitle: NSLocalizedString("Remove Folder", comment: ""),
            primaryButtonAction: {
                Db.writeConn?.asyncReadWrite() { tx in
                    tx.remove(project)

                    if let completionHandler = completionHandler {
                        DispatchQueue.main.async {
                            completionHandler(true)
                        }
                    }
                }
            },
            secondaryButtonTitle: NSLocalizedString("Cancel", comment: ""),
            secondaryButtonAction: {
                if let completionHandler = completionHandler {
                    DispatchQueue.main.async {
                        completionHandler(false)
                    }
                }
            }, showCheckbox: false, secondaryButtonIsOutlined: false,
            iconImage: Image(systemName: "exclamationmark.circle"),isRemoveAlert: true
        )
        
        vc.present(alertVC, animated: true)
        
    }
}
