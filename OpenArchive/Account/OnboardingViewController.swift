//
//  OnboardingViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 24.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

class OnboardingViewController: BaseTableViewController {

    private static let alreadyRun = "already_run"

    class var firstRunDone: Bool {
        get {
            return UserDefaults(suiteName: Constants.suiteName)?.bool(forKey: alreadyRun)
                ?? false
        }
        set {
            UserDefaults(suiteName: Constants.suiteName)?.set(newValue, forKey: alreadyRun)
        }
    }

    var spaceCreated = false

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if InternetArchive.isAvailable || spaceCreated {
            done()
            return
        }

        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    // MARK: - Table view data source

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let vc: UIViewController?

        switch indexPath.row {
        case 1:
            vc = PrivateServerViewController()
        case 2:
            vc = InternetArchiveViewController()
        default:
            vc = nil
        }

        if let vc = vc {
            navigationController?.pushViewController(vc, animated: true)
        }
    }

    @IBAction func done() {
        OnboardingViewController.firstRunDone = true

        (navigationController as? MainNavigationController)?.setRoot()
    }
}
