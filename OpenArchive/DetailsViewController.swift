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

        navigationItem.title = NSLocalizedString("Details", comment: "Title of details scene.")

        // Add upload button.
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(named: "CloudUpload"),
                                                            style: .plain,
                                                            target: self,
                                                            action: #selector(upload(_:)))

        serverUrlLb.addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(followServerUrl(_:))))
    }

    @objc func followServerUrl(_ sender: UITapGestureRecognizer) {
        if let url = asset?.getServers().first?.publicUrl {
            UIApplication.shared.openURL(url)
        }
    }
}
