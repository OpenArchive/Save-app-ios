//
//  DetailsViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 03.07.18.
//  Copyright © 2018 Open Archive. All rights reserved.
//

import UIKit

class DetailsViewController: BaseDetailsViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        let title = UILabel(frame: CGRect(x: 0, y: 0, width: 200, height: 28))
        title.text = asset?.filename
        title.allowsDefaultTighteningForTruncation = true
        title.adjustsFontSizeToFitWidth = true
        title.minimumScaleFactor = 0.5
        title.textAlignment = .center
        navigationItem.titleView = title

        serverUrlLb.addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(followServerUrl(_:))))
    }

    @objc func followServerUrl(_ sender: UITapGestureRecognizer) {
        if let url = asset?.getServers().first?.value.publicUrl {
            let vc = UIActivityViewController(activityItems: [url],
                                              applicationActivities: [TUSafariActivity(), ARChromeActivity()])
            present(vc, animated: true)

            // For iPad
            if let popOver = vc.popoverPresentationController {
                popOver.sourceView = serverUrlLb
                popOver.sourceRect = serverUrlLb.frame
            }
        }
    }
}
