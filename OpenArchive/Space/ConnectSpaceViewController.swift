//
//  ConnectSpaceViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 24.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

class ConnectSpaceViewController: BaseTableViewController {

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

        // Onboarding phase, directly after first start. Allow skip, so
        // users can see the main scene. Where they can't do anything, but
        // at least they can have a glimpse.
        // All other times they can back out with a navigation back button.
        if !ConnectSpaceViewController.firstRunDone {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: "Skip".localize(), style: .plain, target: self,
                action: #selector(done))
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if spaceCreated {
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
        if !ConnectSpaceViewController.firstRunDone {
            // We're still in the onboarding phase. Need to change root view
            // controller to main scene.

            ConnectSpaceViewController.firstRunDone = true

            (navigationController as? MainNavigationController)?.setRoot()
        }
        else {
            // All other times: We're not the root view controller, so just
            // back out.

            navigationController?.popViewController(animated: true)
        }
    }
}
