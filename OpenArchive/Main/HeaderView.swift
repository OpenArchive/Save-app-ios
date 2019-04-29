//
//  HeaderView.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 29.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

protocol HeaderViewDelegate: class {
    func showDetails(_ collection: Collection)
}

class HeaderView: UICollectionReusableView {

    static let reuseId = "headerView"

    @IBOutlet weak var infoLb: UILabel!
    @IBOutlet weak var subInfoLb: UILabel!
    @IBOutlet weak var manageBt: UIButton!

    weak var delegate: HeaderViewDelegate?

    var collection: Collection? {
        didSet {
            if let uploadedTs = collection?.uploaded, collection?.waitingAssetsCount ?? 0 == 0 {
                let uploaded = collection?.uploadedAssetsCount ?? 0

                // I know this is really wrong, but using stringsdict is just a fucking
                // hastle and at least this works well for English, German and many more
                // languages.
                infoLb.text = uploaded == 1
                    ? "% Item Uploaded".localize(value: Formatters.format(uploaded))
                    : "% Items Uploaded".localize(value: Formatters.format(uploaded))

                let fiveMinAgo = Date(timeIntervalSinceNow: -5 * 60)

                subInfoLb.text = fiveMinAgo < uploadedTs
                    ? "Just now".localize()
                    : Formatters.format(uploadedTs)

                manageBt.isHidden = true
            }
            else if collection?.closed != nil {
                infoLb.text = "Uploading".localize().localizedUppercase

                let total = collection?.assets.count ?? 0
                let uploaded = collection?.uploadedAssetsCount ?? 0

                subInfoLb.text = total == 1
                    ? "% of % item uploaded".localize(values: Formatters.format(uploaded), Formatters.format(total))
                    : "% of % items uploaded".localize(values: Formatters.format(uploaded), Formatters.format(total))

                manageBt.isHidden = true
            }
            else {
                infoLb.text = "Ready to upload".localize().localizedUppercase

                let waiting = collection?.waitingAssetsCount ?? 0

                subInfoLb.text = waiting == 1
                    ? "% item".localize(value: Formatters.format(waiting))
                    : "% items".localize(value: Formatters.format(waiting))

                manageBt.isHidden = false
            }
        }
    }
    
    @IBAction func manage() {
        if let collection = collection {
            delegate?.showDetails(collection)
        }
        else {
            print("[\(String(describing: type(of: self)))]#manage - no collection! That should not happen!")
        }
    }
}
