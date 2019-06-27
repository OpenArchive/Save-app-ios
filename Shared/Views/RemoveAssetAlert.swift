//
//  RemoveAssetAlert.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 25.03.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

class RemoveAssetAlert: UIAlertController {

    convenience init(_ assets: [Asset], _ onSuccess: (() -> Void)? = nil) {
        let appName = Bundle.main.displayName

        let message = assets.count == 1
        ? "This item will be removed only from the % App.\nIt will remain on the server and in your camera roll."
            .localize(value: appName)
            : "These items will be removed only from the % App.\nThey will remain on the server and in your camera roll."
                .localize(value: appName)

        self.init(title: "Remove Media from %".localize(value: appName),
                   message: message,
                   preferredStyle: .alert)

        addAction(AlertHelper.cancelAction())
        addAction(AlertHelper.destructiveAction("Remove Media".localize(), handler: { _ in
            for asset in assets {
                if asset == assets.last {
                    asset.remove(onSuccess)
                }
                else {
                    asset.remove()
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
