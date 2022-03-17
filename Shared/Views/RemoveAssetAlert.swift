//
//  RemoveAssetAlert.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 25.03.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import IPtProxyUI

class RemoveAssetAlert: UIAlertController {

    convenience init(_ assets: [Asset], _ onSuccess: (() -> Void)? = nil) {
        let appName = Bundle.main.displayName

        let text = [
            String.localizedStringWithFormat(
                NSLocalizedString("This item/These items will be removed from the App only.", comment: "#bc-ignore!"),
                assets.count, appName),
            String.localizedStringWithFormat(
                NSLocalizedString("It/They will remain on the server and in your Photos app.", comment: "#bc-ignore!"),
                assets.count)]

        self.init(title: String(format: NSLocalizedString("Remove Media from %@", comment: ""), appName),
                  message: text.joined(separator: "\n"),
                   preferredStyle: .alert)

        addAction(AlertHelper.cancelAction())
        addAction(AlertHelper.destructiveAction(NSLocalizedString("Remove Media", comment: ""), handler: { _ in
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
