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
    @IBOutlet weak var subInfoLb: UILabel!
    @IBOutlet weak var manageBt: UIButton!

    private var collection: Collection?

    func set(_ collection: Collection? = nil, waiting: Int = 0, uploaded: Int = 0) {
        self.collection = collection

        if let uploadedTs = collection?.uploaded {

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

            subInfoLb.text = uploaded + waiting == 1
                ? "% of % item uploaded".localize(values: Formatters.format(uploaded), Formatters.format(uploaded + waiting))
                : "% of % items uploaded".localize(values: Formatters.format(uploaded), Formatters.format(uploaded + waiting))

            manageBt.setImage(nil, for: .normal)
            manageBt.setTitle("Manage".localize(), for: .normal)
            manageBt.isHidden = false
        }
        else {
            infoLb.text = "Waiting".localize().localizedUppercase

            subInfoLb.text = waiting == 1
                ? "% item ready to upload".localize(value: Formatters.format(waiting))
                : "% items ready to upload".localize(value: Formatters.format(waiting))

            manageBt.setImage(UIImage(named: "ic_up"), for: .normal)
            manageBt.setTitle(nil, for: .normal)
            manageBt.isHidden = false
        }
    }
    
    @IBAction func manage() {
        if collection?.closed != nil {
            print("[\(String(describing: type(of: self)))]#manage - state \"uploading\" - TODO: Go to upload manager")
        }
        else {
            print("[\(String(describing: type(of: self)))]#manage - state \"waiting\" - TODO: Go to assets-of-collection details scene")
        }
    }
}
