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

    @IBOutlet weak var timestampLb: UILabel!
    @IBOutlet weak var projectLb: UILabel!

    func set(_ collection: Collection? = nil) {
        projectLb.text = "Uploaded to %".localize(value: collection?.project.name ?? "unnamed".localize())

        if let uploaded = collection?.uploaded {
            let fiveMinAgo = Date(timeIntervalSinceNow: -5 * 60)

            timestampLb.text = fiveMinAgo < uploaded
                ? "Just now".localize()
                : "% ago".localize(value:
                    Formatters.uploaded.string(from: Date().timeIntervalSince(uploaded))!)
        }
        else {
            timestampLb.text = "Not yet".localize()
        }
    }
    
    @IBAction func addInfo(_ sender: Any) {
        print("[\(String(describing: type(of: self)))]#addInfo TODO")
    }
}
