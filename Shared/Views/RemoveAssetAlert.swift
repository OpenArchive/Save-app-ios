//
//  RemoveAssetAlert.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 25.03.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

class RemoveAssetAlert: UIAlertController {

    convenience init(_ asset: Asset, _ onSuccess: (() -> Void)? = nil) {
        self.init(title: "Remove Media".localize(),
                   message: "This item will be removed from your project!".localize(),
                   preferredStyle: .alert)

        addAction(AlertHelper.cancelAction())
        addAction(AlertHelper.destructiveAction("Remove Media".localize(), handler: { _ in
            asset.remove(onSuccess)
        }))
    }

    private override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
    }
}
