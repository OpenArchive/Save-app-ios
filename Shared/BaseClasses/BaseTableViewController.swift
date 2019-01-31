//
//  BaseTableViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 31.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

class BaseTableViewController: UITableViewController {

    lazy var workingOverlay: WorkingOverlay = {
        return WorkingOverlay().addToSuperview(navigationController?.view ?? view)
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.tableFooterView = UIView()
    }
}
