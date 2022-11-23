//
//  AppAddProjectViewController.swift
//  Save
//
//  Created by Benjamin Erhart on 22.11.22.
//  Copyright © 2022 Open Archive. All rights reserved.
//

import UIKit

class AppAddProjectViewController: AddProjectViewController {

    override var noBrowse: Bool {
        SelectedSpace.space is IaSpace
    }

    // MARK: UITableViewDelegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.row == 2 && SelectedSpace.space is DropboxSpace {
            navigationController?.pushViewController(BrowseDropboxViewController(), animated: true)
        }
        else {
            super.tableView(tableView, didSelectRowAt: indexPath)
        }
    }
}
