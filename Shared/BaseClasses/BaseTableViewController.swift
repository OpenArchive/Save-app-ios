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

        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }

        tableView.register(TableHeader.nib, forHeaderFooterViewReuseIdentifier: TableHeader.reuseId)
        tableView.register(MenuItemCell.nib, forCellReuseIdentifier: MenuItemCell.reuseId)

        tableView.tableFooterView = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.size.width, height: 1))
    }

    
    // MARK: UITableViewDelegate

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> TableHeader {
        return tableView.dequeueReusableHeaderFooterView(withIdentifier: TableHeader.reuseId) as! TableHeader
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return TableHeader.reducedHeight
    }


    // MARK: Actions

    @IBAction func dismiss(_ sender: Any? = nil) {
        if let nav = navigationController {
            nav.popViewController(animated: true)
        }
        else {
            dismiss(animated: true)
        }
    }
}
