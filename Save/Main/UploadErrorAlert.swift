//
//  UploadErrorAlert.swift
//  Save
//
//  Created by Benjamin Erhart on 20.11.23.
//  Copyright © 2023 Open Archive. All rights reserved.
//

import UIKit

class UploadErrorAlert {

    class func present(_ vc: UIViewController, _ upload: Upload) {
        AlertHelper.present(
            vc, message: upload.error,
            title: NSLocalizedString("Upload unsuccessful", comment: ""),
            actions: [
                AlertHelper.destructiveAction(NSLocalizedString("Remove", comment: ""), handler: { _ in
                    upload.remove()
                }),
                AlertHelper.defaultAction(NSLocalizedString("Retry", comment: ""), handler: { _ in
                    NotificationCenter.default.post(name: .uploadManagerUnpause, object: upload.id)
                }),
                AlertHelper.cancelAction()])
    }
}
