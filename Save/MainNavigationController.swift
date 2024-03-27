//
//  MainNavigationController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 24.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import TorManager

class MainNavigationController: UINavigationController {

    override func viewDidLoad() {
        super.viewDidLoad()

        setRoot()
    }

    func setRoot() {
        if Settings.firstRunDone {
            if Settings.useTor && !TorManager.shared.connected {
                setViewControllers([UIStoryboard.main.instantiate(TorStartViewController.self)],
                                   animated: true)
            }
            else if !(topViewController is MainViewController) {
                setViewControllers([UIStoryboard.main.instantiate(MainViewController.self)],
                                   animated: true)
            }
        }
        else {
            setViewControllers(
                [UIStoryboard.main.instantiate(ClaimViewController.self)],
                animated: true)
        }
    }
}
