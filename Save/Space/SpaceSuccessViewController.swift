//
//  SpaceSuccessViewController.swift
//  Save
//
//  Created by Benjamin Erhart on 22.11.23.
//  Copyright © 2023 Open Archive. All rights reserved.
//

import UIKit

class SpaceSuccessViewController: BaseViewController {


    var spaceName = ""


    @IBOutlet weak var titleLb: UILabel!

    @IBOutlet weak var doneBt: UIButton! {
        didSet {
            doneBt.setTitle(NSLocalizedString("Done", comment: ""))
        }
    }


    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = NSLocalizedString("Setup Complete", comment: "")
        titleLb.text = String(
            format: NSLocalizedString("You have successfully connected to %@!",
                                      comment: "Placeholder is a server type or name"),
            spaceName)
    }

    @IBAction func done() {
        if let existingVC = navigationController?.viewControllers.first(where: { $0.isKind(of: type(of: MainViewController())) }) {
            navigationController?.popToViewController(existingVC, animated: true)
            } else {
                navigationController?.setViewControllers([UIStoryboard.main.instantiate(MainViewController.self)],
                                   animated: true)
            }
    }
}
