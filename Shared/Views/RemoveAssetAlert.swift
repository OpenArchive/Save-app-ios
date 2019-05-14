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
        let message = assets.count == 1
            ? "This item will be removed from your project.".localize()
            : "These items will be removed from your project.".localize()

        self.init(title: "Remove Media".localize(),
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
