//
//  ConnectSpaceViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 24.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

class ConnectSpaceViewController: BaseTableViewController {

    var hasOneInternetArchive = false
    var hasOneDropbox = false

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(dismiss))

        // Onboarding phase, directly after first start. Allow skip, so
        // users can see the main scene. Where they can't do anything, but
        // at least they can have a glimpse.
        // All other times they can back out with a navigation back button.
        if !SelectedSpace.available {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: NSLocalizedString("Skip", comment: ""), style: .plain, target: self,
                action: #selector(dismiss))
        }

        Db.bgRwConn?.asyncRead { transaction in
            transaction.iterateKeysAndObjects(inCollection: Space.collection, using: { (key, object: DropboxSpace, stop) in
                self.hasOneDropbox = true

                DispatchQueue.main.async {
                    self.tableView.reloadData()
                }

                stop = true
            })

            transaction.iterateKeysAndObjects(inCollection: Space.collection, using: { (key, object: IaSpace, stop) in
                self.hasOneInternetArchive = true

                DispatchQueue.main.async {
                    self.tableView.reloadData()
                }

                stop = true
            })
        }

        tableView.register(TitleCell.nib, forCellReuseIdentifier: TitleCell.reuseId)
        tableView.register(BigMenuItemCell.nib, forCellReuseIdentifier: BigMenuItemCell.reuseId)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    // MARK: UITableViewDataSource

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 2 + (hasOneDropbox ? 0 : 1) + (hasOneInternetArchive ? 0 : 1)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.row == 0,
            let cell = tableView.dequeueReusableCell(withIdentifier: TitleCell.reuseId, for: indexPath) as? TitleCell {

            return cell.set(NSLocalizedString("Connect Your Space", comment: ""),
                            NSLocalizedString("Set up where you want your media to be stored.", comment: ""))
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: BigMenuItemCell.reuseId, for: indexPath) as! BigMenuItemCell

        if indexPath.row == 2 {
            return hasOneDropbox ? cell.setInternetArchive() : cell.setDropbox()
        }
        else if indexPath.row == 3 {
            return cell.setInternetArchive()
        }

        return cell.setWebDav()
    }

    // MARK: UITableViewDelegate

    override func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return indexPath.row == 0 ? TitleCell.fullHeight : BigMenuItemCell.height
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let vc: FormViewController?

        switch indexPath.row {
        case 1:
            vc = PrivateServerViewController()

        case 2:
            vc = hasOneDropbox ? InternetArchiveViewController() : DropboxViewController()

        case 3:
            vc = InternetArchiveViewController()

        default:
            vc = nil
        }

        if let vc = vc {
            navigationController?.pushViewController(vc, animated: true)
        }
    }
}
