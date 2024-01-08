//
//  HeaderView.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 29.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

class HeaderView: UICollectionReusableView {

    static let reuseId = "headerView"

    @IBOutlet weak var infoLb: UILabel!

    @IBOutlet weak var assetCountLb: UILabel! {
        didSet {
            // iOS 17 fix: Is ignored in iOS 17, when only set in storyboard.
            assetCountLb.clipsToBounds = true
        }
    }


    var collection: Collection? {
        didSet {
            if let uploadedTs = collection?.uploaded, collection?.waitingAssetsCount ?? 0 == 0 {
                let fiveMinAgo = Date(timeIntervalSinceNow: -5 * 60)

                infoLb.text = fiveMinAgo < uploadedTs
                    ? NSLocalizedString("Just now", comment: "")
                    : Formatters.format(uploadedTs)

                let uploaded = collection?.uploadedAssetsCount ?? 0

                assetCountLb.text = "  \(Formatters.format(uploaded))  "
            }
            else if collection?.closed != nil {
                if UploadManager.shared.waiting {
                    infoLb.text = NSLocalizedString("Waiting…", comment: "")
                }
                else {
                    infoLb.text = NSLocalizedString("Uploading…", comment: "")
                }

                let total = collection?.assets.count ?? 0
                let uploaded = collection?.uploadedAssetsCount ?? 0

                assetCountLb.text = String(
                    format: "  \(NSLocalizedString("%1$@/%2$@", comment: "both are integer numbers meaning 'x of n'"))  ",
                    Formatters.format(uploaded),
                    Formatters.format(total))
            }
            else {
                infoLb.text = NSLocalizedString("Ready to upload", comment: "").localizedUppercase

                let waiting = collection?.waitingAssetsCount ?? 0

                assetCountLb.text = "  \(Formatters.format(waiting))  "
            }
        }
    }
}
