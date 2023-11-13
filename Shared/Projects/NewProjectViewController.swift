//
//  NewProjectViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 29.03.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import Eureka

class NewProjectViewController: BaseProjectViewController {

    init() {
        super.init(Project(space: SelectedSpace.space))
    }

    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
    }

    override func viewDidLoad() {
        navigationItem.title = NSLocalizedString("New Project", comment: "")

        if navigationController?.viewControllers.first == self {
            navigationItem.leftBarButtonItem = UIBarButtonItem(
                barButtonSystemItem: .cancel, target: self, action: #selector(dismiss))
        }

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done, target: self, action: #selector(connect))
        navigationItem.rightBarButtonItem?.accessibilityIdentifier = "btDone"

        form
            +++ LabelRow() {
                $0.title = NSLocalizedString("Add a project folder to the server that anyone can upload to.", comment: "")
                $0.cell.textLabel?.numberOfLines = 0
            }

            +++ nameRow.cellUpdate { cell, _ in
                self.enableDone()
            }

        super.viewDidLoad()
    }


    // MARK: UITableViewDelegate

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return TableHeader.reducedHeight
    }

    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return section == 1 ? tableView.separatorView : nil
    }
}
