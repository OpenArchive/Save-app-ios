//
//  HeaderView.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 29.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

protocol HeaderViewDelegate: AnyObject {
    func showDetails(_ collection: Collection, section: Int?)
}

class HeaderView: UICollectionReusableView {

    static let reuseId = "headerView"

    @IBOutlet weak var infoLb: UILabel!
    @IBOutlet weak var subInfoLb: UILabel!
    @IBOutlet weak var manageBt: UIButton!

    weak var delegate: HeaderViewDelegate?

    var section: Int?

    var collection: Collection? {
        didSet {
            if let uploadedTs = collection?.uploaded, collection?.waitingAssetsCount ?? 0 == 0 {
                let uploaded = collection?.uploadedAssetsCount ?? 0

                // I know this is really wrong, but using stringsdict is just a fucking
                // hastle and at least this works well for English, German and many more
                // languages.
                infoLb.text = String.localizedStringWithFormat(NSLocalizedString("%u Item(s) Uploaded", comment: "#bc-ignore!"), uploaded)

                let fiveMinAgo = Date(timeIntervalSinceNow: -5 * 60)

                subInfoLb.text = fiveMinAgo < uploadedTs
                    ? NSLocalizedString("Just now", comment: "")
                    : Formatters.format(uploadedTs)

                manageBt.isHidden = true
            }
            else if collection?.closed != nil {
                infoLb.text = NSLocalizedString("Uploading", comment: "").localizedUppercase

                let total = collection?.assets.count ?? 0
                let uploaded = collection?.uploadedAssetsCount ?? 0

                let format = NSLocalizedString("%1$u of %2$u item(s) uploaded", comment: "#bc-ignore!")
                let result = String.localizedStringWithFormat(format, uploaded, total)

                print("[\(String(describing: type(of: self)))] format=\(format), result=\(result)")

                subInfoLb.text = String.localizedStringWithFormat(NSLocalizedString("%1$u of %2$u item(s) uploaded", comment: "#bc-ignore!"), uploaded, total)

                manageBt.isHidden = true
            }
            else {
                infoLb.text = NSLocalizedString("Ready to upload", comment: "").localizedUppercase

                let waiting = collection?.waitingAssetsCount ?? 0

                let format = NSLocalizedString("%u item(s)", comment: "#bc-ignore!")
                let result = String.localizedStringWithFormat(format, waiting)

                print("[\(String(describing: type(of: self)))] format=\(format), result=\(result)")

                subInfoLb.text = String.localizedStringWithFormat(NSLocalizedString("%u item(s)", comment: "#bc-ignore!"), waiting)

                manageBt.isHidden = false
            }
        }
    }
    
    @IBAction func manage() {
        if let collection = collection {
            delegate?.showDetails(collection, section: section)
        }
        else {
            print("[\(String(describing: type(of: self)))]#manage - no collection! That should not happen!")
        }
    }
}
