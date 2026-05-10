//
//  RemoveProjectAlert.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 25.03.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import SwiftUI
import UIKit

class RemoveProjectAlert {

    class func present(_ vc: UIViewController, _ project: Project, _ completionHandler: ((_ success: Bool) -> Void)? = nil) {

        let model = CustomAlertPresentationModel(
            title: NSLocalizedString("Remove from app", comment: ""),
            message: String(format: NSLocalizedString(
                "Are you sure you want to remove your project?",
                comment: "Placeholder is app name"), Bundle.main.displayName),
            primaryButtonTitle: NSLocalizedString("Remove", comment: ""),
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
            },
            secondaryButtonIsOutlined: false,
            showCheckbox: false,
            iconImage: Image("trash_icon"),
            isRemoveAlert: true
        )

        CustomAlertPresenter.present(model, from: vc)
    }
}
