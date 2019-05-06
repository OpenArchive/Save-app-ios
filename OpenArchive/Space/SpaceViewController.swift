//
//  SpaceViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 03.05.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import Eureka

/**
 Shows a menu to either forward to `InternetArchiveViewController`,
 `PrivateServerViewController` or `EditProfileViewController`.
 */
class SpaceViewController: BaseTableViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(SelectedSpaceCell.nib, forCellReuseIdentifier: SelectedSpaceCell.reuseId)

        tableView.separatorStyle = .none
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationItem.title = SelectedSpace.space?.prettyName

        tableView.reloadData()
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return indexPath.row == 0 ? SelectedSpaceCell.height : MenuItemCell.height
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 3
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.row == 0,
            let cell = tableView.dequeueReusableCell(withIdentifier: SelectedSpaceCell.reuseId) as? SelectedSpaceCell {

            cell.space = SelectedSpace.space

            return cell
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: MenuItemCell.reuseId, for: indexPath) as! MenuItemCell
        cell.accessoryType = .disclosureIndicator
        cell.label.text = indexPath.row == 1
            ? "Login Info".localize() : "Profile".localize()

        return cell
    }

    override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        return indexPath.row == 0 ? nil : indexPath
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let vc: UIViewController

        if indexPath.row == 2 {
            vc = EditProfileViewController()
        }
        else {
            if let space = SelectedSpace.space as? IaSpace {
                let iavc = InternetArchiveViewController()
                iavc.space = space
                vc = iavc
            }
            else if let space = SelectedSpace.space as? WebDavSpace {
                let psvc = PrivateServerViewController()
                psvc.space = space
                vc = psvc
            }
            else {
                return
            }
        }

        navigationController?.pushViewController(vc, animated: true)
    }
}
