//
//  MenuNavigationController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 16.05.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

class MenuNavigationController: UINavigationController {

    override func viewDidLoad() {
        super.viewDidLoad()

        setRoot()
    }

    func setRoot() {
        if !SelectedSpace.available {
            let vc = UIStoryboard(name: "Main", bundle: nil)
                .instantiateViewController(withIdentifier: "connectSpace")

            setViewControllers([vc], animated: true)
        }
    }
}
