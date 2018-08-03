//
//  MainViewController.swift
//  ShareExtension
//
//  Created by Benjamin Erhart on 03.08.18.
//  Copyright © 2018 Open Archive. All rights reserved.
//

import UIKit

@objc(MainViewController)
class MainViewController: UINavigationController {

    override func viewDidLoad() {
        super.viewDidLoad()

        Db.setup()

        self.pushViewController(ShareViewController(), animated: false)
    }
}
