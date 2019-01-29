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

    func apply(_ project: Project, uploadedTs: TimeInterval) {
        projectLb.text = "Uploaded to %".localize(value: project.name ?? "unnamed".localize())

        let fiveMinAgo = Date(timeIntervalSinceNow: -5 * 60)
        let uploaded = Date(timeIntervalSince1970: uploadedTs)

        timestampLb.text = fiveMinAgo < uploaded
            ? "Just now".localize()
            : "% ago".localize(value:
                Formatters.uploaded.string(from: Date().timeIntervalSince(uploaded))
                    ?? "\(uploadedTs / 60) min")
    }
    
    @IBAction func addInfo(_ sender: Any) {
        print("[\(String(describing: type(of: self)))]#addInfo TODO")
    }
}
