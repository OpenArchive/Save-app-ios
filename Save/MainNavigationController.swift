//
//  MainNavigationController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 24.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

class MainNavigationController: UINavigationController {

    override func viewDidLoad() {
        super.viewDidLoad()

        setRoot()
    }

    func setRoot() {
        if Settings.firstRunDone {
            if !(topViewController is MainViewController) {
                setViewControllers([UIStoryboard.main.instantiate(MainViewController.self)],
                                   animated: true)
            }
        }
        else {
            setViewControllers(
                [UIStoryboard.main.instantiateViewController(withIdentifier: "OnboardingViewController")],
                animated: true)
        }
    }
}
