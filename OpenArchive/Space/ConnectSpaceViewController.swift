//
//  ConnectSpaceViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 24.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

class ConnectSpaceViewController: BaseTableViewController, DoneDelegate {

    var hasOneInternetArchive = false

    override func viewDidLoad() {
        super.viewDidLoad()

        // Onboarding phase, directly after first start. Allow skip, so
        // users can see the main scene. Where they can't do anything, but
        // at least they can have a glimpse.
        // All other times they can back out with a navigation back button.
        if !SelectedSpace.available {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: "Skip".localize(), style: .plain, target: self,
                action: #selector(done))
        }

        Db.bgRwConn?.asyncRead { transaction in
            transaction.enumerateKeysAndObjects(inCollection: Space.collection, using: { key, object, stop in
                if object is IaSpace {
                    self.hasOneInternetArchive = true

                    DispatchQueue.main.async {
                        self.tableView.reloadData()
                    }

                    stop.pointee = true
                }
            })
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    // MARK: UITableViewDataSource

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 2 + (hasOneInternetArchive ? 0 : 1)
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let vc: FormViewController?

        switch indexPath.row {
        case 1:
            vc = PrivateServerViewController()
        case 2:
            vc = InternetArchiveViewController()
        default:
            vc = nil
        }

        if let vc = vc {
            vc.delegate = self

            navigationController?.pushViewController(vc, animated: true)
        }
    }


    // MARK: ConnectSpaceDelegate

    @objc func done() {
        if !Settings.firstRunDone {
            // We're still in the onboarding phase. Need to change root view
            // controller to main scene.

            Settings.firstRunDone = true

            (navigationController as? MainNavigationController)?.setRoot()
        }
        else {
            // All other times: We should be running in a popover as root.
            // Dismiss that.

            dismiss(animated: true)
        }
    }
}
